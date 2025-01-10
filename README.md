
# ARC Framework Solidity Implementation

This repository contains the **Logarithmic Market Scoring Rule (LMSR)** implementation in Solidity, designed to provide dynamic pricing, inherent liquidity, and risk management for decentralized coverage pools.

## Prerequisites

Before you begin, ensure you have the following installed:

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html): Foundry is a blazing-fast development framework for Ethereum.
- Node.js and Yarn: Required for dependency management.
- A configured Ethereum wallet (e.g., MetaMask) and access to a testnet like Goerli.

### Install Foundry
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Setting Up the Foundry Project

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/idrees535/arc-framework-solidity.git
   cd arc-framework-solidity
   ```

2. **Install Dependencies**:
   Install the required dependencies via `forge` and `yarn`:
   ```bash
   forge install
   yarn install
   ```

3. **Compile the Contracts**:
   Build the Solidity contracts to ensure everything compiles correctly.
   ```bash
   forge build
   ```

4. **Run Tests**:
   Execute the test suite to verify contract functionality.
   ```bash
   forge test
   ```


## Setting Up the Hardhat Project

1. **Initialize the Project**:
   ```bash
   npm init -y
   npm install
   npm install --save-dev hardhat
   ```

2. **Install Hardhat Plugins**:
   ```bash
   npm install --save-dev @nomicfoundation/hardhat-foundry @nomicfoundation/hardhat-toolbox
   ```

3. **Configure Hardhat**:
   Run the Hardhat initializer:
   ```bash
   npx hardhat
   ```
   Select "Create an empty hardhat.config.js" and update it as follows:

   ```javascript
   require("@nomicfoundation/hardhat-toolbox");
   require("@nomicfoundation/hardhat-foundry");

   module.exports = {
     solidity: "0.8.19",
   };
   ```

4. **Run Tests**:
   ```bash
   npx hardhat test
   ```

5. **Deploy Contracts**:
   ```bash
   npx hardhat run scripts/initialize_market.js --network <network-name>
   ```


5. **Configure Network Settings**:
   Update the `.env` file with your private key and desired network settings:
   ```bash
   PRIVATE_KEY=<YOUR_PRIVATE_KEY>
   RPC_URL=https://goerli.infura.io/v3/<YOUR_INFURA_PROJECT_ID>
   ```


## Project Structure

- `src`: Contains the Solidity LMSR contract implementations.
- `script`: Deployment and setup scripts.
- `test`: Unit tests for the LMSR contract.
- `.env`: Configuration for private key and network RPC.

## LMSR Features

1. **Dynamic Pricing**: Implements the LMSR cost function for share price adjustments.
2. **Inherent Liquidity**: Ensures markets remain liquid via the `b` parameter.
3. **Worst-Case Loss Coverage**: Calculates maximum potential loss to secure payouts.
4. **Share Trading**: Facilitates buying and selling of shares with dynamically calculated odds.
5. **Oracle Integration**: Supports oracle mechanisms for event resolution.



## Contributing

Contributions are welcome! Please fork the repository, make your changes, and open a pull request. Refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for more details.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

