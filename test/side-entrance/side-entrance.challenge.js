const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Side entrance', function () {

    let deployer, attacker;

    const ETHER_IN_POOL = ethers.utils.parseEther('1000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const SideEntranceLenderPoolFactory = await ethers.getContractFactory('SideEntranceLenderPool', deployer);
        const ETHPoolAttacker = await ethers.getContractFactory('ETHPoolAttacker', attacker);
        this.pool = await SideEntranceLenderPoolFactory.deploy();
        this.Attacker = await ETHPoolAttacker.deploy();

        await this.pool.deposit({ value: ETHER_IN_POOL });

        this.attackerInitialEthBalance = await ethers.provider.getBalance(attacker.address);

        expect(
            await ethers.provider.getBalance(this.pool.address)
        ).to.equal(ETHER_IN_POOL);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        console.log(" -------------------- Before exploition --------------------")
        console.log(` pool balance : ${await ethers.provider.getBalance(this.pool.address)}`)
        console.log(` attacker balance : ${this.attackerInitialEthBalance} `);

        await this.Attacker.connect(attacker).attack(this.pool.address);
        await this.Attacker.connect(attacker).withdraw() ;
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        let poolBalance = await ethers.provider.getBalance(this.pool.address) ;
        let attackerBalance = await ethers.provider.getBalance(attacker.address) ;
        
        expect(
            poolBalance
        ).to.be.equal('0');
        
        // Not checking exactly how much is the final balance of the attacker,
        // because it'll depend on how much gas the attacker spends in the attack
        // If there were no gas costs, it would be balance before attack + ETHER_IN_POOL
        expect(
            attackerBalance
        ).to.be.gt(this.attackerInitialEthBalance);

        console.log(" -------------------- After exploition --------------------")
        console.log(` pool balance : ${poolBalance}`);
        console.log(` attacker balance : ${attackerBalance} `);
     });
});
