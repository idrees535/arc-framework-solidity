
const { ethers } = require("hardhat");

async function main() {
  const marketAddress = "0x2b3F1d1bd355EdeA8fBc381bD2deFd8cFC5b684D";
  const PredictionMarket = await ethers.getContractFactory("LMSRPredictionMarket");
  const market = await PredictionMarket.attach(marketAddress);
  // Claim payout for outcome 0 (if you bet on the winning outcome)
  const tx = await market.claimPayout();
  await tx.wait();
  console.log("Payout claimed for outcome 0");
}
main().catch((error) => {
  console.error("Error:", error);
  process.exitCode = 1;
});
