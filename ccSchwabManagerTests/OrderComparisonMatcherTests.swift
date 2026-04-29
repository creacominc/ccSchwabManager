import XCTest
@testable import ccSchwabManager

@MainActor
final class OrderComparisonMatcherTests: XCTestCase {
    private func makeCurrentOrder(
        side: CurrentOrderSide,
        quantity: Double = 100,
        limitPrice: Double? = 100,
        trailPercent: Double? = 2.0
    ) -> CurrentOrderDisplayInfo {
        let symbol = side == .sell ? "SELLSYM" : "BUYSYM"
        let instruction: OrderInstructionType = side == .sell ? .SELL_TO_CLOSE : .BUY_TO_OPEN
        let leg = OrderLegCollection(
            instrument: AccountsInstrument(symbol: symbol),
            instruction: instruction,
            positionEffect: side == .sell ? .CLOSING : .OPENING,
            quantity: quantity
        )
        let order = Order(
            duration: .GOOD_TILL_CANCEL,
            orderType: .TRAILING_STOP_LIMIT,
            quantity: quantity,
            stopPriceLinkBasis: side == .sell ? .ASK : .BID,
            stopPriceLinkType: .PERCENT,
            stopPriceOffset: trailPercent,
            price: limitPrice,
            orderLegCollection: [leg],
            orderStrategyType: .SINGLE,
            orderId: 999_001,
            status: .working
        )
        let quote = Quote(askPrice: 101, bidPrice: 99, lastPrice: 100, mark: 100)
        guard let info = CurrentOrderDisplayInfo(
            order: order,
            groupOrderId: order.orderId,
            quote: quote,
            lastPriceFallback: 100
        ) else {
            fatalError("Failed to construct CurrentOrderDisplayInfo test fixture")
        }
        return info
    }

    private func sellRecommendation(
        shares: Double,
        trailingStop: Double,
        target: Double = 105,
        breakEven: Double = 100,
        gain: Double = 5,
        description: String
    ) -> RecommendedOrderDisplayInfo {
        let record = SalesCalcResultsRecord(
            shares: shares,
            rollingGainLoss: (target - breakEven) * shares,
            breakEven: breakEven,
            gain: gain,
            sharesToSell: shares,
            trailingStop: trailingStop,
            entry: target + 1,
            target: target,
            cancel: target - 1,
            description: description,
            openDate: "test"
        )
        return RecommendedOrderDisplayInfo.from(
            sell: record,
            quote: Quote(askPrice: 101, bidPrice: 99, lastPrice: 100, mark: 100),
            lastPriceFallback: 100
        )
    }

    private func buyRecommendation(
        shares: Double,
        trailingStop: Double,
        targetBuyPrice: Double = 110,
        targetGainPercent: Double = 15,
        description: String
    ) -> RecommendedOrderDisplayInfo {
        let record = BuyOrderRecord(
            shares: shares,
            targetBuyPrice: targetBuyPrice,
            entryPrice: targetBuyPrice - 2,
            trailingStop: trailingStop,
            targetGainPercent: targetGainPercent,
            currentGainPercent: 5,
            sharesToBuy: shares,
            orderCost: shares * targetBuyPrice,
            description: description,
            orderType: "BUY",
            submitDate: "",
            isImmediate: false
        )
        return RecommendedOrderDisplayInfo.from(
            buy: record,
            quote: Quote(askPrice: 101, bidPrice: 99, lastPrice: 100, mark: 100),
            lastPriceFallback: 100
        )
    }

    func testBestSellReplacement_PrefersFiveATRWithFewestShares() {
        let current = makeCurrentOrder(side: .sell)
        let candidates = [
            sellRecommendation(shares: 50, trailingStop: 3, description: "(3*ATR) SELL -50 TEST"),
            sellRecommendation(shares: 40, trailingStop: 5, description: "(5*ATR) SELL -40 TEST"),
            sellRecommendation(shares: 30, trailingStop: 5, description: "(5*ATR) SELL -30 TEST")
        ]

        let best = OrderComparisonMatcher.bestMatch(for: current, sells: candidates, buys: [])

        XCTAssertNotNil(best)
        XCTAssertEqual(best?.sourceLabel, "5*ATR")
        XCTAssertEqual(best?.quantity, 30, accuracy: 0.001)
    }

