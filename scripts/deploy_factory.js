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
  
  // Step 2: Deploy the ERC-1155 Positions Contract
  console.log("Deploying ERC-1155 positions contract...");
  const baseURI = "https:example/dashboards/{id}.json"; 
  
  // Step 3: Deploy the MarketFactory contract with positions address
  console.log("Deploying MarketFactory...");
  const MarketFactory = await ethers.getContractFactory("MarketFactory");
  const factory = await MarketFactory.deploy(baseURI); // Pass ERC-1155 positions address
  await factory.waitForDeployment();
  console.log("MarketFactory deployed to:", await factory.getAddress());
  
}

main().catch((error) => {
  console.error("An unexpected error occurred:", error);
  process.exitCode = 1;
});
