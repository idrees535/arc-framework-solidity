
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("LMSRPredictionMarket", function () {
  let owner, user1, user2, oracle, feeRecipient;
  let factory, positions, token, market;

  beforeEach(async function () {
    [owner, user1, user2, oracle, feeRecipient] = await ethers.getSigners();

    // Deploy Mock ERC20 Token
    const Token = await ethers.getContractFactory("ERC20Token");
    token = await Token.deploy(ethers.parseEther("1000000"));
    await token.waitForDeployment();

    // Deploy PredictionMarketPositions Contract
    const Positions = await ethers.getContractFactory("PredictionMarketPositions");
    positions = await Positions.deploy("https://example.com/metadata/", owner.address);
    await positions.waitForDeployment();

    // Deploy MarketFactory Contract
    const Factory = await ethers.getContractFactory("MarketFactory");
    factory = await Factory.deploy(positions.getAddress());
    await factory.waitForDeployment();

    // Create a Market
    const marketId = 1;
    const outcomes = ["Yes", "No"];
    const b = 100;//ethers.parseEther("500");
    const duration = 7 * 24 * 60 * 60; // 1 week
    const feePercent = 1; // 1%
    const initialFunds = ethers.parseEther("1000");
    const marketTitle="Will service provider Infura Face a delay of more than 5 minutes in next 30 days?"
  

    // Transfer tokens to user1 and user2
    await token.transfer(user1.getAddress(), ethers.parseEther("5000"));
    await token.transfer(user2.getAddress(), ethers.parseEther("5000"));

    // User1 approves the factory to spend tokens
    await token.connect(user1).approve(factory.getAddress(), initialFunds);

    // User1 creates Market
    const tx = await factory.connect(user1).createMarket(
      marketId,
      marketTitle,
      outcomes,
      oracle.getAddress(),
      b,
      duration,
      feePercent,
      feeRecipient,
      token.getAddress(),
      initialFunds
    );

    const activeMarkets = await factory.getActiveMarkets();
    const marketAddress = activeMarkets[0];
    market = await ethers.getContractAt("LMSRPredictionMarket", marketAddress);
  });

  it("Should allow users to buy shares and update positions", async function () {
    const outcomeIndex = 0; // "Yes"
    const numShares = 10;

    // User1 approves the market to spend tokens
    await token.connect(user1).approve(market.getAddress(), ethers.parseEther("1000"));

    // Estimate cost
    const estimatedCost = await market.connect(user1).estimateCost(outcomeIndex, numShares);

    // Buy shares
    await expect(market.connect(user1).buyShares(outcomeIndex, numShares))
      .to.emit(market, "SharesPurchased")
      .withArgs(user1.getAddress(), outcomeIndex, numShares, estimatedCost);

    // Check user's position balance
    const tokenId = await positions.getTokenId(1, 0); 
    expect(await positions.balanceOf(user1.getAddress(), tokenId)).to.equal(numShares);
  });

  it("Should calculate correct prices after share purchases", async function () {
    // Buy shares as before
    const outcomeIndex = 0;
    const numShares = 10;
    await token.connect(user1).approve(market.getAddress(), ethers.parseEther("1000"));
    await market.connect(user1).buyShares(outcomeIndex, numShares);

    // Get price
    const price = await market.getPrice(outcomeIndex);
    expect(price).to.be.gt(0);
  });

  it("Should close the market after marketEndTime", async function () {
    // Fast-forward time beyond marketEndTime
    await ethers.provider.send("evm_increaseTime", [8 * 24 * 60 * 60]); // 8 days
    await ethers.provider.send("evm_mine");

    await expect(market.connect(user1).closeMarket()).to.emit(market, "MarketClosed");
    expect(await market.marketClosed()).to.be.true;
  });

  it("Should only allow the oracle to set the outcome", async function () {
    // Close the market first
    await ethers.provider.send("evm_increaseTime", [8 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await market.connect(user1).closeMarket();

    // Non-oracle tries to set outcome
    await expect(market.connect(user1).setOutcome(0)).to.be.revertedWith("Not authorized");

    // Oracle sets outcome
    await expect(market.connect(oracle).setOutcome(0)).to.emit(market, "OutcomeSet").withArgs(0);
    expect(await market.marketSettled()).to.be.true;
  });

  it("Should allow users to claim payouts correctly", async function () {
    // Buy shares and settle market as before
    const outcomeIndex = 0;
    const numShares = 10;
    await token.connect(user1).approve(market.getAddress(), ethers.parseEther("1000"));
    await market.connect(user1).buyShares(outcomeIndex, numShares);

    await ethers.provider.send("evm_increaseTime", [8 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");
    await market.connect(user1).closeMarket();
    await market.connect(oracle).setOutcome(outcomeIndex);

    // User1 claims payout
    await expect(market.connect(user1).claimPayout())
      .to.emit(market, "PayoutClaimed")
      .withArgs(user1.getAddress(), ethers.parseEther("10")); // Assuming payout per share is 1e18

    // User1's position should be burned
    const tokenId = 1 * 1000 + outcomeIndex;
    expect(await positions.balanceOf(user1.getAddress(), tokenId)).to.equal(0);

    // User1 cannot claim again
    await expect(market.connect(user1).claimPayout()).to.be.revertedWith("No winnings to claim");
  });

  it("Should allow fee recipient to withdraw collected fees", async function () {
    // Buy shares to generate fees
    const outcomeIndex = 0;
    const numShares = 10;
    await token.connect(user1).approve(market.getAddress(), ethers.parseEther("1000"));
    await market.connect(user1).buyShares(outcomeIndex, numShares);

    // Fee recipient withdraws fees
    await expect(market.connect(feeRecipient).withdrawFees())
      .to.emit(market, "FeesWithdrawn")
      .withArgs(feeRecipient.getAddress(), await market.collectedFees());

    expect(await market.collectedFees()).to.equal(0);
  });
});
