// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/core/LMSRPredictionMarket.sol";
import "../../src/core/PredictionMarketPositions.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/mock/ERC20Token.sol";

contract LMSRPredictionMarketTest is Test {
    LMSRPredictionMarket market;
    PredictionMarketPositions positions;
    ERC20Token token;

    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);
    string[] outcomes = ["Yes", "No"];

    function setUp() public {
        // Deploy test ERC20 token with an initial supply
        token = new ERC20Token(100000000000 * 1e18);

        // Mint tokens to Alice and Bob
        vm.prank(owner);
        token.transfer(alice, 1000 * 1e18);
        vm.prank(owner);
        token.transfer(bob, 1000 * 1e18);

        // Deploy PredictionMarketPositions contract
        positions = new PredictionMarketPositions("https://example.com/{id}.json", owner);

        // Deploy LMSRPredictionMarket with initial funds for liquidity
        market = new LMSRPredictionMarket(
            1,                      // marketId
            "Will it rain tomorrow?", // title
            outcomes,
            owner,                  // oracle
            1000,                   // b (liquidity parameter)
            1 days,                 // duration
            1,                      // feePercent
            owner,                  // feeRecipient
            address(token),         // tokenAddress
            1000 * 1e18,            // initialFunds
            address(positions)      // positionsAddress
        );
    }

    function testBuyShares() public {
        vm.startPrank(alice);

        // Approve the market to spend Alice's tokens
        token.approve(address(market), 1000 * 1e18);

        // Estimate the cost of buying 10 shares of outcome 0
        uint256 cost = market.estimateCost(0, 10);
        assertGe(token.balanceOf(alice), cost, "Alice has insufficient balance to buy shares.");

        // Buy 10 shares of outcome 0
        market.buyShares(0, 10);

        // Check Alice's share balance for outcome 0
        uint256 tokenId = positions.getTokenId(1, 0);
        uint256 balance = positions.balanceOf(alice, tokenId);
        assertEq(balance, 10, "Alice's balance for outcome 0 should be 10 shares.");

        vm.stopPrank();
    }

    function testSellShares() public {
        vm.startPrank(alice);

        // Approve the market to spend Alice's tokens
        token.approve(address(market), 1000 * 1e18);

        // Buy shares first, so Alice has shares to sell
        market.buyShares(0, 10);

        // Check initial balance after buying
        uint256 tokenId = positions.getTokenId(1, 0);
        uint256 initialBalance = positions.balanceOf(alice, tokenId);
        assertEq(initialBalance, 10, "Alice should initially own 10 shares of outcome 0.");

        // Sell 5 shares of outcome 0
        market.sellShares(0, 5);

        // Check balance after selling
        uint256 newBalance = positions.balanceOf(alice, tokenId);
        assertEq(newBalance, 5, "Alice's balance for outcome 0 should be 5 shares after selling.");

        vm.stopPrank();
    }

    function testMarketEndsAfterDuration() public {
        // Move forward in time beyond the market duration
        vm.warp(block.timestamp + 2 days);

        // Attempt to end the market
        market.closeMarket();
        bool isEnded=market.marketClosed();
       
        assertTrue(isEnded, "Market should have ended after the duration.");
    }
}
