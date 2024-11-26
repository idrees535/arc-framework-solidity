const { ethers } = require("hardhat");

async function main() {
  // Correct market address without any spaces
  const marketAddress = "0x2b3F1d1bd355EdeA8fBc381bD2deFd8cFC5b684D";

  // Get the contract factory and attach it to the deployed address
  const PredictionMarket = await ethers.getContractFactory("LMSRPredictionMarket");
  const market = await PredictionMarket.attach(marketAddress);

  try {
    // Close the market
    const tx = await market.closeMarket();
    await tx.wait();  // Wait for the transaction to be mined

    console.log("Market closed successfully.");
  } catch (error) {
    console.error("Error closing market:", error.message);
  }
}

main().catch((error) => {
  console.error("Unexpected error occurred:", error);
  process.exitCode = 1;
});
