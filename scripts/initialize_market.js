const { ethers } = require("hardhat");
const config = require("./config_sepolia.js");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Step 1: Deploy the ERC-20 Token
  console.log("Deploying token...");
  const initialSupply = ethers.parseUnits('1000000000', 18);
  const Token = await ethers.getContractFactory("ERC20Token");
  const token = await Token.deploy(initialSupply);
  await token.waitForDeployment(); // Wait for deployment to finish
  console.log("Token deployed to:", await token.getAddress());
  
  
  const baseURI = "https://example/dashboards/{id}.json"; 
  
  // Step 3: Deploy the MarketFactory contract with positions address
  console.log("Deploying MarketFactory...");
  const MarketFactory = await ethers.getContractFactory("MarketFactory");
  const factory = await MarketFactory.deploy(baseURI); // Pass ERC-1155 positions address
  await factory.waitForDeployment();
  console.log("MarketFactory deployed to:", await factory.getAddress());
  
  // Step 4: Create a new market with a unique marketId
  console.log("Creating a new market...");
  const marketTitle="Will Infura's average API response time remain below 500 milliseconds over the next 30 days?"
  const outcomes = ["Yes", "No"];
  const oracle = deployer.address;
  const feeRecipient = deployer.address;
  const b = 1000;//ethers.parseUnits("2.88", 18);  // LMSR liquidity parameter
  const duration = 3600 * 24 * 30;  // 30 days
  const feePercent = 2;  // 1%
  const marketId = Math.floor(Math.random() * 1000000);
  const initialFunds = ethers.parseUnits("700", 18);


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
    const tx = await factory.createMarket(marketId,marketTitle, outcomes, oracle, b, duration, feePercent,feeRecipient, await token.getAddress(),initialFunds);//,{ gasLimit: gasEstimate.add(100000) }); // Pass token and marketId
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
      const marketTitle = await market.title();
      console.log(`Market Title is: ${marketTitle}`);

      const outcomeIndex_0 = 0;
      const odds_0 = await market.getPrice(outcomeIndex_0);
      console.log(`Current Odds for outcomeIndex 0: ${ethers.formatUnits(odds_0,8)}`);

      const outcomeIndex_1 = 1;
      const odds_1 = await market.getPrice(outcomeIndex_1);
      console.log(`Current Odds for outcomeIndex 1: ${ethers.formatUnits(odds_1,8)}`);
    }

  } catch (error) {
    console.error("Error creating market:", error.message);
  }
}

main().catch((error) => {
  console.error("An unexpected error occurred:", error);
  process.exitCode = 1;
});