    func testBestSellReplacement_FallsBackToMaxSharesWhenNoThreeATR() {
        let current = makeCurrentOrder(side: .sell)
        let candidates = [
            sellRecommendation(shares: 30, trailingStop: 1.5, description: "(Top 100) SELL -30 TEST"),
            sellRecommendation(shares: 45, trailingStop: 2.0, description: "(Min BE) SELL -45 TEST")
        ]

        let best = OrderComparisonMatcher.bestMatch(for: current, sells: candidates, buys: [])

        XCTAssertNotNil(best)
        XCTAssertEqual(best?.quantity, 45, accuracy: 0.001)
    }

    func testBestSellReplacement_RejectsUnprofitableCandidates() {
        let current = makeCurrentOrder(side: .sell)
        let candidates = [
            sellRecommendation(
                shares: 10,
                trailingStop: 5,
                target: 98,
                breakEven: 100,
                gain: -2,
                description: "(5*ATR) SELL -10 TEST"
            )
        ]

        let best = OrderComparisonMatcher.bestMatch(for: current, sells: candidates, buys: [])

        XCTAssertNil(best)
    }

    func testBestBuyReplacement_PrefersWhenOverRecommendation() {
        let current = makeCurrentOrder(side: .buy, quantity: 1, limitPrice: 105, trailPercent: 4)
        let candidates = [
            buyRecommendation(
                shares: 1,
                trailingStop: 12,
                targetBuyPrice: 114,
                targetGainPercent: 15,
                description: "BUY 1 XYZ (When over 5*ATR or 15%) Trigger=12.0% CurrP/L=4.0% Target=114 TS=8%"
            ),
            buyRecommendation(
                shares: 1,
                trailingStop: 20,
                targetBuyPrice: 116,
                targetGainPercent: 15,
                description: "BUY 1 XYZ (1 sh, 2x max buy TS 10.00%) Target=116 TS=20%"
            )
        ]

        let best = OrderComparisonMatcher.bestMatch(for: current, sells: [], buys: candidates)

        XCTAssertNotNil(best)
        XCTAssertTrue(best?.isWhenOverFiveATROrFifteenBuy == true)
    }

    func testBestBuyReplacement_UsesHighTrailThenLowestShares() {
        let current = makeCurrentOrder(side: .buy, quantity: 5, limitPrice: 103, trailPercent: 3)
        let candidates = [
            buyRecommendation(
                shares: 2,
                trailingStop: 9,
                targetBuyPrice: 111,
                targetGainPercent: 15,
                description: "BUY 2 XYZ (high gain A) Target=111 TS=9%"
            ),
            buyRecommendation(
                shares: 1,
                trailingStop: 9,
                targetBuyPrice: 110,
                targetGainPercent: 15,
                description: "BUY 1 XYZ (high gain B) Target=110 TS=9%"
            ),
            buyRecommendation(
                shares: 1,
                trailingStop: 7,
                targetBuyPrice: 109,
                targetGainPercent: 15,
                description: "BUY 1 XYZ (lower trail) Target=109 TS=7%"
            )
        ]

        let best = OrderComparisonMatcher.bestMatch(for: current, sells: [], buys: candidates)

        XCTAssertNotNil(best)
        XCTAssertEqual(best?.trailPercent, 9, accuracy: 0.001)
        XCTAssertEqual(best?.quantity, 1, accuracy: 0.001)
    }

    func testDeltaSentiment_ReflectsDirectionalImprovementBySide() {
        let currentSell = makeCurrentOrder(side: .sell, quantity: 80, limitPrice: 100, trailPercent: 3)
        let improvedSellSuggestion = sellRecommendation(
            shares: 40,
            trailingStop: 5,
            target: 110,
            description: "(5*ATR) SELL -40 TEST"
        )
        let sellComparison = OrderComparisonInfo(current: currentSell, suggestion: improvedSellSuggestion)
        XCTAssertEqual(sellComparison.sentiment(for: .quantity), .better)
        XCTAssertEqual(sellComparison.sentiment(for: .target), .better)
        XCTAssertEqual(sellComparison.sentiment(for: .trail), .better)

        let currentBuy = makeCurrentOrder(side: .buy, quantity: 1, limitPrice: 105, trailPercent: 6)
        let worseBuySuggestion = buyRecommendation(
            shares: 5,
            trailingStop: 4,
            targetBuyPrice: 103,
            targetGainPercent: 10,
            description: "BUY 5 XYZ (weaker buy) Target=103 TS=4%"
        )
        let buyComparison = OrderComparisonInfo(current: currentBuy, suggestion: worseBuySuggestion)
        XCTAssertEqual(buyComparison.sentiment(for: .quantity), .worse)
        XCTAssertEqual(buyComparison.sentiment(for: .target), .worse)
        XCTAssertEqual(buyComparison.sentiment(for: .trail), .worse)
    }
}
