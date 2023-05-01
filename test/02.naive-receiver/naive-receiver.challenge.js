const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Naive receiver', function () {
    let deployer, user, player;
    let pool, receiver;

    // Pool has 1000 ETH in balance
    const ETHER_IN_POOL = 1000n * 10n ** 18n;

    // Receiver has 10 ETH in balance
    const ETHER_IN_RECEIVER = 10n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, user, player] = await ethers.getSigners();

        const LenderPoolFactory = await ethers.getContractFactory('NaiveReceiverLenderPool', deployer);
        const FlashLoanReceiverFactory = await ethers.getContractFactory('FlashLoanReceiver', deployer);
        
        pool = await LenderPoolFactory.deploy();
        await deployer.sendTransaction({ to: pool.address, value: ETHER_IN_POOL });
        const ETH = await pool.ETH();
        
        expect(await ethers.provider.getBalance(pool.address)).to.be.equal(ETHER_IN_POOL);
        expect(await pool.maxFlashLoan(ETH)).to.eq(ETHER_IN_POOL);
        expect(await pool.flashFee(ETH, 0)).to.eq(10n ** 18n);

        receiver = await FlashLoanReceiverFactory.deploy(pool.address);
        await deployer.sendTransaction({ to: receiver.address, value: ETHER_IN_RECEIVER });
        await expect(
            receiver.onFlashLoan(deployer.address, ETH, ETHER_IN_RECEIVER, 10n**18n, "0x")
        ).to.be.reverted;
        expect(
            await ethers.provider.getBalance(receiver.address)
        ).to.eq(ETHER_IN_RECEIVER);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // All ETH has been drained from the receiver
        expect(
            await ethers.provider.getBalance(receiver.address)
        ).to.be.equal(0);
        expect(
            await ethers.provider.getBalance(pool.address)
        ).to.be.equal(ETHER_IN_POOL + ETHER_IN_RECEIVER);
    });
});
