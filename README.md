
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

## Setting Up the Project

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-repo/lmsr-foundry.git
   cd lmsr-foundry
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

5. **Configure Network Settings**:
   Update the `.env` file with your private key and desired network settings:
   ```bash
   PRIVATE_KEY=<YOUR_PRIVATE_KEY>
   RPC_URL=https://goerli.infura.io/v3/<YOUR_INFURA_PROJECT_ID>
   ```

6. **Deploy the Contracts**:
   Deploy the LMSR contract to a specified network using Foundry's deployment scripts:
   ```bash
   forge script script/DeployLMSR.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
   ```

7. **Verify Deployment**:
   Verify the contract address using the output from the deployment script or Etherscan.

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

## Example Commands

- **Compile Contracts**:
   ```bash
   forge build
   ```

- **Run Tests**:
   ```bash
   forge test
   ```

- **Deploy Contracts**:
   ```bash
   forge script script/DeployLMSR.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
   ```

- **Interact with Contracts**:
   Use scripts or a front-end to interact with the deployed LMSR contract for creating pools, placing bets, and resolving events.

## Deployment Script Example

Below is an example of a deployment script (`script/DeployLMSR.s.sol`):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/LMSR.sol";

contract DeployLMSR is Script {
    function run() external {
        vm.startBroadcast();
        
        // Deploy LMSR Contract
        LMSR lmsr = new LMSR();
        console.log("LMSR deployed at:", address(lmsr));
        
        vm.stopBroadcast();
    }
}
```

## Contributing

Contributions are welcome! Please fork the repository, make your changes, and open a pull request. Refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file for more details.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more information.

