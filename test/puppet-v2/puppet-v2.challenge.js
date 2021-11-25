const pairJson = require("@uniswap/v2-core/build/UniswapV2Pair.json")
const factoryJson = require("@uniswap/v2-core/build/UniswapV2Factory.json")
const routerJson = require("@uniswap/v2-periphery/build/UniswapV2Router02.json")

const { ethers } = require("hardhat")
const { expect } = require("chai")

describe("[Challenge] Puppet v2", function () {
    let deployer, attacker

    // Uniswap v2 exchange will start with 100 tokens and 10 WETH in liquidity
    const UNISWAP_INITIAL_TOKEN_RESERVE = ethers.utils.parseEther("100")
    const UNISWAP_INITIAL_WETH_RESERVE = ethers.utils.parseEther("10")

    const ATTACKER_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther("10000")
    const POOL_INITIAL_TOKEN_BALANCE = ethers.utils.parseEther("1000000")

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        ;[deployer, attacker] = await ethers.getSigners()

        await ethers.provider.send("hardhat_setBalance", [
            attacker.address,
            "0x1158e460913d00000", // 20 ETH
        ])
        expect(await ethers.provider.getBalance(attacker.address)).to.eq(
            ethers.utils.parseEther("20"),
        )

        const UniswapFactoryFactory = new ethers.ContractFactory(
            factoryJson.abi,
            factoryJson.bytecode,
            deployer,
        )
        const UniswapRouterFactory = new ethers.ContractFactory(
            routerJson.abi,
            routerJson.bytecode,
            deployer,
        )
        const UniswapPairFactory = new ethers.ContractFactory(
            pairJson.abi,
            pairJson.bytecode,
            deployer,
        )

        // Deploy tokens to be traded
        this.token = await (await ethers.getContractFactory("DamnValuableToken", deployer)).deploy()
        this.weth = await (await ethers.getContractFactory("WETH9", deployer)).deploy()

        // Deploy Uniswap Factory and Router
        this.uniswapFactory = await UniswapFactoryFactory.deploy(ethers.constants.AddressZero)
        this.uniswapRouter = await UniswapRouterFactory.deploy(
            this.uniswapFactory.address,
            this.weth.address,
        )

        // Create Uniswap pair against WETH and add liquidity
        await this.token.approve(this.uniswapRouter.address, UNISWAP_INITIAL_TOKEN_RESERVE)
        await this.uniswapRouter.addLiquidityETH(
            this.token.address,
            UNISWAP_INITIAL_TOKEN_RESERVE, // amountTokenDesired
            0, // amountTokenMin
            0, // amountETHMin
            deployer.address, // to
            (await ethers.provider.getBlock("latest")).timestamp * 2, // deadline
            { value: UNISWAP_INITIAL_WETH_RESERVE },
        )
        this.uniswapExchange = await UniswapPairFactory.attach(
            await this.uniswapFactory.getPair(this.token.address, this.weth.address),
        )
        expect(await this.uniswapExchange.balanceOf(deployer.address)).to.be.gt("0")

        // Deploy the lending pool
        this.lendingPool = await (
            await ethers.getContractFactory("PuppetV2Pool", deployer)
        ).deploy(
            this.weth.address,
            this.token.address,
            this.uniswapExchange.address,
            this.uniswapFactory.address,
        )

        // Setup initial token balances of pool and attacker account
        await this.token.transfer(attacker.address, ATTACKER_INITIAL_TOKEN_BALANCE)
        await this.token.transfer(this.lendingPool.address, POOL_INITIAL_TOKEN_BALANCE)

        // Ensure correct setup of pool.
        expect(
            await this.lendingPool.calculateDepositOfWETHRequired(ethers.utils.parseEther("1")),
        ).to.be.eq(ethers.utils.parseEther("0.3"))
        expect(
            await this.lendingPool.calculateDepositOfWETHRequired(POOL_INITIAL_TOKEN_BALANCE),
        ).to.be.eq(ethers.utils.parseEther("300000"))
    })

    it("Exploit", async function () {
        /** CODE YOUR EXPLOIT HERE */
    })

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Attacker has taken all tokens from the pool
        expect(await this.token.balanceOf(this.lendingPool.address)).to.be.eq("0")

        expect(await this.token.balanceOf(attacker.address)).to.be.gte(POOL_INITIAL_TOKEN_BALANCE)
    })
})
