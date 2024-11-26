const { ethers } = require("hardhat");
const config = require("./config_sepolia.js");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);


  // Step 1: Deploy the ERC-20 Token
  const tokenAddress = config.TOKEN_ADDRESS;
  const token = await ethers.getContractAt("IERC20", tokenAddress);
  console.log("Token laoded:", await token.getAddress());
  
  // Step 2: Deploy the ERC-1155 Positions Contract
  const positionsAddress = config.POSITIONS_ADDRESS;
  const positions = await ethers.getContractAt("PredictionMarketPositions",positionsAddress);
  //const positions = await positions.attach(positionsAddress);
  
   // Pass URI and deployer's address as the owner
  console.log("ERC-1155 positions contract loaded:", await positions.getAddress());
  
  // Step 3: Deploy the MarketFactory contract with positions address
  const factoryAddress = config.FACTORY_ADDRESS;
  const factory = await ethers.getContractAt("MarketFactory",factoryAddress);
  console.log("MarketFactory Laoded: ", await factory.getAddress());
  
  // Step 4: Create a new market with a unique marketId
  console.log("Creating a new market...");
  const marketTitle="Will service provider Infura Face a delay of more than 5 minutes in next 30 days?"
  const outcomes = ["Yes", "No"];
  const oracle = deployer.address;
  const feeRecipient = deployer.address;
  const b = 1000;//ethers.parseUnits("2.88", 18);  // LMSR liquidity parameter
  const duration = 3600 * 24 * 30;  // 30 days
  const feePercent = 2;  // 1%
  const marketId = Math.floor(Math.random() * 1000000);
  const initialFunds = ethers.parseUnits("1400", 18);


    console.log("Market ID:", marketId);
    console.log("Market ID:", marketTitle);
    console.log("Outcomes:", outcomes);
    console.log("Oracle Address:", oracle);
    console.log("Fee Recipeinet Address:", feeRecipient);
    console.log("Liquidity Parameter (b):", b);
    console.log("Duration:", duration);
    console.log("Fee Percent:", feePercent);
    console.log("Token Address:", await token.getAddress());
    console.log("Initial Funds:", initialFunds.toString());
    console.log("Psoitions Address:", await positions.getAddress());

    await token.approve(factory, initialFunds);
    console.log("MarketFactory approved to spend", initialFunds.toString(), "tokens");

    try {
      const gasEstimate = await factory.createMarket.estimateGas(
        marketId,
        marketTitle,
        outcomes, 
        oracle, 
        b, 
        duration, 
        feePercent,
        feeRecipient, 
        token.address, 
        initialFunds
      );
      console.log(`Estimated Gas for createMarket: ${gasEstimate.toString()}`);
    } catch (error) {
      console.error("Error estimating gas:", error.message);
    }

  try {
    const tx = await factory.createMarket(marketId, outcomes, oracle, b, duration, feePercent, await token.getAddress(),initialFunds);//,{ gasLimit: gasEstimate.add(100000) }); // Pass token and marketId
    const receipt = await tx.wait();
    console.log(`Gas used by Create Market: ${receipt.gasUsed.toString()}`);

    // Step 5: Fetch active markets from the factory
    console.log("Fetching active markets...");
    const activeMarkets = await factory.getActiveMarkets();
    console.log("Active Markets:", activeMarkets);

    if (activeMarkets.length === 0) {
      console.log("No active markets found.");
    } else {
      activeMarkets.forEach((market, index) => {
        console.log(`Market ${index + 1}: ${market}`);
      });
    }

    // Step 6: Get odds for the newly created market
    const marketAddress = activeMarkets[activeMarkets.length - 1]; 
    //console.log("Last Market Address:", marketAddress);
    if (marketAddress) {
      console.log(`Fetching odds for the new market at address: ${marketAddress}`);
      const PredictionMarket = await ethers.getContractFactory("LMSRPredictionMarket");
      const market = await PredictionMarket.attach(marketAddress);

      const outcomeIndex_0 = 0;
      const odds_0 = await market.getPrice(outcomeIndex_0);
      console.log(`Current Odds for outcomeIndex 0: ${ethers.formatUnits(odds_0,10)}`);

      const outcomeIndex_1 = 1;
      const odds_1 = await market.getPrice(outcomeIndex_1);
      console.log(`Current Odds for outcomeIndex 1: ${ethers.formatUnits(odds_1,10)}`);
    }

  } catch (error) {
    console.error("Error creating market:", error.message);
  }
}

main().catch((error) => {
  console.error("An unexpected error occurred:", error);
  process.exitCode = 1;
});
