const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PredictionMarketPositions", function () {
  let owner, user;
  let positions;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy PredictionMarketPositions Contract
    const Positions = await ethers.getContractFactory("PredictionMarketPositions");
    positions = await Positions.deploy("https://example.com/metadata/", owner.address);
    await positions.waitForDeployment();
  });

  it("Should mint positions correctly", async function () {
    const marketId = 1;
    const outcomeIndex = 0;
    const amount = 10;
    const tokenId =  await positions.getTokenId(marketId, 0);

    // Mint positions
    await positions.mint(user.address, marketId, outcomeIndex, amount);

    // Check balance
    expect(await positions.balanceOf(user.address, tokenId)).to.equal(amount);
  });

  it("Should burn positions correctly", async function () {
    const marketId = 1;
    const outcomeIndex = 0;
    const amount = 10;
    const tokenId = marketId * 1000 + outcomeIndex;

    // Mint positions
    await positions.mint(user.address, marketId, outcomeIndex, amount);

    // Burn positions
    await positions.connect(user).burn(user.address, marketId, outcomeIndex, amount);

    // Check balance
    expect(await positions.balanceOf(user.address, tokenId)).to.equal(0);
  });

  it("Should return correct token URIs", async function () {
    const marketId = 1;
    const outcomeIndex = 0;
    const tokenId = marketId * 1000 + outcomeIndex;

    const uri = await positions.uri(tokenId);
    expect(uri).to.equal(`https://example.com/metadata/${tokenId}.json`);
  });
});
