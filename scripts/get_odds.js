const { ethers } = require("hardhat");
const config = require("./config.js");

async function main() {
  const marketAddress = config.MARKET_ADDRESS; // Replace with actual market address
  const PredictionMarket = await ethers.getContractFactory("LMSRPredictionMarket");
  const market = await PredictionMarket.attach(marketAddress);
  
  const outcomeIndex_0=0;
  const odds_0 = await market.getPrice(outcomeIndex_0);
  console.log("Current Odds for outcomeIndex:",outcomeIndex_0, odds_0);

  const outcomeIndex_1=1;
  const odds_1 = await market.getPrice(outcomeIndex_1);
  console.log("Current Odds for outcomeIndex:",outcomeIndex_1, odds_1);
}

main().catch((error) => {
  console.error("Error:", error);
  process.exitCode = 1;
});
