const { ethers } = require('hardhat');
const { expect } = require('chai');
const { setBalance } = require('@nomicfoundation/hardhat-network-helpers');

describe('[Challenge] Side entrance', function () {
    let deployer, player;
    let pool;

    const ETHER_IN_POOL = 1000n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();

        // Deploy pool and fund it
        pool = await (await ethers.getContractFactory('SideEntranceLenderPool', deployer)).deploy();
        await pool.deposit({ value: ETHER_IN_POOL });
        expect(await ethers.provider.getBalance(pool.address)).to.equal(ETHER_IN_POOL);

        // Player starts with limited ETH in balance
        await setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.eq(PLAYER_INITIAL_ETH_BALANCE);

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

        const AttackFactory = await ethers.getContractFactory("AttackSideEntrance", player);
        const attackContract = await AttackFactory.deploy(pool.address);

        await attackContract.attack(ETHER_IN_POOL);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // Player took all ETH from the pool
        expect(await ethers.provider.getBalance(pool.address)).to.be.equal(0);
        expect(await ethers.provider.getBalance(player.address)).to.be.gt(ETHER_IN_POOL);
    });
});
