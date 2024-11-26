

const { ethers } = require("hardhat");
const config = require("./config_sepolia.js");

async function main() {
  const marketAddress = config.MARKET_ADDRESS;//"0x75537828f2ce51be7289709686A69CbFDbB714F1"; // Replace with your market address
  const tokenAddress = config.TOKEN_ADDRESS;//"0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Replace with the ERC-20 token address
  
  // Get the LMSRPredictionMarket and ERC-20 token contract instances
  const PredictionMarket = await ethers.getContractFactory("LMSRPredictionMarket");
  const market = await PredictionMarket.attach(marketAddress);
  
  const token = await ethers.getContractAt("IERC20", tokenAddress);

  

  const [signer] = await ethers.getSigners();  // Get the current user (signer)
   // Log the net cost
   const currentB = await market.b();
   console.log("Current b value:", currentB.toString());
  
  // Define the outcome index and number of shares
  const outcomeIndex = 1; // Index of the outcome you want to buy shares in
  const numShares = 10000000;//ethers.parseUnits("100", 18);   // Number of shares you want to buy

  // Call estimateCost to get the net cost
 const netCost = await market.estimateCost(outcomeIndex, numShares);

  console.log(`Net cost to buy ${numShares} shares in outcome: ${outcomeIndex}: ${ethers.formatUnits(netCost,18)} tokens`);

  // Approve the token transfer (if required)
  const allowance = await token.allowance(signer.address, marketAddress);

  //console.log(`Allowance: ${allowance.toString()}`);
  //console.log(`Net Cost: ${netCost.toString()}`);
  
  if (allowance<netCost) {
    console.log("Approving tokens for transfer...");
    const approveTx = await token.approve(marketAddress, netCost);
    await approveTx.wait();
    console.log(`Tokens approved: ${netCost.toString()}`);
  }

  // Call buyShares (no need for `msg.value` here since we're using ERC-20 tokens)
  const tx = await market.buyShares(outcomeIndex, numShares);
  const receipt = await tx.wait();

  // Log the gas used
  console.log(`Gas used: ${receipt.gasUsed.toString()}`);

  // Confirm shares were bought
  console.log(`Bought ${numShares} shares in outcome ${outcomeIndex}`);

  // Fetch and log updated odds
  const outcomeIndex_0 = 0;
  const odds_0 = await market.getPrice(outcomeIndex_0);
  const outcomeIndex_1 = 1;
  const odds_1 = await market.getPrice(outcomeIndex_1);
  console.log("Updated Odds");
  console.log(`outcomeIndex 0: ${ethers.formatUnits(odds_0,10)}`);
  console.log(`outcomeIndex 1: ${ethers.formatUnits(odds_1,10)}`);
}

main()
  .catch((error) => {
    console.error("Error:", error);
    process.exitCode = 1;
  });
