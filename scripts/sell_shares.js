const { ethers } = require("hardhat");
const config = require("./config.js");

async function main() {
    const marketAddress = config.MARKET_ADDRESS;//"0x75537828f2ce51be7289709686A69CbFDbB714F1"; // Replace with your market address
    const tokenAddress = config.TOKEN_ADDRESS;//"0x5FbDB2315678afecb367f032d93F642f64180aa3"; // Replace with the ERC-20 token address
    
    const _DECIMALS=8
  // Get the LMSRPredictionMarket and ERC-20 token contract instances
  const PredictionMarket = await ethers.getContractFactory("LMSRPredictionMarket");
  const market = await PredictionMarket.attach(marketAddress);
  
  const token = await ethers.getContractAt("IERC20", tokenAddress);
  
  const [signer] = await ethers.getSigners();  // Get the current user (signer)
  
  // Define the outcome index and number of shares
  const outcomeIndex = 1; // Index of the outcome you want to sell shares from
  const numShares = 700;//ethers.parseUnits("1", 18);   ;   // Number of shares you want to sell

  const _funds = await market.marketMakerFunds();
  console.log("Before Market Funds: ", _funds.toString());

  // Call sellShares
  const tx = await market.sellShares(outcomeIndex, numShares);//, { gasLimit: 200000 });
  const receipt = await tx.wait();

  // Log the gas used
  console.log(`Gas used: ${receipt.gasUsed.toString()}`);

  //console.log('transaction events', receipt.logs);

  
  // Confirm shares were sold
  console.log(`Sold ${numShares} shares in outcome ${outcomeIndex}`);

  //onsole.log(receipt.log);

  // Fetch and log updated odds
  
  const outcomeIndex_0 = 0;
  const odds_0 = await market.getPrice(outcomeIndex_0);
  const outcomeIndex_1 = 1;
  const odds_1 = await market.getPrice(outcomeIndex_1);
  console.log("Updated Odds");
  console.log(`outcomeIndex 0: ${ethers.formatUnits(odds_0,_DECIMALS)}`);
  console.log(`outcomeIndex 1: ${ethers.formatUnits(odds_1,_DECIMALS)}`);
  const funds = await market.marketMakerFunds();
  console.log("New Market Funds: ", funds.toString());
  

}

main()
  .catch((error) => {
    console.error("Error:", error);
    process.exitCode = 1;
  });
