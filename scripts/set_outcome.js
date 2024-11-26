
const { ethers } = require("hardhat");

async function main() {
 
  const marketAddress = "0x2b3F1d1bd355EdeA8fBc381bD2deFd8cFC5b684D";

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
