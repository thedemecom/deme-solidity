// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";

library SafeMath64 {
/**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint64 _a, uint64 _b) internal pure returns (uint64) {
    uint64 c = _a + _b;
    require(c >= _a);

    return c;
  }
}

library SafeMath8 {
/**
  * @dev Adds two numbers, reverts on overflow.
  */
  function add(uint8 _a, uint8 _b) internal pure returns (uint8) {
    uint8 c = _a + _b;
    require(c >= _a);

    return c;
  }
}

contract Deme{
    event SetupBill(address indexed from, address indexed to, address indexed token, uint256 amount, uint256 bill_id, uint8 time_mode);
    event PayBill(address indexed from, address indexed to, address indexed token, uint256 amount, uint256 bill_id, uint8 attempt);
    event CancelBill(address indexed from, address indexed to, address indexed token, uint256 amount, uint256 bill_id);

    struct SetupBillCommand {
        uint112 amount;
        uint8 time_mode;
        address to;
        address token;
    }

    struct Bill {
        uint112 amount;
        uint64 initial_timestamp;
        uint8 time_mode;
        uint8 attempts;
        bool is_active;
        address to;
        address from;
        address token;
    }

    address public helper;
    uint256 public next_bill_id;
    mapping(uint256 => Bill) public bills;
    mapping(address => uint128) public feeRate;

    constructor() {
        next_bill_id = 0;
        helper = msg.sender;
    }

    modifier onlyHelper() {
        require(msg.sender == helper, "Only helper can call this function.");
        _;
    }

    function setHelper(address _helper) public onlyHelper {
        helper = _helper;
    }

    function _addTimeByMode(
        uint8 mode, 
        uint64 initial_timestamp, 
        uint8 attempts
    ) internal view returns (uint256) {
        if (mode == 0) {
                return DateTime.addMonths(initial_timestamp, attempts);
        } else {
            if (mode == 1) {
                return DateTime.addDays(initial_timestamp, attempts * 7);
            } else {
                if (mode == 2) {
                    return DateTime.addDays(initial_timestamp, attempts);
                } else {
                    require(false, "No mode");
                }
            }
        }
    }

    function setupBill(
        SetupBillCommand memory params
    ) external returns (uint256) {
        uint112 amount = params.amount;
        address to = params.to;
        address token = params.token;
        uint256 bill_id = next_bill_id;
        bills[bill_id] = Bill({
            amount: amount,
            attempts: 0,
            initial_timestamp: uint64(block.timestamp),
            time_mode: params.time_mode,
            to: to,
            from: msg.sender,
            token: token,
            is_active: true
        });
        emit SetupBill(msg.sender, to, token, amount, bill_id, params.time_mode);
        bill_id++;
        next_bill_id = bill_id;
        return bill_id;
    }

    function payoutHelp(uint112[] memory bill_ids, address userAddr, address tokenAddr) external onlyHelper {
        uint128 feeRateHelper = feeRate[userAddr];
        uint256 amount = 0;
        for (uint i = 0; i < bill_ids.length; i++) {
            uint256 bill_id = bill_ids[i];
            Bill memory bill = bills[bill_id];
            require(bill.is_active, "Bill should be available");
            uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);
            require(ts <= block.timestamp, "Bill is not matured");
            require(bill.to == userAddr || bill.from == userAddr, "should be user addr");
            require(bill.token == tokenAddr, "Token should be same addr");
            IERC20(bill.token).transferFrom(bill.from, bill.to, bill.amount);
            amount = amount + bill.amount;
            emit PayBill(bill.from, bill.to, bill.token, bill.amount, bill_id, bill.attempts);
            uint8 attempts = SafeMath8.add(bill.attempts, 1);
            ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            while(ts <= block.timestamp) {
                attempts = SafeMath8.add(attempts, 1);
                ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            }
            bill.attempts = attempts;
            bills[bill_id] = bill;
        }
        if (feeRateHelper > 0 && amount > 0) {
            IERC20(tokenAddr).transferFrom(
                userAddr, 
                helper, 
                amount * feeRateHelper / 10000
            );
        }
    }

    function setFeeRate(uint128 rate) external {
        require(rate < 500, "shouldn't be too much");
        feeRate[msg.sender] = rate;
    }

    function claim(uint112[] memory bill_ids) external returns (uint256) {
        uint256 amount = 0;
        for (uint i = 0; i < bill_ids.length; i++) {
            uint256 bill_id = bill_ids[i];
            Bill memory bill = bills[bill_id];
            require(bill.is_active, "Bill should be available");
            uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);
            require(ts <= block.timestamp, "Bill is not matured");
            require(bill.from == msg.sender || bill.to == msg.sender,  "Should be payouted by sender or claimer");
            IERC20(bill.token).transferFrom(bill.from, bill.to, bill.amount);
            amount = amount + bill.amount;
            emit PayBill(bill.from, bill.to, bill.token, bill.amount, bill_id, bill.attempts);
            uint8 attempts = SafeMath8.add(bill.attempts, 1);
            ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            while(ts <= block.timestamp) {
                attempts = SafeMath8.add(attempts, 1);
                ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            }
            bill.attempts = attempts;
            bills[bill_id] = bill;
        }
        return amount;
    }

    function cancelBills(uint112[] memory bill_ids) external {
        for (uint i = 0; i < bill_ids.length; i++) {
            uint256 bill_id = bill_ids[i];
            Bill memory bill = bills[bill_id];
            require(bill.is_active, "Bill should be available");
            require(bill.from == msg.sender || bill.to == msg.sender, "Only sender or receiver can cancel bill");
            bill.is_active = false;
            bills[bill_id] = bill;
            emit CancelBill(msg.sender, bill.to, bill.token, bills[bill_id].amount, bill_id);
        }
    }

    function couldClaimBill(address claimer, uint256 bill_id) external view returns (bool) {
        Bill memory bill = bills[bill_id];
        uint256 allowance = IERC20(bill.token).allowance(bill.from, bill.to);
        uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);

        return bill.is_active
            && (bill.from == claimer || bill.to == claimer) 
            && ts <= block.timestamp 
            && allowance >= bill.amount;
    }

    function nextClaimBill(uint256 bill_id) external view returns (uint256) {
        Bill memory bill = bills[bill_id];
        uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);
        return ts;
    }
}