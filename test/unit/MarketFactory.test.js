
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("MarketFactory", function () {
  let owner, user, oracle, feeRecipient;
  let factory, positions, token;

  beforeEach(async function () {
    [owner, user, oracle, feeRecipient] = await ethers.getSigners();

    // Deploy Mock ERC20 Token
    const Token = await ethers.getContractFactory("ERC20Token");
    token = await Token.deploy(ethers.parseEther("1000000"));
    await token.waitForDeployment();

    // Deploy PredictionMarketPositions Contract
    const Positions = await ethers.getContractFactory("PredictionMarketPositions");
    positions = await Positions.deploy("https://example.com/metadata/", owner.getAddress());
    await positions.waitForDeployment();

    // Deploy MarketFactory Contract
    const Factory = await ethers.getContractFactory("MarketFactory");
    factory = await Factory.deploy(positions.getAddress());
    await factory.waitForDeployment();
  });

  it("Should create a new market with correct parameters", async function () {
    const marketId = 1;
    const outcomes = ["Yes", "No"];
    const b = 100;//ethers.parseEther("500");
    const duration = 7 * 24 * 60 * 60; // 1 week
    const feePercent = 1; // 1%
    const initialFunds = ethers.parseEther("1000");
    const marketTitle="Will service provider Infura Face a delay of more than 5 minutes in next 30 days?"

    // Transfer tokens to user
    await token.transfer(user.getAddress(), ethers.parseEther("5000"));
    // User approves the factory to spend tokens
    await token.connect(user).approve(factory.getAddress(), initialFunds);

    // Create Market
    await expect(
      factory.connect(user).createMarket(
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
      )
    ).to.emit(factory, "MarketCreated");

    const activeMarkets = await factory.getActiveMarkets();
    expect(activeMarkets.length).to.equal(1);

    const marketAddress = activeMarkets[0];
    const market = await ethers.getContractAt("LMSRPredictionMarket", marketAddress);

    expect(await market.marketId()).to.equal(marketId);
    expect(await market.oracle()).to.equal(await oracle.getAddress());
    expect(await market.b()).to.equal(b);
    expect(await market.feePercent()).to.equal(feePercent);
    expect(await market.token()).to.equal(await token.getAddress());
    expect(await market.marketMakerFunds()).to.equal(initialFunds);
  });
});
