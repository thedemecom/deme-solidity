// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deme{
    struct ChequeCommand {
        uint112 amount;
        address to;
        address token;
        uint[] dates;
    }

    struct Cheque {
        uint112 amount;
        uint timestamp;
        address to;
        address from;
        address token;
        bool is_active;
        bool is_cashed;
    }

    uint256 public last_cheque_id;
    mapping(uint256 => Cheque) public cheques;
    mapping(address => uint[]) public receiverMap;
    mapping(address => uint[]) public senderMap;

    constructor() {
        last_cheque_id = 0;
    }

    function setupCheque(ChequeCommand memory params) external {
        uint[] memory dates = params.dates;
        uint112 amount = params.amount;
        address to = params.to;
        address token = params.token;
        uint256 cheque_id = last_cheque_id;
        for (uint i = 0; i < dates.length; i++) {
            cheques[cheque_id] = Cheque(amount, dates[i], to, msg.sender, token, true, false);
            receiverMap[to].push(cheque_id);
            senderMap[msg.sender].push(cheque_id);
            cheque_id++;
        }
        last_cheque_id = cheque_id;
    }

    function alternateChequeSums(uint[] memory cheque_ids) external {
        
    }

    function cancelCheques(uint[] memory cheque_ids) external {
        for (uint i = 0; i < cheque_ids.length; i++) {
            uint256 cheque_id = cheque_ids[i];
            require(cheques[cheque_id].from == msg.sender, "Only sender can cancel cheque");
            require(cheques[cheque_id].is_cashed == false, "Could cancel only uncashed cheques");
            cheques[cheque_id].is_active = false;
        }
    }

    function claimCheques(uint[] memory cheque_ids) external {
        for (uint i = 0; i < cheque_ids.length; i++) {
            uint256 cheque_id = cheque_ids[i];
            Cheque memory cheque = cheques[cheque_id];
            require(cheque.to == msg.sender, "Only receiver can claim cheque");
            require(cheque.is_active, "Cheque is cancelled");
            require(cheque.timestamp <= block.timestamp, "Cheque is not matured");
            require(!cheque.is_cashed, "Cheque is already cashed");
            cheque.is_cashed = true;
            IERC20(cheque.token).transferFrom(cheque.from, cheque.to, cheque.amount);
            cheques[cheque_id] = cheque;
        }
    }

    function claimableCheques(address receiver) external view returns (uint[] memory) {
        uint[] memory ids = receiverMap[receiver];
        
        uint claimable_count = 0;
        for (uint i = 0; i < ids.length; i++) {
            uint256 cheque_id = ids[i];
            Cheque memory cheque = cheques[cheque_id];
            uint allowance = IERC20(cheque.token).allowance(cheque.from, address(this));
            if (cheque.is_active && cheque.timestamp <= block.timestamp && !cheque.is_cashed && allowance >= cheque.amount) {
                claimable_count++;
            }
        }
        uint[] memory claimable_ids = new uint[](claimable_count);
        claimable_count = 0;
        for (uint i = 0; i < ids.length; i++) {
            uint256 cheque_id = ids[i];
            Cheque memory cheque = cheques[cheque_id];
            uint allowance = IERC20(cheque.token).allowance(cheque.from, address(this));
            if (cheque.is_active && cheque.timestamp <= block.timestamp && !cheque.is_cashed && allowance >= cheque.amount) {
                claimable_ids[claimable_count] = cheque_id;
                claimable_count++;
            }
        }
        return claimable_ids;
    }

    function activeCheques(address sender) external view returns (uint[] memory) {
        uint[] memory ids = senderMap[sender];
        
        uint count = 0;
        for (uint i = 0; i < ids.length; i++) {
            uint256 cheque_id = ids[i];
            Cheque memory cheque = cheques[cheque_id];
            if (cheque.is_active && !cheque.is_cashed) {
                count++;
            }
        }
        uint[] memory active_ids = new uint[](count);
        count = 0;
        for (uint i = 0; i < ids.length; i++) {
            uint256 cheque_id = ids[i];
            Cheque memory cheque = cheques[cheque_id];
            if (cheque.is_active && !cheque.is_cashed) {
                active_ids[count] = cheque_id;
                count++;
            }
        }
        return active_ids;
    }

    function activeChequesByReceiver(address sender, address receiver) external view returns (uint[] memory) {
        uint[] memory ids = senderMap[sender];
        
        uint count = 0;
        for (uint i = 0; i < ids.length; i++) {
            uint256 cheque_id = ids[i];
            Cheque memory cheque = cheques[cheque_id];
            if (cheque.is_active && !cheque.is_cashed && cheque.to == receiver) {
                count++;
            }
        }
        uint[] memory active_ids = new uint[](count);
        count = 0;
        for (uint i = 0; i < ids.length; i++) {
            uint256 cheque_id = ids[i];
            Cheque memory cheque = cheques[cheque_id];
            if (cheque.is_active && !cheque.is_cashed && cheque.to == receiver) {
                active_ids[count] = cheque_id;
                count++;
            }
        }
        return active_ids;
    }
}