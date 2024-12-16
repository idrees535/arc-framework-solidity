// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title LMSR Prediction Market
 * @dev Implements a Logarithmic Market Scoring Rule (LMSR) prediction market with ERC20 token support.
 */

import "../utils/ABDKMath64x64.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PredictionMarketPositions.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract LMSRPredictionMarket is Ownable, ReentrancyGuard, Pausable {
    using ABDKMath64x64 for int128;

    // ==============================
    // State variables
    // ==============================

    struct Outcome {
        string name;
        uint256 totalShares; // Quantity q_i
    }

    Outcome[] public outcomes;
    uint256 public marketEndTime;
    bool public marketClosed;
    bool public marketSettled;
    uint256 public winningOutcome;
    string public title;
    address public oracle;

    uint256 public marketMakerFunds = 0;
    uint256 public initialFunds = 0;
    uint256 public collectedFees = 0;
    PredictionMarketPositions public positions;

    // ==============================
    // IMMUTABLE VARIABLES
    // ==============================

    uint256 public immutable b; // LMSR liquidity parameter
    IERC20 public immutable token;
    uint256 public immutable marketId;
    uint256 public immutable feePercent;
    address public immutable feeRecipient;
    uint8 public immutable tokenDecimals;
    uint256 public immutable payoutPerShare;
    uint256 public immutable unitScalingFactor;
    uint256 public immutable i_numOutcomes;

    // ==============================
    // CONSTANTS
    // ==============================

    uint256 public constant SHARES_DECIMALS = 10; // Decimals for shares scaling
    uint256 public constant PERCENT_DENOMINATOR = 100; // Denominator for percentage calculations
    uint256 public constant FEE_REINVEST_PERCENT = 50; // Percentage of fees reinvested into the market maker
    uint256 public constant MAX_SHARE_TRADE = 1000; // Maximum number of shares that can be bought
    uint256 public constant MAX_OUTCOME = 5; // Maximum number of outcomes allowed
    uint256 public constant MIN_LIQUIDITY_PARAM = 1; // Minimum liquidity parameter
    uint256 public constant MAX_LIQUIDITY_PARAM = 0x7FFFFFFFFFFFFFFF; // Maximum liquidity parameter

    // ==============================
    // EVENTS
    // ==============================

    event SharesPurchased(
        address indexed user,
        uint256 outcomeIndex,
        uint256 numShares,
        uint256 cost
    );
    event SharesSold(
        address indexed user,
        uint256 outcomeIndex,
        uint256 numShares,
        uint256 payment
    );
    event MarketClosed();
    event OutcomeSet(uint256 indexed winningOutcome);
    event PayoutClaimed(address indexed user, uint256 amount);
    event FeesWithdrawn(address indexed feeRecipient, uint256 amount);
    event FundsDeposited(address indexed depositor, uint256 amount);

    // ==============================
    // CONSTRUCTOR
    // ==============================

    /**
     * @dev Initializes the prediction market with the specified parameters.
     * @param _marketId Unique identifier for the market.
     * @param _title Title of the prediction market.
     * @param _outcomes Array of outcome names for the market.
     * @param _oracle Address of the oracle responsible for setting the outcome.
     * @param _b Liquidity parameter (LMSR constant) that affects share pricing dynamics.
     * @param _positionsAddress Address of the ERC1155 contract managing tokenized positions.
     * @param _duration Duration (in seconds) for the market to remain open.
     * @param _feePercent Fee percentage applied to trades.
     * @param _feeRecipient Address receiving the collected fees.
     * @param _tokenAddress Address of the ERC20 token used for trades.
     * @param _initialFunds Initial funds deposited into the market maker.
     */

    constructor(
        uint256 _marketId,
        string memory _title,
        string[] memory _outcomes,
        address _oracle,
        uint256 _b,
        uint256 _duration,
        uint256 _feePercent,
        address _feeRecipient,
        address _tokenAddress,
        uint256 _initialFunds,
        address _positionsAddress
    ) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_feeRecipient != address(0), "Invalid fee recipient address");
        require(_outcomes.length > 0, "At least one outcome required");
        require(_b > 0, "Liquidity parameter b must be greater than zero");
        require(_duration > 0, "Duration must be positive");
        require(
            _outcomes.length > 0 && _outcomes.length <= MAX_OUTCOME,
            "Invalid number of outcomes"
        );
        require(
            _b <= MAX_LIQUIDITY_PARAM,
            "Liquidity parameter 'b' exceeds the limit maximum"
        );
        require(
            _b >= MIN_LIQUIDITY_PARAM,
            "Liquidity parameter 'b' must be greater than minimum"
        );
        // Enforce the condition: initialFunds > b * ln(num_outcomes)

        require(
            _initialFunds >=
                calculateMinimumInitialFunds(_b, _outcomes.length) *
                    (10 ** IERC20Metadata(_tokenAddress).decimals()),
            "Initial funds must exceed b * ln(num_outcomes)"
        );

        marketId = _marketId;
        title = _title;
        oracle = _oracle;
        b = _b;
        marketEndTime = block.timestamp + _duration;
        marketClosed = false;
        marketSettled = false;
        feePercent = _feePercent;
        feeRecipient = _feeRecipient;
        token = IERC20(_tokenAddress);
        i_numOutcomes = _outcomes.length;
        // Get token decimals dynamically
        tokenDecimals = IERC20Metadata(_tokenAddress).decimals();
        positions = PredictionMarketPositions(_positionsAddress);

        // Grant roles to this contract
        //positions.grantRole(positions.MINTER_ROLE(), address(this));
        //positions.grantRole(positions.BURNER_ROLE(), address(this));

        // Adjust scaling factor dynamically
        if (tokenDecimals > SHARES_DECIMALS) {
            unitScalingFactor = 10 ** (tokenDecimals - SHARES_DECIMALS);
        } else {
            unitScalingFactor = 10 ** (SHARES_DECIMALS - tokenDecimals);
        }

        payoutPerShare = 1 * (10 ** tokenDecimals);

        for (uint256 i = 0; i < _outcomes.length; i++) {
            outcomes.push(Outcome({name: _outcomes[i], totalShares: 0}));
        }
    }

    // ==============================
    // MODIFIERS
    // ==============================

    modifier onlyOracle() {
        require(msg.sender == oracle, "Not authorized");
        _;
    }

    // ==============================
    // FUNCTIONS
    // ==============================

    /**
     * @notice Purchases shares for a specific outcome.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares to purchase.
     * @dev Transfers tokens from the user to the contract and mints new shares.
     * Emits a {SharesPurchased} event.
     */

    function buyShares(
        uint256 outcomeIndex,
        uint256 numShares
    ) public nonReentrant whenNotPaused {
        require(!marketClosed, "Market is closed");
        require(outcomeIndex < outcomes.length, "Invalid outcome");
        require(numShares > 0, "Must buy at least one share");
        require(numShares < MAX_SHARE_TRADE, "Share trade limit exceeded");

        // Calculate cost before purchase
        uint256[] memory qBefore = getQuantities();
        int128 costBefore = calculateCost(qBefore);

        // Update quantity for the selected outcome
        outcomes[outcomeIndex].totalShares += numShares;

        // Calculate cost after purchase
        uint256[] memory qAfter = getQuantities();
        int128 costAfter = calculateCost(qAfter);

        // Calculate the cost difference
        int128 costDifference = ABDKMath64x64.sub(costAfter, costBefore);
        require(costDifference >= 0, "Cost difference is negative");
        int128 scaledCostDifference = ABDKMath64x64.mul(
            costDifference,
            ABDKMath64x64.fromUInt(10 ** SHARES_DECIMALS)
        );
        uint256 cost = ABDKMath64x64.toUInt(scaledCostDifference) *
            unitScalingFactor;

        // Calculate the fee
        uint256 feeAmount = (cost * feePercent) / PERCENT_DENOMINATOR;
        uint256 reinvestAmount = (feeAmount * FEE_REINVEST_PERCENT) /
            PERCENT_DENOMINATOR;
        uint256 feeRecipientAmount = feeAmount - reinvestAmount;
        uint256 netCost = cost + feeAmount;

        // Transfer tokens from user to contract
        require(
            token.transferFrom(msg.sender, address(this), netCost),
            "Token transfer failed"
        );

        positions.mint(msg.sender, marketId, outcomeIndex, numShares);

        // Update market maker's funds (cost + reinvested fee)
        marketMakerFunds += cost + reinvestAmount;

        // Update collected fees (fee to be collected by feeRecipient)
        collectedFees += feeRecipientAmount;

        // Emit an event
        emit SharesPurchased(msg.sender, outcomeIndex, numShares, netCost);
    }

    /**
     * @notice Sells shares for a specific outcome.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares to sell.
     * @dev Burns the user's shares and transfers tokens back to the user.
     * Emits a {SharesSold} event.
     */

    function sellShares(
        uint256 outcomeIndex,
        uint256 numShares
    ) public nonReentrant whenNotPaused {
        require(!marketClosed, "Market is closed");
        require(outcomeIndex < outcomes.length, "Invalid outcome");
        require(numShares > 0, "Must sell at least one share");

        // Calculate a unique token ID based on marketId and outcomeIndex
        uint256 tokenId = positions.getTokenId(marketId, outcomeIndex);

        // Check if the user has enough shares to sell
        uint256 userSharesAmount = positions.balanceOf(msg.sender, tokenId);
        require(userSharesAmount >= numShares, "Not enough shares to sell");

        // Calculate cost before selling
        uint256[] memory qBefore = getQuantities();
        int128 costBefore = calculateCost(qBefore);

        // Update quantity for the selected outcome
        outcomes[outcomeIndex].totalShares -= numShares;

        // Calculate cost after selling
        uint256[] memory qAfter = getQuantities();
        int128 costAfter = calculateCost(qAfter);

        // Calculate the payment difference
        int128 costDifference = ABDKMath64x64.sub(costBefore, costAfter);
        require(costDifference >= 0, "Cost difference is negative");
        int128 scaledCostDifference = ABDKMath64x64.mul(
            costDifference,
            ABDKMath64x64.fromUInt(10 ** SHARES_DECIMALS)
        );
        uint256 payment = ABDKMath64x64.toUInt(scaledCostDifference) *
            unitScalingFactor;

        // Apply fees
        uint256 feeAmount = (payment * feePercent) / PERCENT_DENOMINATOR;
        uint256 reinvestAmount = (feeAmount * FEE_REINVEST_PERCENT) /
            PERCENT_DENOMINATOR;
        uint256 feeRecipientAmount = feeAmount - reinvestAmount;
        uint256 netPayment = payment - feeAmount;

        // Update market maker's funds (reduce by netPayment and reinvested fee)
        require(
            marketMakerFunds >= netPayment + reinvestAmount,
            "Insufficient market maker funds"
        );
        marketMakerFunds -= (netPayment + reinvestAmount);

        // Update collected fees (fee to be collected by feeRecipient)
        collectedFees += feeRecipientAmount;

        // Burn the shares from the user's balance
        positions.burn(msg.sender, marketId, outcomeIndex, numShares);

        // Transfer tokens to the user
        require(
            token.transfer(msg.sender, netPayment),
            "Token transfer failed"
        );

        // Emit an event
        emit SharesSold(msg.sender, outcomeIndex, numShares, netPayment);
    }

    /**
     * @notice Deposits additional funds into the market maker.
     * @param amount The amount of funds to deposit (in the ERC20 token's smallest unit).
     * @dev Can only be called by the owner. Updates the market maker's available funds.
     * Emits a {FundsDeposited} event.
     */
    function depositInitialFunds(uint256 amount) external onlyOwner {
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Initial fund transfer failed"
        );
        marketMakerFunds += amount;
        emit FundsDeposited(msg.sender, amount);
    }

    /**
     * @notice Closes the market when the end time is reached.
     * @dev Can only be called after the market end time.
     * Emits a {MarketClosed} event.
     */
    function closeMarket() public {
        require(block.timestamp >= marketEndTime, "Market not over yet");
        marketClosed = true;
        emit MarketClosed();
    }

    /**
     * @notice Sets the winning outcome for the market.
     * @param _winningOutcome The index of the winning outcome.
     * @dev Can only be called by the oracle and after the market is closed.
     * Emits an {OutcomeSet} event.
     */

    function setOutcome(uint256 _winningOutcome) public onlyOracle {
        require(marketClosed, "Market still open");
        require(!marketSettled, "Market already settled");
        require(_winningOutcome < outcomes.length, "Invalid outcome");
        require(!marketSettled, "Market already settled");

        winningOutcome = _winningOutcome;
        marketSettled = true;

        emit OutcomeSet(_winningOutcome);
    }

    /**
     * @notice Claims the payout for a user holding shares of the winning outcome.
     * @dev Transfers tokens to the user based on their shareholding.
     * Emits a {PayoutClaimed} event.
     */
    function claimPayout() public nonReentrant whenNotPaused {
        require(marketSettled, "Market not settled yet");

        // Calculate a unique token ID based on marketId and outcomeIndex
        uint256 tokenId = positions.getTokenId(marketId, winningOutcome);

        // Get the user's share balance for the winning outcome
        uint256 userSharesAmount = positions.balanceOf(msg.sender, tokenId);
        require(userSharesAmount > 0, "No winnings to claim");

        // Calculate payout based on dynamic formula
        uint256 totalWinningShares = outcomes[winningOutcome].totalShares;
        require(
            totalWinningShares >= userSharesAmount,
            "Invalid share amounts"
        );

        // Calculate payout: number of winning shares times payout per share ($1)
        //uint256 payout = userSharesAmount * payoutPerShare;
        uint256 payout = (userSharesAmount * payoutPerShare); // / (10 ** SHARES_DECIMALS);

        // Ensure the market maker has enough funds
        require(marketMakerFunds >= payout, "Insufficient market maker funds");

        // Update market maker funds
        marketMakerFunds -= payout;

        // Burn the ERC-1155 tokens representing the user's shares
        positions.burn(msg.sender, marketId, winningOutcome, userSharesAmount);

        // Transfer the payout in ERC-20 tokens to the user
        require(token.transfer(msg.sender, payout), "Token payout failed");

        emit PayoutClaimed(msg.sender, payout);
    }

    /**
     * @notice Withdraws collected fees to the fee recipient.
     * @dev Can only be called by the fee recipient.
     * Emits a {FeesWithdrawn} event.
     */
    function withdrawFees() external {
        require(msg.sender == feeRecipient, "Not authorized");
        uint256 amount = collectedFees;
        collectedFees = 0;
        // Transfer the collected fees in ERC-20 tokens to the feeRecipient
        require(token.transfer(feeRecipient, amount), "Fee withdrawal failed");
        emit FeesWithdrawn(feeRecipient, amount);
    }

    /**
     * @notice Estimates the cost of purchasing a given number of shares.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares to purchase.
     * @return The estimated cost of purchasing the shares.
     */

    function estimateCost(
        uint256 outcomeIndex,
        uint256 numShares
    ) public view returns (uint256) {
        require(outcomeIndex < outcomes.length, "Invalid outcome index");
        require(numShares > 0, "Number of shares must be greater than zero");
        require(b > 0, "Liquidity parameter b must be greater than zero");
        uint256[] memory qBefore = getQuantities();
        int128 costBefore = calculateCost(qBefore);

        // Simulate the purchase
        qBefore[outcomeIndex] += numShares;
        int128 costAfter = calculateCost(qBefore);

        int128 costDifference = ABDKMath64x64.sub(costAfter, costBefore);
        int128 scaledCostDifference = ABDKMath64x64.mul(
            costDifference,
            ABDKMath64x64.fromUInt(10 ** SHARES_DECIMALS)
        );
        uint256 cost = ABDKMath64x64.toUInt(scaledCostDifference) *
            unitScalingFactor;

        uint256 feeAmount = (cost * feePercent) / PERCENT_DENOMINATOR;
        uint256 netCost = cost + feeAmount;

        return netCost;
    }

    /**
     * @notice Estimates the payment for selling a given number of shares.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares to sell.
     * @return The estimated payment for selling the shares.
     */
    function estimatePayment(
        uint256 outcomeIndex,
        uint256 numShares
    ) public view returns (uint256) {
        require(outcomeIndex < outcomes.length, "Invalid outcome index");
        require(numShares > 0, "Number of shares must be greater than zero");
        require(b > 0, "Liquidity parameter b must be greater than zero");
        uint256[] memory qBefore = getQuantities();
        int128 costBefore = calculateCost(qBefore);

        // Simulate the purchase
        qBefore[outcomeIndex] -= numShares;
        int128 costAfter = calculateCost(qBefore);

        int128 costDifference = ABDKMath64x64.sub(costBefore, costAfter);
        int128 scaledCostDifference = ABDKMath64x64.mul(
            costDifference,
            ABDKMath64x64.fromUInt(10 ** SHARES_DECIMALS)
        );
        uint256 payment = ABDKMath64x64.toUInt(scaledCostDifference) *
            unitScalingFactor;

        uint256 feeAmount = (payment * feePercent) / PERCENT_DENOMINATOR;
        uint256 netpayment = payment + feeAmount;

        return netpayment;
    }

    /**
     * @notice Updates the oracle address.
     * @param _newOracle The new oracle address.
     * @dev Can only be called by the owner.
     */
    function updateOracle(address _newOracle) external onlyOwner {
        require(_newOracle != address(0), "Invalid oracle address");
        oracle = _newOracle;
    }

    /**
     * @notice Withdraws any remaining funds from the market maker.
     * @dev Can only be called by the owner and after the market is settled.
     * Transfers all remaining funds in the market maker to the fee recipient.
     * Emits no specific event; uses the token transfer to signal success.
     */

    function withdrawRemainingFunds() external onlyOwner {
        require(marketSettled, "Market not settled yet");
        uint256 remainingFunds = marketMakerFunds;
        marketMakerFunds = 0;
        require(
            token.transfer(feeRecipient, remainingFunds),
            "Withdrawal failed"
        );
    }

    /**
     * @notice Pauses the contract.
     * @dev Can only be called by the owner.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract.
     * @dev Can only be called by the owner.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ==============================
    // Helper FUNCTIONS
    // ==============================

    /**
     * @notice Helper function to retrieve the quantities of all outcomes.
     * @return Array of quantities representing total shares for each outcome.
     */

    function getQuantities() internal view returns (uint256[] memory) {
        uint256[] memory q = new uint256[](outcomes.length);
        for (uint256 i = 0; i < outcomes.length; i++) {
            q[i] = outcomes[i].totalShares;
        }
        return q;
    }

    /**
     * @notice Internal function to calculate the cost of purchasing shares.
     * @param q Array of quantities representing total shares for each outcome.
     * @return The cost of purchasing shares as a 64x64 fixed-point number.
     */
    function calculateCost(uint256[] memory q) internal view returns (int128) {
        require(q.length > 0, "No outcomes available");
        int128 sumExp = ABDKMath64x64.fromUInt(0);
        for (uint256 i = 0; i < q.length; i++) {
            int128 qiDivB = ABDKMath64x64.divu(q[i], b);
            int128 expQiDivB = ABDKMath64x64.exp(qiDivB);
            sumExp = ABDKMath64x64.add(sumExp, expQiDivB);
        }
        return
            ABDKMath64x64.mul(
                ABDKMath64x64.fromUInt(b),
                ABDKMath64x64.ln(sumExp)
            );
    }

    /**
     * @notice Gets the unique position ID for a user in a specific outcome.
     * @param _marketId The ID of the market.
     * @param outcomeIndex The index of the outcome.
     * @return The unique position ID.
     */
    /**
     * @dev Calculates the minimum initial funds required: b * ln(num_outcomes)
     * @param b The LMSR liquidity parameter
     * @param numOutcomes The number of outcomes in the market
     * @return The minimum initial funds required
     */
    function calculateMinimumInitialFunds(
        uint256 b,
        uint256 numOutcomes
    ) public view returns (uint256) {
        require(numOutcomes > 1, "At least two outcomes required");
        // Use ABDKMath64x64 for precision logarithmic calculations
        int128 lnOutcomes = ABDKMath64x64.ln(
            ABDKMath64x64.fromUInt(numOutcomes)
        );
        return ABDKMath64x64.mulu(lnOutcomes, b);
    }

    // ==============================
    // Gettor FUNCTIONS
    // ==============================

    function getPositionId(
        uint256 _marketId,
        uint256 outcomeIndex
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_marketId, outcomeIndex)));
    }

    /**
     * @notice Gets the total number of outcomes in the market.
     * @return The number of outcomes.
     */
    function getOutcomeCount() external view returns (uint256) {
        return outcomes.length;
    }

    /**
     * @notice Gets the total shares for a specific outcome.
     * @param outcomeIndex The index of the outcome.
     * @return The total shares for the outcome.
     */
    function getOutcomeTotalShares(
        uint256 outcomeIndex
    ) external view returns (uint256) {
        require(outcomeIndex < outcomes.length, "Invalid outcome index");
        return outcomes[outcomeIndex].totalShares;
    }

    /**
     * @notice Gets the user's share balance for a specific outcome.
     * @param user The address of the user.
     * @param outcomeIndex The index of the outcome.
     * @return The user's share balance for the specified outcome.
     * @dev Uses the PredictionMarketPositions contract to retrieve the balance.
     */

    function getUserShares(
        address user,
        uint256 outcomeIndex
    ) external view returns (uint256) {
        uint256 tokenId = positions.getTokenId(marketId, outcomeIndex);
        return positions.balanceOf(user, tokenId);
    }

    /**
     * @notice Gets the current price of shares for a specific outcome.
     * @param outcomeIndex The index of the selected outcome.
     * @return The price of a single share (scaled to match SHARES_DECIMALS precision).
     * @dev Uses the LMSR formula to calculate the price based on current share quantities.
     * The price is normalized to the precision defined by SHARES_DECIMALS.
     */

    function getPrice(uint256 outcomeIndex) public view returns (uint256) {
        require(outcomeIndex < outcomes.length, "Invalid outcome");

        int128 numerator = ABDKMath64x64.exp(
            ABDKMath64x64.divu(outcomes[outcomeIndex].totalShares, b)
        );
        int128 denominator = ABDKMath64x64.fromUInt(0);
        for (uint256 i = 0; i < outcomes.length; i++) {
            int128 expQiDivB = ABDKMath64x64.exp(
                ABDKMath64x64.divu(outcomes[i].totalShares, b)
            );
            denominator = ABDKMath64x64.add(denominator, expQiDivB);
        }
        int128 price = ABDKMath64x64.div(numerator, denominator);
        return
            ABDKMath64x64.toUInt(
                ABDKMath64x64.mul(
                    price,
                    ABDKMath64x64.fromUInt(10 ** SHARES_DECIMALS)
                )
            );
    }
}
