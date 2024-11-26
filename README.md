# System Architecture and Components

Statia leverages a Logarithmic Market Scoring Rule (LMSR) model to dynamically adjust the costs and odds based on user participation, creating a responsive, self-regulating market. Key components of Statia include:

- **Prediction Market Module**: Manages market creation, share trading, and settlement using the LMSR cost function.
- **Oracles**: Trusted entities that verify event outcomes and ensure data accuracy.

## Prediction Market Module

### LMSR Cost Function

In Statia’s LMSR-based prediction market, the cost function, \(C(q)\), determines the price for purchasing shares in a particular outcome and adjusts as more bets are placed. This function ensures liquidity and dynamic pricing within the market.

The cost function for LMSR is defined as:

\[ 
C(q) = b \cdot \ln \left( \sum_{i=1}^{n} e^{\frac{q_i}{b}} \right)
\]

Where:
- \(C(q)\): Total cost required to reach a state \(q\), where \(q_i\) is the total amount bet on outcome \(i\).
- \(b\): Liquidity parameter, which controls the sensitivity of prices to new bets (higher \(b\) means greater liquidity and less responsive odds).
- \(n\): Number of outcomes.

#### Key Features

- **Dynamic Pricing**: The cost of betting increases with the total amount staked on a particular outcome, ensuring that odds for heavily favored outcomes adjust to discourage overloading.
- **Market Liquidity**: Implicit liquidity is provided through the cost function without external liquidity providers.
- **Initial Liquidity (Worst-Case Loss)**: To guarantee that the market can cover potential payouts, the worst-case loss is calculated as:

\[
L_{\text{max}} = b \cdot \ln(n)
\]

Where \(n\) is the number of outcomes.

- **Dynamic Odds**: The odds for each outcome \(i\) are calculated based on the relative stakes:

\[
p_i = \frac{e^{\frac{q_i}{b}}}{\sum_{j=1}^{n} e^{\frac{q_j}{b}}}
\]

### Share Trading

When a user buys shares in an outcome, the cost of shares is calculated as the difference between the current and previous states of the cost function.

\[
\text{Cost} = C(q_{\text{new}}) - C(q_{\text{current}})
\]

Where:
- \(q_{\text{current}}\): Current total stake in each outcome.
- \(q_{\text{new}}\): New stake after the user places a bet.

The number of shares received by a user when they place a bet of amount \(\Delta C\) on outcome \(i\) is given by:

\[
s = \frac{\Delta C}{p_i}
\]

Where \(p_i\) is the price per share for outcome \(i\), derived from the LMSR function.

#### Key Features

- **Impact of Bet Placement**: As more bets are placed on an outcome, \(p_i\) adjusts to reflect market sentiment, discouraging disproportionate betting on a single outcome.
- **Share Distribution**: Users placing a bet \(\Delta C\) on outcome \(i\) receive tokens based on current market odds.
- **Market Pricing Feedback**: Each bet placed adjusts costs for future bets and updates odds in real-time.
- **Redemption for Winning Outcome**: Upon event conclusion, holders of winning outcome tokens can redeem them based on the stakes.

### Market Settlement

After the event concludes and an outcome is verified by oracles, users holding winning shares can redeem their tokens for payouts. 

**Payout Calculation**: Each share of the winning outcome can be redeemed at a fixed payout of 1 unit.

\[
P_{\text{user}} = s_{\text{win}} \times (1 \text{ USD})
\]

Where \(s_{\text{win}}\) is the number of shares the user holds in the winning outcome.

## Oracles

Oracles are critical components responsible for determining the outcome of prediction markets. They are whitelisted entities specified at market creation to verify and submit outcomes securely.

### Oracle Process

1. **Event Monitoring**: The oracle monitors the event associated with the prediction market.
2. **Outcome Determination**: The oracle determines the correct outcome based on verifiable data.
3. **Outcome Submission**: The oracle submits the outcome to the smart contract using its whitelisted address.
4. **Market Settlement**: Upon receiving the outcome, the smart contract settles the market, allowing participants to redeem their winnings.

### Oracle Implementation

When creating a market, the creator specifies the oracle's address. The oracle can be:

- **An Individual Wallet**: A single entity controlling a wallet address.
- **A Multisignature Wallet (Multisig)**: A group of entities requiring multiple approvals to submit outcomes.
- **A Smart Contract**: An autonomous contract determining outcomes programmatically based on external data.

#### Features of Oracle Flexibility

- **Customization**: Market creators can select oracles with expertise suited to the event type.
- **Diversity**: Oracles can implement custom logic for consensus, dispute resolution, and staking based on the market type.
