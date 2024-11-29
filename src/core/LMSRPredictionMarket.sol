// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/ABDKMath64x64.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PredictionMarketPositions.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract LMSRPredictionMarket is Ownable, ReentrancyGuard, Pausable {
    using ABDKMath64x64 for int128;

    struct Outcome {
        string name;
        uint256 totalShares; // Quantity q_i
    }

    Outcome[] public outcomes;
    uint256 public b; // LMSR liquidity parameter
    address public oracle;
    uint256 public marketEndTime;
    bool public marketClosed;
    bool public marketSettled;
    uint256 public winningOutcome;

    uint256 public marketMakerFunds = 0;
    uint256 public initialFunds = 0;
    uint256 public feePercent;
    address public feeRecipient;
    uint256 public collectedFees = 0;
    IERC20 public token;
    PredictionMarketPositions public positions;
    uint256 public marketId;
    string public title;

    uint256 public sharesDecimals = 10;
    uint8 public tokenDecimals = 18;
    uint256 public payoutPerShare = 1 * (10 ** tokenDecimals);

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
        positions = PredictionMarketPositions(_positionsAddress);
        marketMakerFunds = _initialFunds;
        initialFunds =_initialFunds;

        for (uint256 i = 0; i < _outcomes.length; i++) {
            outcomes.push(Outcome({name: _outcomes[i], totalShares: 0}));
        }
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Not authorized");
        _;
    }

    function getQuantities() internal view returns (uint256[] memory) {
        uint256[] memory q = new uint256[](outcomes.length);
        for (uint256 i = 0; i < outcomes.length; i++) {
            q[i] = outcomes[i].totalShares;
        }
        return q;
    }

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

    function buyShares(
        uint256 outcomeIndex,
        uint256 numShares
    ) public nonReentrant whenNotPaused {
        require(!marketClosed, "Market is closed");
        require(outcomeIndex < outcomes.length, "Invalid outcome");
        require(numShares > 0, "Must buy at least one share");

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
            ABDKMath64x64.fromUInt(10 ** sharesDecimals)
        );
        uint256 cost = ABDKMath64x64.toUInt(scaledCostDifference) *
            10 ** (tokenDecimals - sharesDecimals);

        // Calculate the fee
        uint256 feeAmount = (cost * feePercent) / (100);
        uint256 reinvestAmount = feeAmount / 2;
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
            ABDKMath64x64.fromUInt(10 ** sharesDecimals)
        );
        uint256 payment = ABDKMath64x64.toUInt(scaledCostDifference) *
            10 ** (tokenDecimals - sharesDecimals);

        // Apply fees
        uint256 feeAmount = (payment * feePercent) / (100);
        uint256 reinvestAmount = feeAmount / 2;
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
                    ABDKMath64x64.fromUInt(10 ** sharesDecimals)
                )
            );
    }

    function depositInitialFunds(uint256 amount) external onlyOwner {
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Initial fund transfer failed"
        );
        marketMakerFunds += amount;
        emit FundsDeposited(msg.sender, amount);
    }

    function closeMarket() public {
        require(block.timestamp >= marketEndTime, "Market not over yet");
        marketClosed = true;
        emit MarketClosed();
    }

    function setOutcome(uint256 _winningOutcome) public onlyOracle {
        require(marketClosed, "Market still open");
        require(!marketSettled, "Market already settled");
        require(_winningOutcome < outcomes.length, "Invalid outcome");
        require(!marketSettled, "Market already settled");

        winningOutcome = _winningOutcome;
        marketSettled = true;

        emit OutcomeSet(_winningOutcome);
    }

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
        uint256 payout = (userSharesAmount * payoutPerShare); // / (10 ** sharesDecimals);

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

    function withdrawFees() external {
        require(msg.sender == feeRecipient, "Not authorized");
        uint256 amount = collectedFees;
        collectedFees = 0;
        // Transfer the collected fees in ERC-20 tokens to the feeRecipient
        require(token.transfer(feeRecipient, amount), "Fee withdrawal failed");
        emit FeesWithdrawn(feeRecipient, amount);
    }

    function getUserShares(
        address user,
        uint256 outcomeIndex
    ) external view returns (uint256) {
        uint256 tokenId = positions.getTokenId(marketId, outcomeIndex);
        return positions.balanceOf(user, tokenId);
    }

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
            ABDKMath64x64.fromUInt(10 ** sharesDecimals)
        );
        uint256 cost = ABDKMath64x64.toUInt(scaledCostDifference) *
            10 ** (tokenDecimals - sharesDecimals);

        uint256 feeAmount = (cost * feePercent) / 100;
        uint256 netCost = cost + feeAmount;

        return netCost;
    }

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
            ABDKMath64x64.fromUInt(10 ** sharesDecimals)
        );
        uint256 payment = ABDKMath64x64.toUInt(scaledCostDifference) *
            10 ** (tokenDecimals - sharesDecimals);

        uint256 feeAmount = (payment * feePercent) / 100;
        uint256 netpayment = payment + feeAmount;

        return netpayment;
    }

    function updateOracle(address _newOracle) external onlyOwner {
        require(_newOracle != address(0), "Invalid oracle address");
        oracle = _newOracle;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawRemainingFunds() external onlyOwner {
        require(marketSettled, "Market not settled yet");
        uint256 remainingFunds = marketMakerFunds;
        marketMakerFunds = 0;
        require(
            token.transfer(feeRecipient, remainingFunds),
            "Withdrawal failed"
        );
    }

    function getPositionId(
        uint256 _marketId,
        uint256 outcomeIndex
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(_marketId, outcomeIndex)));
    }

    //Getter functions added
    function getOutcomeCount() external view returns (uint256) {
        return outcomes.length;
    }

    function getOutcomeTotalShares(
        uint256 outcomeIndex
    ) external view returns (uint256) {
        require(outcomeIndex < outcomes.length, "Invalid outcome index");
        return outcomes[outcomeIndex].totalShares;
    }
}
