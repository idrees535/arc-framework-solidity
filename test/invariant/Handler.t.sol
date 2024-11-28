// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../src/core/LMSRPredictionMarket.sol";
import "../../src/core/PredictionMarketPositions.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/mock/ERC20Token.sol";
import "forge-std/console.sol";
import "forge-std/StdInvariant.sol";

// Handler contract
contract Handler is Test{
    LMSRPredictionMarket public market;
    ERC20Token public token;
    PredictionMarketPositions public positions;
    address[] public actors;

    uint256 public totalDeposits;    // Total tokens spent by users to buy shares
    uint256 public totalWithdrawals; // Total tokens received by users when selling shares

    // Expected values to track
    uint256 public expectedCollectedFees;
    mapping(uint256 => uint256) public expectedOutcomeTotalShares; // outcomeIndex => totalShares
    mapping(address => mapping(uint256 => uint256)) public userExpectedBalances; // user => outcomeIndex => shares
    uint256 public expectedMarketMakerFunds;

    constructor(
        LMSRPredictionMarket _market,
        ERC20Token _token,
        PredictionMarketPositions _positions,
        address[] memory _actors
    ) {
        market = _market;
        token = _token;
        positions = _positions;
        actors = _actors;
    }

    // Function to buy shares
    function simulateBuy(
        uint256 outcomeIndex,
        uint256 numSharesSeed,
        uint256 actorSeed
    ) public {
        address actor = actors[actorSeed % actors.length];
        vm.startPrank(actor);

        // Bound numShares to prevent overflows or excessively large values
        uint256 numShares = bound(numSharesSeed, 1, type(uint256).max);

        // Estimate cost
        uint256 cost = market.estimateCost(outcomeIndex, numShares);


        uint256 feePercent = market.feePercent();
        uint256 feeAmount = (cost * feePercent) / 100;
        uint256 reinvestAmount = feeAmount / 2;
        uint256 feeRecipientAmount = feeAmount - reinvestAmount;
        //uint256 costWithoutFees = cost - feeAmount;

        // Update expected collected fees (half of fee goes to feeRecipient)
        expectedCollectedFees += feeRecipientAmount;

        // Update expected market maker funds (cost without fees + reinvested fee)
        expectedMarketMakerFunds += cost + reinvestAmount;

        // Update expected outcome total shares
        expectedOutcomeTotalShares[outcomeIndex] += numShares;

        // Update user's expected balance
        userExpectedBalances[actor][outcomeIndex] += numShares;


        // Ensure actor has enough tokens
        uint256 actorBalance = token.balanceOf(actor);
        if (actorBalance < cost) {
            token.transfer(actor, cost - actorBalance);
        }
        token.approve(address(market), cost);

        // Call buyShares
        market.buyShares(outcomeIndex, numShares);

        vm.stopPrank();

        // Update ghost variable
        totalDeposits += cost;
    }

    // Function to sell shares
    function simulateSell(
        uint256 outcomeIndex,
        uint256 numSharesSeed,
        uint256 actorSeed
    ) public {
        address actor = actors[actorSeed % actors.length];
        vm.startPrank(actor);

        uint256 tokenId = positions.getTokenId(market.marketId(), outcomeIndex);
        uint256 balance = positions.balanceOf(actor, tokenId);

        if (balance == 0) {
            // No shares to sell
            vm.stopPrank();
            return;
        }

        // Bound numShares to actor's balance
        uint256 numShares = bound(numSharesSeed, 1, balance);

        // Estimate payment
        uint256 payment = market.estimatePayment(outcomeIndex, numShares);

        uint256 feePercent = market.feePercent();
        uint256 feeAmount = (payment * feePercent) / 100;
        uint256 reinvestAmount = feeAmount / 2;
        uint256 feeRecipientAmount = feeAmount - reinvestAmount;
        uint256 netPayment = payment - feeAmount;

        // Update expected collected fees (half of fee goes to feeRecipient)
        expectedCollectedFees += feeRecipientAmount;

        // Update expected market maker funds (reduce by net payment and reinvested fee)
       expectedMarketMakerFunds -= (payment - reinvestAmount);

        // Update expected outcome total shares
        expectedOutcomeTotalShares[outcomeIndex] -= numShares;

        // Update user's expected balance
        userExpectedBalances[actor][outcomeIndex] -= numShares;


        // Call sellShares
        market.sellShares(outcomeIndex, numShares);

        vm.stopPrank();

        // Update ghost variable
        totalWithdrawals += netPayment;
    }

    function withdrawFees(uint256 actorSeed) public {
        address actor = actors[actorSeed % actors.length];
        vm.prank(actor);

        // Only the fee recipient can withdraw fees
        if (actor != market.feeRecipient()) {
            vm.stopPrank();
            return;
        }

        uint256 feesBefore = market.collectedFees();
        market.withdrawFees();
        uint256 feesAfter = market.collectedFees();

        // Update expected collected fees
        expectedCollectedFees -= (feesBefore - feesAfter);

        vm.stopPrank();
    }


}
