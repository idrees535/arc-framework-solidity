// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LMSRPredictionMarket.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PredictionMarketPositions.sol"; // Import the ERC-1155 contract

contract MarketFactory is Ownable {
    address[] public activeMarkets;
    PredictionMarketPositions public positions;
    // Mapping to store market titles
    mapping(address => string) public marketTitles;

    event MinterAuthorized(address indexed marketAddress);
    event MarketCreated(address indexed marketAddress, string title);
    event RolesGranted(address indexed marketAddress);
    event FundsTransferred(address indexed marketAddress, uint256 amount);

    /**
     * @dev Constructor to initialize the factory with the ERC-1155 positions contract
     * @param baseURI URI of positions address
     */

    constructor(string memory baseURI) Ownable(msg.sender) {
        positions = new PredictionMarketPositions(baseURI, address(this));
    }

    function createMarket(
        uint256 marketId,
        string memory title,
        string[] memory outcomes,
        address oracle,
        uint256 b,
        uint256 duration,
        uint256 feePercent,
        address feeRecipient,
        address tokenAddress,
        uint256 initialFunds
    ) public returns (address) {
        // Deploy the LMSRPredictionMarket contract

        LMSRPredictionMarket newMarket = new LMSRPredictionMarket(
            marketId,
            title,
            outcomes,
            oracle,
            b,
            duration,
            feePercent,
            feeRecipient,
            tokenAddress,
            initialFunds,
            address(positions)
            
        );

        // Add the new market to the list of active markets
        activeMarkets.push(address(newMarket));

        marketTitles[address(newMarket)] = title;
        emit MarketCreated(address(newMarket), title);

        // Grant roles to this contract
        positions.grantRole(positions.MINTER_ROLE(), address(newMarket));
        positions.grantRole(positions.BURNER_ROLE(), address(newMarket));
        emit RolesGranted(address(newMarket));

        if (initialFunds > 0) {
            require(
                IERC20(tokenAddress).transferFrom(
                    msg.sender,
                    address(newMarket),
                    initialFunds
                ),
                "Initial fund transfer failed"
            );
        }
    // Transfer ownership of the deployed market to the creator
        newMarket.transferOwnership(msg.sender);

        return address(newMarket);
    }

    /**
     * @dev Returns the list of all active markets
     */
    function getActiveMarkets() public view returns (address[] memory) {
        return activeMarkets;
    }

    function getPositions() public view returns (address) {
    return address(positions);
}

}
