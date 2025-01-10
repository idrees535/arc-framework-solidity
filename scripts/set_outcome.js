
const { ethers } = require("hardhat");

async function main() {
 
  const marketAddress = "0x9f1ac54BEF0DD2f6f3462EA0fa94fC62300d3a8e";

  const PredictionMarket = await ethers.getContractFactory("LMSRPredictionMarket");
  const market = await PredictionMarket.attach(marketAddress);

  // Set the outcome (e.g., 0 for "Yes")
  const tx = await market.setOutcome(0); // Outcome 0 (Yes)
  await tx.wait();

  console.log("Outcome set to 0");
}

main().catch((error) => {
  console.error("Error:", error);
  process.exitCode = 1;
});
