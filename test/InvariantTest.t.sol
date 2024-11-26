// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/core/LMSRPredictionMarket.sol";
import "../src/core/PredictionMarketPositions.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../src/mock/ERC20Token.sol";
import "forge-std/console.sol";
import "forge-std/StdInvariant.sol";

contract LMSRInvariantTest is StdInvariant, Test{
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

  function setUp() public{
        token = new ERC20Token(1_000_0000_000 * 1e18);  // Increase total supply
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
        token.transfer(alice, 500_000 * 1e18);  // Allocate a larger amount to Alice
        vm.prank(owner);
        token.transfer(bob, 500_000 * 1e18);

        // Deploy PredictionMarketPositions contract
        positions = new PredictionMarketPositions("https://example.com/{id}.json", owner);

        // Deploy LMSRPredictionMarket with initial liquidity funds
        market = new LMSRPredictionMarket(
            1,                      // marketId
            "Will it rain tomorrow?", // title
            outcomes,
            owner,                  // oracle
            10000,                  // b
            1 days,                 // duration
            1,                      // feePercent
            owner,                  // feeRecipient
            address(token),         // tokenAddress
            1000 * 1e18,            // initialFunds for liquidity
            address(positions)      // positionsAddress
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

        // Set target contract for invariant testing
        targetContract(address(handler));
  }
    // Invariant: Collected fees are correct
    function invariant_collectedFeesCorrect() public view{
        uint256 actualCollectedFees = market.collectedFees();
        uint256 expectedFees = handler.expectedCollectedFees();
        uint256 tolerance = 1e18;
        assertApproxEqAbs(
        actualCollectedFees,
        expectedFees,
        tolerance,
        "Collected fees mismatch exceeds tolerance"
            );
       
    }
    // Invariant: Outcome shares match expected total shares
    function invariant_outcomeSharesMatchExpected() public view{
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
            assertEq(
                userBalance,
                expectedBalance,
                "User share balance mismatch"
            );
        }

        // Compare total shares with sum of user shares
        assertEq(
            totalShares,
            userSharesSum,
            "Total shares do not match sum of user positions"
        );

        // Compare with expected total shares
        uint256 expectedTotalShares = handler.expectedOutcomeTotalShares(i);
        assertEq(
            totalShares,
            expectedTotalShares,
            "Total shares mismatch for outcome"
        );
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
        assertTrue(
            marketMakerFunds >= totalUnclaimedPayouts,
            "Market Maker funds insufficient for payouts"
        );
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
        uint256 numShares = bound(numSharesSeed, 1, 100);

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
