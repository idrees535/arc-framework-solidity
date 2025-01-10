const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Prediction Market Stress Tests", function () {
    let owner, user1, user2,user3,oracle,feeRecipient;
    let Token, token;
    let MarketFactory, factory;
    let PredictionMarket, market;
    let PredictionMarketPositions, positions;

    let outcomes = ["Yes", "No"];
    let b = 1000//ethers.parseEther("500");
    let duration = 3600 * 24 * 30;  // 30 days
    let feePercent = 20;
    let marketId = 1;
    let initialFunds=ethers.parseUnits("1000", 18);
    let marketTitle="Will service provider Infura Face a delay of more than 5 minutes in next 30 days?"

    beforeEach(async () => {
        // Get signers
        [owner, user1, user2,user3,oracle,feeRecipient] = await ethers.getSigners();

        // Deploy ERC20 token
        Token = await ethers.getContractFactory("ERC20Token");
        token = await Token.deploy(ethers.parseUnits("10000000", 18));
        await token.waitForDeployment();

      

        // Deploy MarketFactory contract
        MarketFactory = await ethers.getContractFactory("MarketFactory");
        factory = await MarketFactory.deploy("https://metadata-uri.com/{id}.json");
        await factory.waitForDeployment();
    
        // Approve factory to mint tokens for test
        await token.approve(factory.getAddress(), ethers.parseUnits("100000", 18));
    });

    describe("Market Creation", function () {
        it("Should create a new market", async () => {
            const tx = await factory.createMarket(
                marketId,
                marketTitle,
                outcomes,
                oracle.getAddress(),
                b,
                duration,
                feePercent,
                feeRecipient,
                token.getAddress(),
                initialFunds);
            await tx.wait();

            const activeMarkets = await factory.getActiveMarkets();
            expect(activeMarkets.length).to.equal(1);

            const marketAddress = activeMarkets[0];
            market = await ethers.getContractAt("LMSRPredictionMarket", marketAddress);

            expect(await market.marketId()).to.equal(marketId);
        });

        it("Should emit MarketCreated event", async () => {
            await expect(factory.createMarket(marketId,
                marketTitle,
                outcomes,
                oracle.getAddress(),
                b,
                duration,
                feePercent,
                feeRecipient,
                token.getAddress(),
                initialFunds))
                .to.emit(factory, "MarketCreated");
        });
    });

    describe("Buying Shares", function () {
        beforeEach(async () => {
            // Create a new market
            const tx = await factory.createMarket(marketId,
                marketTitle,
                outcomes,
                oracle.getAddress(),
                b,
                duration,
                feePercent,
                feeRecipient,
                token.getAddress(),
                initialFunds);
            await tx.wait();
            const activeMarkets = await factory.getActiveMarkets();
            market = await ethers.getContractAt("LMSRPredictionMarket", activeMarkets[0]);
                // Retrieve the PredictionMarketPositions contract instance
        const positionsAddress = await factory.getPositions();
        positions = await ethers.getContractAt("PredictionMarketPositions", positionsAddress);
        });

        it("Should estimate cost to buy shares", async () => {
            const numShares = 10;
            const cost = await market.estimateCost(0, numShares); // Buying shares for outcome 0
            expect(cost).to.be.gt(0);
        });

        it("Should allow user to buy shares", async () => {
            const numShares = 30;
            const cost = await market.estimateCost(0, numShares);

            await token.transfer(user1.address, cost);
            await token.connect(user1).approve(market.getAddress(), cost);

            const tx = await market.connect(user1).buyShares(0, numShares); // Buy shares for outcome 0
            await tx.wait();

            const tokenId = await positions.getTokenId(marketId, 0)
            const balance = await positions.balanceOf(user1.address, tokenId); // Check share balance for outcome 0
            expect(balance).to.equal(numShares);
        });

        it("Should emit SharesPurchased event", async () => {
            const numShares = 10;
            const cost = await market.estimateCost(0, numShares);

            await token.transfer(user1.address, cost);
            await token.connect(user1).approve(market.getAddress(), cost);

            await expect(market.connect(user1).buyShares(0, numShares)) // Buy shares for outcome 0
                .to.emit(market, "SharesPurchased")
                .withArgs(user1.address, 0, numShares, cost);
        });
    });

    describe("Closing Market", function () {
        beforeEach(async () => {
            const tx = await factory.createMarket(marketId,
                marketTitle,
                outcomes,
                oracle.getAddress(),
                b,
                duration,
                feePercent,
                feeRecipient,
                token.getAddress(),
                initialFunds);
            await tx.wait();
            const activeMarkets = await factory.getActiveMarkets();
            market = await ethers.getContractAt("LMSRPredictionMarket", activeMarkets[0]);
        });

        it("Should allow the market to be closed after the duration", async () => {
            await ethers.provider.send("evm_increaseTime", [duration + 1]); // Simulate time passing
            await market.closeMarket();
            const isClosed = await market.marketClosed();
            expect(isClosed).to.equal(true);
        });

        it("Should emit MarketClosed event", async () => {
            await ethers.provider.send("evm_increaseTime", [duration + 1]); // Simulate time passing
            await expect(market.closeMarket()).to.emit(market, "MarketClosed");
        });
    });

    describe("Claiming Payouts", function () {
        beforeEach(async () => {
            const tx = await factory.createMarket(marketId,
                marketTitle,
                outcomes,
                oracle.getAddress(),
                b,
                duration,
                feePercent,
                feeRecipient,
                token.getAddress(),
                initialFunds);
            await tx.wait();
            const activeMarkets = await factory.getActiveMarkets();
            market = await ethers.getContractAt("LMSRPredictionMarket", activeMarkets[0]);

            const numShares = 10;
            const cost = await market.estimateCost(0, numShares);
            await token.transfer(user1.address, cost);
            await token.connect(user1).approve(market.getAddress(), cost);
            await market.connect(user1).buyShares(0, numShares); // User buys shares for outcome 0
        });

        it("Should allow the oracle to set the outcome", async () => {
            await ethers.provider.send("evm_increaseTime", [duration + 1]); // Simulate time passing
            await market.closeMarket();

            await market.connect(oracle).setOutcome(0); // Set outcome 0 as the winning outcome
            const winningOutcome = await market.winningOutcome();
            expect(winningOutcome).to.equal(0);
        });

        it("Should allow the user to claim payout", async () => {
            await ethers.provider.send("evm_increaseTime", [duration + 1]); // Simulate time passing
            await market.closeMarket();
            await market.connect(oracle).setOutcome(0); // Set outcome 0 as the winning outcome

            const userBalanceBefore = await token.balanceOf(user1.address);
            await market.connect(user1).claimPayout(); // User claims payout for outcome 0
            const userBalanceAfter = await token.balanceOf(user1.address);

            expect(userBalanceAfter).to.be.gt(userBalanceBefore); // User's balance should increase
        });

        it("Should emit PayoutClaimed event", async () => {
            await ethers.provider.send("evm_increaseTime", [duration + 1]); // Simulate time passing
            await market.closeMarket();
            await market.connect(oracle).setOutcome(0); // Set outcome 0 as the winning outcome

            await expect(market.connect(user1).claimPayout())
                .to.emit(market, "PayoutClaimed")
                .withArgs(user1.address, ethers.parseUnits("10",18)); // Expected payout amount based on shares
        });
    });

    describe("Fees Withdrawal", function () {
        beforeEach(async () => {
            const tx = await factory.createMarket(marketId,
                marketTitle,
                outcomes,
                oracle.getAddress(),
                b,
                duration,
                feePercent,
                feeRecipient,
                token.getAddress(),
                initialFunds);
            await tx.wait();
            const activeMarkets = await factory.getActiveMarkets();
            market = await ethers.getContractAt("LMSRPredictionMarket", activeMarkets[0]);

            const numShares = 10;
            const cost = await market.estimateCost(0, numShares);
            await token.transfer(user1.address, cost);
            await token.connect(user1).approve(market.getAddress(), cost);
            await market.connect(user1).buyShares(0, numShares); // User buys shares for outcome 0
        });

        it("Should allow the feeRecipient to withdraw collected fees", async () => {
        

            const feeRecipientBalanceBefore = await token.balanceOf(feeRecipient.address);
            await market.connect(feeRecipient).withdrawFees(); // Owner withdraws fees
            const feeRecipientBalanceAfter = await token.balanceOf(feeRecipient.address);

            expect(feeRecipientBalanceAfter).to.be.gt(feeRecipientBalanceBefore); // Fees should increase owner's balance
        });

        it("Should emit event when fees are withdrawn", async () => {
            await expect(market.connect(feeRecipient).withdrawFees()).to.emit(market, "FeesWithdrawn");
        });
    });

    describe("Payout in Extreme Buy Sell Scenario Test", function () {
        beforeEach(async () => {
            const tx = await factory.createMarket(marketId,
                marketTitle,
                outcomes,
                oracle.getAddress(),
                b,
                duration,
                feePercent,
                feeRecipient,
                token.getAddress(),
                initialFunds);
            await tx.wait();
            const activeMarkets = await factory.getActiveMarkets();
            market = await ethers.getContractAt("LMSRPredictionMarket", activeMarkets[0]);

            const numShares = 10;
            const cost = await market.estimateCost(0, numShares);
            await token.transfer(user1.address, cost);
            await token.connect(user1).approve(market.getAddress(), cost);
            await market.connect(user1).buyShares(0, numShares); // User buys shares for outcome 0
        });
        it("user 1 buys large amount of shares of a certain outcome significanlty mpving price in one direction, making otehr oucome very cheaper, user 2 buys other outcome cheaply for a very large amount and this other outcome is decalerd as winning outcoem and user 2 buying shares", async function () {
            // Step 1: User 1 buys a large number of shares in outcome 0
            

            const user1SharesOutcome0 = 1000;
            console.log('market address:', await market.getAddress())
            console.log("Oracle:", oracle ? oracle.address : "Oracle is null");
            const estimatedCostUser1 = await market.estimateCost(0, user1SharesOutcome0);
            console.log('estimatedCostUser1',estimatedCostUser1)
            await token.transfer(user1.address, estimatedCostUser1);
            await token.connect(user1).approve(await market.getAddress(), estimatedCostUser1);
            console.log('tokens transfereed')

            console.log(`User 1 buying ${user1SharesOutcome0} shares in outcome 0`);
            await market.connect(user1).buyShares(0, user1SharesOutcome0);

            console.log(`Cost for User 1: ${estimatedCostUser1}, Market maker funds: ${await market.marketMakerFunds()}`);
            console.log(`Updated prices: ${(await market.getPrice(0)).toString()}`);

            // Step 2: User 2 buys shares in outcome 1, which is now cheaper
            const user2SharesOutcome1 = 100;
            const estimatedCostUser2 = await market.estimateCost(1, user2SharesOutcome1);
            await token.transfer(user2.address, estimatedCostUser2);
            await token.connect(user2).approve(await market.getAddress(), estimatedCostUser2);

            console.log(`User 2 buying ${user2SharesOutcome1} shares in outcome 1`);
            await market.connect(user2).buyShares(1, user2SharesOutcome1);

            console.log(`Cost for User 2: ${estimatedCostUser2}, Market maker funds: ${await market.marketMakerFunds()}`);
            console.log(`Updated prices: ${(await market.getPrice(1)).toString()}`);

            // Step 3: Simulate the market being settled with outcome 1 as the winner
            await ethers.provider.send("evm_increaseTime", [duration + 1]); // Simulate time passing
            const tx= await market.closeMarket();
            await tx.wait();
            await market.connect(oracle).setOutcome(1); 

            console.log("Market settled with outcome 1 as the winning outcome");

            // Step 4: User 2 claims payout for outcome 1
            const user2BalanceBefore = await token.balanceOf(user2.address);
            await market.connect(user2).claimPayout();
            const user2BalanceAfter = await token.balanceOf(user2.address);

            
            // Ensure that User 2's balance increased after claiming payout
            expect(user2BalanceAfter).to.be.gt(user2BalanceBefore);

            // Final check on market maker funds
            const remainingFunds = await market.marketMakerFunds();
            console.log(`Final market maker funds after payout: ${remainingFunds}`);
        });
    });

   });
