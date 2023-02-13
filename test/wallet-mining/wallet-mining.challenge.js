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

        //  Data from https://github.com/safe-global/safe-singleton-factory/blob/main/artifacts/31337/deployment.json
        const GNOSIS_SINGLETON_DEPLOYMENT_INFO = {
            "gasPrice": 100000000000,
            "gasLimit": 100000,
            "signerAddress": "0xE1CB04A0fA36DdD16a06ea828007E35e1a3cBC37",
            "transaction": "0xf8a78085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf382f4f5a00dc4d1d21b308094a30f5f93da35e4d72e99115378f135f2295bea47301a3165a0636b822daad40aa8c52dd5132f378c0c0e6d83b4898228c7e21c84e631a0b891",
            "address": "0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7"
        }

        const attackWalletDeployer = walletDeployer.connect(player);
        const attackAuthorizer = authorizer.connect(player);

        const fn = attackAuthorizer.interface.getSighash("can(address,address)");
        // console.log(fn);

        // const attackFactory = await ethers.getContractFactory("AttackWalletMiner", player);
        // const c = await attackFactory.deploy();

        // await c.deploySafe();

        // Transfer funds to deploying address
        const tx = {
            to: GNOSIS_SINGLETON_DEPLOYMENT_INFO.signerAddress,
            value: ethers.utils.parseEther("1")
        }
        await player.sendTransaction(tx);


        // Deploy safe singleton factory for hardhat from
        // which deploys contract at 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7
        // https://github.com/safe-global/safe-singleton-factory/blob/main/artifacts/31337/deployment.json

        const txRes = await ethers.provider.sendTransaction(GNOSIS_SINGLETON_DEPLOYMENT_INFO.transaction);
        const deployerAddr = (await txRes.wait()).contractAddress;
        console.log("deployer address is", deployerAddr)

        const gnosisFactory = await ethers.getContractFactory("GnosisSafe", player);

        
        // Deploying the GnosisSafe must contain the salt prepended to the intialization bytecode.
        const deployRes = await (await player.sendTransaction({
            to: deployerAddr,
            data: ethers.constants.HashZero + gnosisFactory.bytecode.substring(2),
            gasLimit: 30000000
        })).wait();

        const gnosisMasteryCopyAddr = ethers.utils.getCreate2Address(deployerAddr, ethers.constants.HashZero, ethers.utils.keccak256(gnosisFactory.bytecode));
        console.log("Gnosis Address")
        console.log(gnosisMasteryCopyAddr);

        const deployed = await ethers.getContractAt("GnosisSafe", gnosisMasteryCopyAddr, player);

        console.log(await deployed.VERSION())
        






        // Notes:
        // Looks like the addresses are created from Gnosis Safe 1.1.1
        // https://github.com/safe-global/safe-deployments/blob/main/src/assets/v1.1.1/gnosis_safe.json
        // https://github.com/safe-global/safe-deployments/blob/main/src/assets/v1.1.1/proxy_factory.json

        // We should be able to do this with Gnosis deployments to actually get somewhere, but im not sure
        // how we will be able to put code behind the random address
        

        // const res = await attackWalletDeployer.can(player.address, DEPOSIT_ADDRESS)
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
