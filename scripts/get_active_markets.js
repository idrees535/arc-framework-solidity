const { ethers } = require("hardhat");
const config = require("./config_sepolia.js");

async function main() {
  
  const factoryAddress = config.FACTORY_ADDRESS;
  const factory = await ethers.getContractAt("MarketFactory",factoryAddress);
  console.log("MarketFactory Laoded: ", await factory.getAddress());

    // Step 5: Fetch active markets from the factory
    console.log("Fetching active markets...");
    const activeMarkets = await factory.getActiveMarkets();
    console.log("Active Markets:", activeMarkets);

 
}

main().catch((error) => {
    console.error("Error:", error);
    process.exitCode = 1;
  });