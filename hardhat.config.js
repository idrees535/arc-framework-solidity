require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true, // Enable the optimizer
        runs: 200,     // Number of optimization runs
      },
      viaIR: true,       // Enable Intermediate Representation optimizer
    },
  },
};
