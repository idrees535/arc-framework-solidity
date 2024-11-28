// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/core/LMSRPredictionMarket.sol";
import "../../src/core/PredictionMarketPositions.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/mock/ERC20Token.sol";
import "forge-std/console.sol";
import "forge-std/StdInvariant.sol";
import "./Handler.t.sol";

contract LMSRInvariantTest is StdInvariant, Test {
    LMSRPredictionMarket market;
    PredictionMarketPositions positions;
    ERC20Token token;
    // Handler
    Handler public handler;
    // Actors
    address[] public actors;

    address owner = address(this);
    address alice = address(0x1);
    address bob = address(0x2);

    string[] outcomes = ["Yes", "No"];

    function setUp() public {
        token = new ERC20Token(1_000_0000_000 * 1e18); // Increase total supply
        // Initialize actors

        actors.push(address(0x3));
        actors.push(address(0x4));
        actors.push(address(0x5));
        actors.push(address(0x6));

        // Mint tokens to actors
        for (uint256 i = 0; i < actors.length; i++) {
            token.transfer(actors[i], 1_000_000 ether);
        }

        // Mint tokens to Alice for testing
        vm.prank(owner);
        token.transfer(alice, 500_000 * 1e18); // Allocate a larger amount to Alice
        vm.prank(owner);
        token.transfer(bob, 500_000 * 1e18);

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

        //targetContract(address(market));
        //console.log('Market Token balance Before: ',token.balanceOf(address(market)));
        //console.log('Market Funds Before: ',market.marketMakerFunds());
        vm.prank(owner);
        token.transfer(address(market), 1000 * 1e18);
        //console.log('Market Token balance After: ',token.balanceOf(address(market)));
        //console.log('Market Funds After: ',market.marketMakerFunds());

        // Deploy Handler
        handler = new Handler(market, token, positions, actors);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.simulateBuy.selector;
        selectors[1] = Handler.simulateSell.selector;
        selectors[0] = Handler.withdrawFees.selector;

        // Set target contract for invariant testing
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    // Invariant: Collected fees are correct
    function invariant_collectedFeesCorrect() public view {
        uint256 actualCollectedFees = market.collectedFees();
        uint256 expectedFees = handler.expectedCollectedFees();
        uint256 tolerance = 10e18;
        assertApproxEqAbs(actualCollectedFees, expectedFees, tolerance, "Collected fees mismatch exceeds tolerance");
    }

    // Invariant: Outcome shares match expected total shares
    function invariant_outcomeSharesMatchExpected() public view {
        uint256 outcomesLength = outcomes.length;
        for (uint256 i = 0; i < outcomesLength; i++) {
            (, uint256 totalShares) = market.outcomes(i);
            uint256 expectedTotalShares = handler.expectedOutcomeTotalShares(i);
            assertEq(totalShares, expectedTotalShares, "Total shares mismatch for outcome");
        }
    }

    function invariant_outcomeSharesMatchUserBalances() public view {
        uint256 marketId = market.marketId();
        uint256 outcomesLength = outcomes.length;

        for (uint256 i = 0; i < outcomesLength; i++) {
            (, uint256 totalShares) = market.outcomes(i);
            uint256 userSharesSum = 0;

            for (uint256 j = 0; j < actors.length; j++) {
                address actor = actors[j];
                uint256 userBalance = positions.balanceOf(actor, positions.getTokenId(marketId, i));
                userSharesSum += userBalance;

                uint256 expectedBalance = handler.userExpectedBalances(actor, i);
                assertEq(userBalance, expectedBalance, "User share balance mismatch");
            }

            // Compare total shares with sum of user shares
            assertEq(totalShares, userSharesSum, "Total shares do not match sum of user positions");

            // Compare with expected total shares
            uint256 expectedTotalShares = handler.expectedOutcomeTotalShares(i);
            assertEq(totalShares, expectedTotalShares, "Total shares mismatch for outcome");
        }
    }

    function invariant_marketMakerFundsSufficientForPayouts() public view {
        if (market.marketSettled()) {
            uint256 winningOutcome = market.winningOutcome();
            (, uint256 totalShares) = market.outcomes(winningOutcome);
            uint256 payoutPerShare = market.payoutPerShare();

            // Total payout required for all winning shares
            uint256 totalUnclaimedPayouts = totalShares * payoutPerShare;

            // Check if MM funds are sufficient
            uint256 marketMakerFunds = market.marketMakerFunds();
            assertTrue(marketMakerFunds >= totalUnclaimedPayouts, "Market Maker funds insufficient for payouts");
        }
    }

    // Invariant: Contract token balance matches funds
    function invariant_tokenBalanceMatchesFunds() public view {
        uint256 contractTokenBalance = token.balanceOf(address(market));
        uint256 expectedBalance = market.marketMakerFunds() + market.collectedFees();
        //console.log('contractTokenBalance: ',contractTokenBalance);
        //console.log('expectedBalance: ', expectedBalance);
        assertEq(contractTokenBalance, expectedBalance, "Token balance mismatch");
    }

    // Invariant: User share balances are correct
    function invariant_userShareBalancesCorrect() public view {
        uint256 marketId = market.marketId();
        uint256 outcomesLength = outcomes.length;

        for (uint256 i = 0; i < actors.length; i++) {
            address user = actors[i];
            for (uint256 j = 0; j < outcomesLength; j++) {
                uint256 userBalance = positions.balanceOf(user, positions.getTokenId(marketId, j));
                //console.log('userBalance:',userBalance);
                uint256 expectedBalance = handler.userExpectedBalances(user, j);
                //console.log('expectedBalance:', expectedBalance);
                assertEq(userBalance, expectedBalance, "User share balance mismatch");
            }
        }
    }
}
