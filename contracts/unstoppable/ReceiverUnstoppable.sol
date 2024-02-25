// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "solmate/src/auth/Owned.sol";
import {UnstoppableVault, ERC20} from "../unstoppable/UnstoppableVault.sol";

/**
 * @title ReceiverUnstoppable
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract ReceiverUnstoppable is Owned, IERC3156FlashBorrower {
    UnstoppableVault public immutable pool;

    error UnexpectedFlashLoan();

    constructor(address poolAddress) Owned(msg.sender) {
        pool = UnstoppableVault(poolAddress);
    }

    /**
     * @dev
     * 1) initiator needs to be "this"
     * 2) caller has to be #UNS
     * 3) token needs to be #DVT
     * 4) fee should be 0
     * 5) token.allowance(initiator, pool(#UNS)) -> amount
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external returns (bytes32) {
        if (
            initiator != address(this) ||
            msg.sender != address(pool) ||
            token != address(pool.asset()) ||
            fee != 0
        ) revert UnexpectedFlashLoan();
        /**
         *
         * @dev #REC allows #UNS to spend amount & adds in #DVT.
         */
        ERC20(token).approve(address(pool), amount);

        return keccak256("IERC3156FlashBorrower.onFlashLoan");
    }

    /**
     * @dev creates local asset = #DVT.
     * executes flashLoan of #UNS(pool)
     */
    function executeFlashLoan(uint256 amount) external onlyOwner {
        address asset = address(pool.asset());
        pool.flashLoan(this, asset, amount, bytes(""));
    }
}
