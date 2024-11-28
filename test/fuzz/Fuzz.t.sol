// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/core/LMSRPredictionMarket.sol";
import "../../src/core/PredictionMarketPositions.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/mock/ERC20Token.sol";
import "forge-std/console.sol";

contract FuzzTest is Test {
    LMSRPredictionMarket market;
    PredictionMarketPositions positions;
    ERC20Token token;

    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);
    string[] outcomes = ["Yes", "No"];

    function setUp() public {
        // Deploy test ERC20 token with a large initial supply
        token = new ERC20Token(1_000_0000000 * 1e18); // Increase total supply

        // Mint tokens to Alice for testing
        vm.prank(owner);
        token.transfer(alice, 500_000 * 1e18); // Allocate a larger amount to Alice

        // Deploy PredictionMarketPositions contract
        positions = new PredictionMarketPositions("https://example.com/{id}.json", owner);

        // Deploy LMSRPredictionMarket with initial liquidity funds
        market = new LMSRPredictionMarket(
            1, // marketId
            "Will it rain tomorrow?", // title
            outcomes,
            owner, // oracle
            10000, // b
            1 days, // duration
            1, // feePercent
            owner, // feeRecipient
            address(token), // tokenAddress
            1000 * 1e18, // initialFunds for liquidity
            address(positions) // positionsAddress
        );
    }

    function testFuzzBuyShares(uint256 numShares) public {
        // Constrain numShares to a reasonable range for testing
        vm.assume(numShares > 0 && numShares <= 10000);

        // Log the number of shares
        console.log("numShares:", numShares);

        vm.startPrank(alice);

        // Estimate the cost and log it for visibility
        uint256 cost = market.estimateCost(0, numShares);
        console.log("Estimated cost for buying shares:", cost);

        // Ensure Alice has sufficient tokens
        assertGe(token.balanceOf(alice), cost, "Alice has insufficient balance for the transaction.");

        // Approve the market to spend Alice's tokens
        token.approve(address(market), cost);

        // Buy shares
        market.buyShares(0, numShares);

        // Verify Alice's share balance
        uint256 tokenId = positions.getTokenId(1, 0);
        uint256 balance = positions.balanceOf(alice, tokenId);
        assertEq(balance, numShares);

        vm.stopPrank();
    }
}
