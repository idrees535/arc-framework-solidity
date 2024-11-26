
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Prediction Market Integration Test", function () {
  let owner, user1, user2, oracle, feeRecipient;
  let factory, positions, token, market;

  before(async function () {
    [owner, user1, user2, oracle, feeRecipient] = await ethers.getSigners();

    // Deploy Mock ERC20 Token
    const Token = await ethers.getContractFactory("ERC20Token");
    token = await Token.deploy(ethers.parseEther("1000000",18));
    await token.waitForDeployment();

    // Deploy PredictionMarketPositions Contract
    const Positions = await ethers.getContractFactory("PredictionMarketPositions");
    positions = await Positions.deploy("https://example.com/metadata/", owner.address);
    await positions.waitForDeployment();

    // Deploy MarketFactory Contract
    const Factory = await ethers.getContractFactory("MarketFactory");
    factory = await Factory.deploy(positions.getAddress());
    await factory.waitForDeployment();

    // Approve factory to mint tokens for test
    await token.approve(factory.getAddress(), ethers.parseUnits("100000", 18));

    // Create a Market
    const marketId = 1;
    const outcomes = ["Yes", "No"];
    const b = 100;//ethers.utils.parseEther("500");
    const duration = 7 * 24 * 60 * 60; // 1 week
    const feePercent = 1; // 1%
    const initialFunds = ethers.parseEther("1000",18);
    const marketTitle="Will service provider Infura Face a delay of more than 5 minutes in next 30 days?"


    // Transfer tokens to user1 and user2
    await token.transfer(user1.address, ethers.parseEther("5000",18));
    await token.transfer(user2.address, ethers.parseEther("5000",18));

    // User1 approves the factory to spend tokens
    await token.connect(user1).approve(factory.getAddress(), initialFunds);

    const oracleAddress = await oracle.getAddress();
    console.log("Oracle address:", oracleAddress);

    const tokenAddress = await token.getAddress();
    console.log("Token address:", tokenAddress);

    // User1 creates Market
    const tx = await factory.connect(user1).createMarket(
      marketId,
      marketTitle,
      outcomes,
      oracleAddress,
      b,
      duration,
      feePercent,
      feeRecipient,
      tokenAddress,
      initialFunds
    );
    await tx.wait();

    const activeMarkets = await factory.getActiveMarkets();
    expect(activeMarkets.length).to.be.gt(0);
    console.log("Active markets:", activeMarkets); 
    
    const marketAddress = activeMarkets[0];
    console.log("Market address:", marketAddress);

    market = await ethers.getContractAt("LMSRPredictionMarket", marketAddress);
    
   
  });

  it("Complete market lifecycle", async function () {
    // Users buy shares
    const numShares = 10;

    // User1 buys "Yes" shares
    await token.connect(user1).approve(market.getAddress(), ethers.parseEther("1000"));
    await market.connect(user1).buyShares(0, numShares);

    // User2 buys "No" shares
    await token.connect(user2).approve(market.getAddress(), ethers.parseEther("1000"));
    await market.connect(user2).buyShares(1, numShares);

    // Advance time beyond marketEndTime
    await ethers.provider.send("evm_increaseTime", [8 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    // Close market
    await market.connect(user1).closeMarket();

    // Oracle sets outcome (e.g., outcome 0 wins)
    await market.connect(oracle).setOutcome(0);

    // Users claim payouts
    await market.connect(user1).claimPayout(); // Should succeed
    await expect(market.connect(user2).claimPayout()).to.be.revertedWith("No winnings to claim");

    // Fee recipient withdraws fees
    await market.connect(feeRecipient).withdrawFees();
  });
});
