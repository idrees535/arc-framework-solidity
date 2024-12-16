// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @title LMSR Prediction Market
 * @dev Implements a Logarithmic Market Scoring Rule (LMSR) prediction market with ERC20 token support.
 */
contract LMSRPredictionMarket is Ownable, ReentrancyGuard, Pausable {
    using ABDKMath64x64 for int128;

    // ==============================
    // EVENTS
    // ==============================

    /**
     * @dev Emitted when shares are purchased by a user.
     * @param user The address of the buyer.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares purchased.
     * @param cost The total cost (including fees) paid for the shares.
     */
    event SharesPurchased(
        address indexed user,
        uint256 outcomeIndex,
        uint256 numShares,
        uint256 cost
    );

    /**
     * @dev Emitted when shares are sold by a user.
     * @param user The address of the seller.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares sold.
     * @param payment The total payment received by the seller.
     */
    event SharesSold(
        address indexed user,
        uint256 outcomeIndex,
        uint256 numShares,
        uint256 payment
    );

    /**
     * @dev Emitted when the market is closed.
     */
    event MarketClosed();

    /**
     * @dev Emitted when the market outcome is set by the oracle.
     * @param winningOutcome The index of the winning outcome.
     */
    event OutcomeSet(uint256 indexed winningOutcome);

    /**
     * @dev Emitted when a user claims their payout.
     * @param user The address of the user claiming the payout.
     * @param amount The payout amount received by the user.
     */
    event PayoutClaimed(address indexed user, uint256 amount);

    /**
     * @dev Emitted when the fee recipient withdraws the collected fees.
     * @param feeRecipient The address of the fee recipient.
     * @param amount The amount of fees withdrawn.
     */
    event FeesWithdrawn(address indexed feeRecipient, uint256 amount);

    /**
     * @dev Emitted when funds are deposited by the owner to the market maker.
     * @param depositor The address of the depositor.
     * @param amount The amount of funds deposited.
     */
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
     * @param _b Liquidity parameter (LMSR constant).
     * @param _duration Duration (in seconds) for the market to remain open.
     * @param _feePercent Fee percentage applied to trades.
     * @param _feeRecipient Address receiving the collected fees.
     * @param _tokenAddress Address of the ERC20 token used for trades.
     * @param _initialFunds Initial funds deposited into the market maker.
     * @param _positionsAddress Address of the ERC1155 contract managing user positions.
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
    ) Ownable(msg.sender) {}

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
    function buyShares(uint256 outcomeIndex, uint256 numShares)
        public
        nonReentrant
        whenNotPaused;

    /**
     * @notice Sells shares for a specific outcome.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares to sell.
     * @dev Burns the user's shares and transfers tokens back to the user.
     * Emits a {SharesSold} event.
     */
    function sellShares(uint256 outcomeIndex, uint256 numShares)
        public
        nonReentrant
        whenNotPaused;

    /**
     * @notice Closes the market when the end time is reached.
     * @dev Can only be called after the market end time.
     * Emits a {MarketClosed} event.
     */
    function closeMarket() public;

    /**
     * @notice Sets the winning outcome for the market.
     * @param _winningOutcome The index of the winning outcome.
     * @dev Can only be called by the oracle and after the market is closed.
     * Emits an {OutcomeSet} event.
     */
    function setOutcome(uint256 _winningOutcome) public onlyOracle;

    /**
     * @notice Claims the payout for a user holding shares of the winning outcome.
     * @dev Transfers tokens to the user based on their shareholding.
     * Emits a {PayoutClaimed} event.
     */
    function claimPayout() public nonReentrant whenNotPaused;

    /**
     * @notice Withdraws collected fees to the fee recipient.
     * @dev Can only be called by the fee recipient.
     * Emits a {FeesWithdrawn} event.
     */
    function withdrawFees() external;

    /**
     * @notice Deposits additional funds into the market maker.
     * @param amount The amount of funds to deposit.
     * @dev Can only be called by the owner.
     * Emits a {FundsDeposited} event.
     */
    function depositInitialFunds(uint256 amount) external onlyOwner;

    /**
     * @notice Estimates the cost of purchasing a given number of shares.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares to purchase.
     * @return The estimated cost of purchasing the shares.
     */
    function estimateCost(uint256 outcomeIndex, uint256 numShares)
        public
        view
        returns (uint256);

    /**
     * @notice Estimates the payment for selling a given number of shares.
     * @param outcomeIndex The index of the selected outcome.
     * @param numShares The number of shares to sell.
     * @return The estimated payment for selling the shares.
     */
    function estimatePayment(uint256 outcomeIndex, uint256 numShares)
        public
        view
        returns (uint256);

    /**
     * @notice Gets the total number of outcomes in the market.
     * @return The number of outcomes.
     */
    function getOutcomeCount() external view returns (uint256);

    /**
     * @notice Gets the total shares for a specific outcome.
     * @param outcomeIndex The index of the outcome.
     * @return The total shares for the outcome.
     */
    function getOutcomeTotalShares(uint256 outcomeIndex)
        external
        view
        returns (uint256);

    /**
     * @notice Gets the user's share balance for a specific outcome.
     * @param user The address of the user.
     * @param outcomeIndex The index of the outcome.
     * @return The user's share balance for the outcome.
     */
    function getUserShares(address user, uint256 outcomeIndex)
        external
        view
        returns (uint256);

    /**
     * @notice Updates the oracle address.
     * @param _newOracle The new oracle address.
     * @dev Can only be called by the owner.
     */
    function updateOracle(address _newOracle) external onlyOwner;

    /**
     * @notice Pauses the contract.
     * @dev Can only be called by the owner.
     */
    function pause() external onlyOwner;

    /**
     * @notice Unpauses the contract.
     * @dev Can only be called by the owner.
     */
    function unpause() external onlyOwner;
}
