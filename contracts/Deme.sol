// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@quant-finance/solidity-datetime/contracts/DateTime.sol";

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
        address from;
    }

    address public helper;
    uint256 public next_bill_id;
    mapping(bytes32 => Bill) public bills;
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
    ) internal pure returns (uint256) {
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
        uint256 bill_id = next_bill_id;
        bytes32 bill_hash = keccak256(abi.encodePacked(params.to, params.token, bill_id));
        bills[bill_hash] = Bill({
            amount: params.amount,
            attempts: 0,
            initial_timestamp: uint64(block.timestamp),
            time_mode: params.time_mode,
            from: msg.sender,
            is_active: true
        });
        emit SetupBill(msg.sender, params.to, params.token, params.amount, bill_id, params.time_mode);
        next_bill_id = bill_id + 1;
        return bill_id;
    }

    function payoutHelp(address claimer, address tokenAddr, uint112[] memory bill_ids) external onlyHelper {
        uint128 feeRateHelper = feeRate[claimer];
        uint256 amount = 0;
        for (uint i = 0; i < bill_ids.length; i++) {
            bytes32 bill_hash = keccak256(abi.encodePacked(claimer, tokenAddr, bill_ids[i]));
            Bill memory bill = bills[bill_hash];
            require(bill.is_active, "Bill should be available");
            uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);
            require(ts <= block.timestamp, "Bill is not matured");
            IERC20(tokenAddr).transferFrom(bill.from, claimer, bill.amount);
            amount = amount + bill.amount;
            emit PayBill(bill.from, claimer, tokenAddr, bill.amount, bill_ids[i], bill.attempts);
            uint8 attempts = bill.attempts + 1;
            ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            while(ts <= block.timestamp) {
                attempts = attempts++;
                ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            }
            bill.attempts = attempts;
            bills[bill_hash] = bill;
        }
        if (feeRateHelper > 0 && amount > 0) {
            IERC20(tokenAddr).transferFrom(
                claimer, 
                helper, 
                amount * feeRateHelper / 10000
            );
        }
    }

    function setFeeRate(uint128 rate) external {
        require(rate < 500, "shouldn't be too much");
        feeRate[msg.sender] = rate;
    }

    function claim(
        address claimer, 
        address tokenAddr, 
        uint256[] memory bill_ids
    ) external returns (uint256) {
        uint256 amount = 0;
        for (uint i = 0; i < bill_ids.length; i++) {
            bytes32 bill_hash = keccak256(abi.encodePacked(claimer, tokenAddr, bill_ids[i]));
            Bill memory bill = bills[bill_hash];
            require(bill.is_active, "Bill should be available");
            uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);
            require(ts <= block.timestamp, "Bill is not matured");
            require(bill.from == msg.sender || claimer == msg.sender,  "Should be payouted by sender or claimer");
            IERC20(tokenAddr).transferFrom(bill.from, claimer, bill.amount);
            amount = amount + bill.amount;
            emit PayBill(bill.from, claimer, tokenAddr, bill.amount, bill_ids[i], bill.attempts);
            uint8 attempts = bill.attempts + 1;
            ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            while(ts <= block.timestamp) {
                attempts++;
                ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, attempts);
            }
            bill.attempts = attempts;
            bills[bill_hash] = bill;
        }
        return amount;
    }

    function cancelBills(address claimer, address tokenAddr,  uint256[] memory bill_ids) external {
        for (uint i = 0; i < bill_ids.length; i++) {
            bytes32 bill_hash = keccak256(abi.encodePacked(claimer, tokenAddr, bill_ids[i]));
            Bill memory bill = bills[bill_hash];
            require(bill.is_active, "Bill should be available");
            require(bill.from == msg.sender || claimer == msg.sender, "Only sender or receiver can cancel bill");
            bill.is_active = false;
            bills[bill_hash] = bill;
            emit CancelBill(bill.from, claimer, tokenAddr, bill.amount, bill_ids[i]);
        }
    }

    function couldClaimBill(address claimer, address tokenAddr,  uint256 bill_id) external view returns (bool) {
        bytes32 bill_hash = keccak256(abi.encodePacked(claimer, tokenAddr, bill_id));
        Bill memory bill = bills[bill_hash];
        uint256 allowance = IERC20(tokenAddr).allowance(bill.from, claimer);
        uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);

        return bill.is_active
            && ts <= block.timestamp 
            && allowance >= bill.amount;
    }

    function nextClaimBill(address claimer, address tokenAddr, uint256 bill_id) external view returns (uint256) {
        bytes32 bill_hash = keccak256(abi.encodePacked(claimer, tokenAddr, bill_id));
        Bill memory bill = bills[bill_hash];
        uint256 ts = _addTimeByMode(bill.time_mode, bill.initial_timestamp, bill.attempts);
        return ts;
    }

    function billInfo(address claimer, address tokenAddr, uint256 bill_id) external view returns (Bill memory) {
        bytes32 bill_hash = keccak256(abi.encodePacked(claimer, tokenAddr, bill_id));
        return bills[bill_hash];
    }
}