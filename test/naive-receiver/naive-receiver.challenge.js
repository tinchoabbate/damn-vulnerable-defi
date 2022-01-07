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

    /**
     * Exploit Overview
     * 
     * @dev
     * This challenge was about exploiting an existing receiver contract with the lending pool.
     * The main thing here is that we can control who the borrower is as that is under the 
     * attackers control.
     * 
     * Since the lending pools fee is 1 ether and the receiver contract has 10 ether we can 
     * execute a transaction that executes a flashLoan on behalf of the receiver. The 
     * receiver then processes and returns the flashloan with the fee.
     * 
     * To do this in one transaction, deploy a smart contract that has a function which 
     * calls the lender in a for loop 10 times. 
     * 
     * Contract Exploit file is located at:
     * "contracts/attacker-contracts/AttackNaiveReceiver.sol"
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */ 
        
        const AttackFactory = await ethers.getContractFactory("AttackNaiveReceiver", attacker);
        const attackContract = await AttackFactory.deploy(this.pool.address);

        await attackContract.attack(this.receiver.address);

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
