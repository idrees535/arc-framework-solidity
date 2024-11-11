// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor(uint256 initialSupply) ERC20("SSL USD Token", "SSLUSD") {
        _mint(msg.sender, initialSupply);  // Mint initial supply to the deployer
    }
}
