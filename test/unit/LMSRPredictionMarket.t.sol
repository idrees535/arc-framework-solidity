// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/core/LMSRPredictionMarket.sol";
import "../../src/core/PredictionMarketPositions.sol";
import "../../src/core/MarketFactory.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/mock/ERC20Token.sol";

contract LMSRPredictionMarketTest is Test {
    LMSRPredictionMarket market;
    PredictionMarketPositions positions;
    ERC20Token token;
    address marketAddress;

    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);
    string[] outcomes = ["Yes", "No"];
    uint256 initialFunds = 694e18;

    function setUp() public {
        // Deploy test ERC20 token with an initial supply
        token = new ERC20Token(100000000000 * 1e18);

        // Mint tokens to Alice and Bob
        vm.prank(owner);
        token.transfer(alice, 1000 * 1e18);
        vm.prank(owner);
        token.transfer(bob, 1000 * 1e18);

        MarketFactory factory = new MarketFactory("https://example.com/{id}.json");

        // Approve the factory to spend the initialFunds on behalf of the owner
        vm.prank(owner);
        token.approve(address(factory), initialFunds);

    
        marketAddress = factory.createMarket(
            1, // marketId
            "Will it rain tomorrow?", // title
            outcomes,
            owner, // oracle
            1000, // b (liquidity parameter)
            1 days, // duration
            1, // feePercent
            owner, // feeRecipient
            address(token), // tokenAddress
            initialFunds // initialFunds
        );

    market = LMSRPredictionMarket(marketAddress);
    address positionsAddress = factory.getPositions();
    positions = PredictionMarketPositions(positionsAddress);

    console.log("Market address: ", marketAddress);
    console.log ("Initial funds allocated: ",initialFunds );
    
    console.log("minimum initial funds calcualted: ", market.calculateMinimumInitialFunds(1000, 2));
    }

    function testBuyShares() public {
        vm.startPrank(alice);

        // Approve the market to spend Alice's tokens
        token.approve(address(market), 1000 * 1e18);

        // Estimate the cost of buying 10 shares of outcome 0
        uint256 cost = market.estimateCost(0, 10);
        console.log("Cost of buying shares: ", cost);
        assertGe(token.balanceOf(alice), cost, "Alice has insufficient balance to buy shares.");

        // Buy 10 shares of outcome 0
        market.buyShares(0, 1000);

        // Check Alice's share balance for outcome 0
        uint256 tokenId = positions.getTokenId(1, 0);
        uint256 balance = positions.balanceOf(alice, tokenId);
        assertEq(balance, 1000, "Alice's balance for outcome 0 should be 1000 shares.");

        vm.stopPrank();
    }

    function testSellShares() public {
        vm.startPrank(alice);

        // Approve the market to spend Alice's tokens
        token.approve(address(market), 1000 * 1e18);

        // Buy shares first, so Alice has shares to sell
        market.buyShares(0, 1000);

        // Check initial balance after buying
        uint256 tokenId = positions.getTokenId(1, 0);
        uint256 initialBalance = positions.balanceOf(alice, tokenId);
        assertEq(initialBalance, 1000, "Alice should initially own 1000 shares of outcome 0.");

        // Sell 5 shares of outcome 0
        market.sellShares(0, 500);

        // Check balance after selling
        uint256 newBalance = positions.balanceOf(alice, tokenId);
        assertEq(newBalance, 500, "Alice's balance for outcome 0 should be 500 shares after selling.");

        vm.stopPrank();
    }

    function testMarketEndsAfterDuration() public {
        // Move forward in time beyond the market duration
        vm.warp(block.timestamp + 2 days);

        // Attempt to end the market
        market.closeMarket();
        bool isEnded = market.marketClosed();

        assertTrue(isEnded, "Market should have ended after the duration.");
    }
}
