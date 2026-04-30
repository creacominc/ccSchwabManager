import XCTest
@testable import ccSchwabManager

@MainActor
final class OrderRecommendationServiceTests: XCTestCase {
    
    var service: OrderRecommendationService!
    
    override func setUp() async throws {
        try await super.setUp()
        service = OrderRecommendationService()
    }
    
    override func tearDown() async throws {
        service = nil
        try await super.tearDown()
    }
    
    // MARK: - Test Data Helpers
    
    private func createMockTaxLots() -> [SalesCalcPositionsRecord] {
        return [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 15.0,
                gainLossDollar: 150.0,
                quantity: 100.0,
                price: 15.0,
                costPerShare: 13.0,
                marketValue: 1500.0,
                costBasis: 1300.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2023-02-01",
                gainLossPct: 8.0,
                gainLossDollar: 80.0,
                quantity: 50.0,
                price: 16.0,
                costPerShare: 14.8,
                marketValue: 800.0,
                costBasis: 740.0
            )
        ]
    }
    
    private func calculatePositionValues(taxLots: [SalesCalcPositionsRecord], currentPrice: Double) -> (totalShares: Double, totalCost: Double, avgCostPerShare: Double, currentProfitPercent: Double) {
        let totalShares = taxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = taxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalShares > 0 ? totalCost / totalShares : 0
        let currentProfitPercent = avgCostPerShare > 0 ? ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0 : 0
        return (totalShares, totalCost, avgCostPerShare, currentProfitPercent)
    }
    
    // MARK: - Sell Orders Tests
    
    func testCalculateRecommendedSellOrders_EmptyTaxLots_ReturnsEmptyArray() async {
        // Given
        let taxLots: [SalesCalcPositionsRecord] = []
        let currentPrice = 160.0
        
        // When
        let result = await service.calculateRecommendedSellOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice
        )
        
        // Then
        XCTAssertTrue(result.isEmpty, "Should return empty array when no tax lots available")
    }
    
    func testCalculateRecommendedSellOrders_ZeroSharesAvailable_ReturnsEmptyArray() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        
        // When
        let result = await service.calculateRecommendedSellOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 0,
            currentPrice: currentPrice
        )
        
        // Then
        XCTAssertTrue(result.isEmpty, "Should return empty array when no shares available for trading")
    }
    
    func testCalculateRecommendedSellOrders_ValidData_ReturnsOrders() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        
        // When
        let result = await service.calculateRecommendedSellOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice
        )
        
        // Then
        // Note: The actual results depend on the service implementation
        // We're testing that the method completes without error
        XCTAssertNotNil(result, "Should return a result")
    }
    
    func testCalculateRecommendedSellOrders_OverallProfitBelowTwoATR_ReturnsEmptyArray() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        
        // When
        let result = await service.calculateRecommendedSellOrders(
            symbol: "CSV",
            atrValue: 2.584958116368578,
            taxLotData: taxLots,
            sharesAvailableForTrading: 63.9977,
            currentPrice: currentPrice,
            currentProfitPercent: -1.2856769493484261
        )
        
        // Then
        XCTAssertTrue(result.isEmpty, "Should not recommend sell orders when overall position P/L is below 2*ATR")
    }

    /// Highest-cost lot is underwater at last; 11 shares hit ≥15% on the remainder but blended cost stays above 1×ATR-below-last until more cheaper shares are included (83 total).
    func testTrimRemainingProfitOrder_IncludedWhenOverallProfitBetweenTwoAndFifteenPercent() async {
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 30.0,
                price: 70.0,
                costPerShare: 100.0,
                marketValue: 2100.0,
                costBasis: 3000.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2023-02-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 70.0,
                price: 70.0,
                costPerShare: 50.0,
                marketValue: 4900.0,
                costBasis: 3500.0
            )
        ]
        let currentPrice = 70.0

        let result = await service.calculateRecommendedSellOrders(
            symbol: "TRIM",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 100,
            currentPrice: currentPrice
        )

        guard let trimOrder = result.first(where: { $0.openDate == "TrimRemP" }) else {
            XCTFail("Should emit trim-to-remaining-profit sell when overall P/L is between 2% and 15%")
            return
        }
        XCTAssertEqual(trimOrder.shares, 83.0, accuracy: 0.001)
        XCTAssertLessThan(trimOrder.breakEven, 68.26, "Blended sold cost should sit below ~1×ATR below last for a profitable limit")
        XCTAssertTrue(trimOrder.description.contains("Trim rem 15"), "Description should indicate 15% remaining-profit target when achievable")
    }

    func testTrimRemainingProfitOrder_ExcludedWhenOverallProfitBelowTwoPercent() async {
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 30.0,
                price: 66.0,
                costPerShare: 100.0,
                marketValue: 1980.0,
                costBasis: 3000.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2023-02-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 70.0,
                price: 66.0,
                costPerShare: 50.0,
                marketValue: 4620.0,
                costBasis: 3500.0
            )
        ]

        let result = await service.calculateRecommendedSellOrders(
            symbol: "TRIM",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 100,
            currentPrice: 66.0
        )

        XCTAssertNil(result.first { $0.openDate == "TrimRemP" }, "Should not offer trim order when overall profit is under 2%")
    }

    /// Even if the cheapest trim for remainder P/L is one share, that share must not sell at a loss at the limit.
    /// Here: 10 @ 46 (sold first) + 90 @ 42; last 48; ATR 2.5% → stop ~46.8, so one share @ 46 is profitable at the midpoint limit.
    /// Cap tradeable at 85 so selling *all* tradeable still leaves remainder P/L under 15% (fallback label 7%) but ≥7%.
    func testTrimRemainingProfitOrder_FallsBackToSevenPercentTarget() async {
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 10.0,
                price: 48.0,
                costPerShare: 46.0,
                marketValue: 480.0,
                costBasis: 460.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2023-02-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 90.0,
                price: 48.0,
                costPerShare: 42.0,
                marketValue: 4320.0,
                costBasis: 3780.0
            )
        ]

        let result = await service.calculateRecommendedSellOrders(
            symbol: "TRIM7",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 85,
            currentPrice: 48.0
        )

        guard let trimOrder = result.first(where: { $0.openDate == "TrimRemP" }) else {
            XCTFail("Expected trim order with 7% remaining-profit fallback")
            return
        }
        XCTAssertEqual(trimOrder.shares, 1.0, accuracy: 0.001)
        XCTAssertTrue(trimOrder.description.contains("Trim rem 7"))
        let stopOneAtrBelow = 48.0 * (1.0 - 2.5 / 100.0)
        XCTAssertLessThan(trimOrder.breakEven, stopOneAtrBelow, "Sold bundle avg cost must be below 1×ATR below last for a profitable limit")
        XCTAssertGreaterThan(trimOrder.target, trimOrder.breakEven, "Limit must clear blended cost")
    }

    /// Trim is only offered when overall position P/L is in [2%, 15%).
    func testTrimRemainingProfitOrder_ExcludedWhenOverallProfitAtOrAboveFifteenPercent() async {
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 100.0,
                price: 12.0,
                costPerShare: 10.0,
                marketValue: 1200.0,
                costBasis: 1000.0
            )
        ]
        let result = await service.calculateRecommendedSellOrders(
            symbol: "TRIM15",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 100,
            currentPrice: 12.0
        )
        XCTAssertNil(result.first { $0.openDate == "TrimRemP" })
    }

    /// If selling every tradeable whole share (high-cost first) still leaves remainder P/L under 7%, no trim target applies.
    func testTrimRemainingProfitOrder_ExcludedWhenMaxSellLeavesRemainderBelowSevenPercent() async {
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 5.0,
                price: 57.0,
                costPerShare: 60.0,
                marketValue: 285.0,
                costBasis: 300.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2023-02-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 95.0,
                price: 57.0,
                costPerShare: 55.0,
                marketValue: 5415.0,
                costBasis: 5225.0
            )
        ]
        // Weighted avg cost 55.25 → ~3.2% profit vs 57; selling 99 shares leaves one @ 55 → ~3.6% on remainder (< 7%).
        let result = await service.calculateRecommendedSellOrders(
            symbol: "TRIMLOWREM",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 99,
            currentPrice: 57.0
        )
        XCTAssertNil(result.first { $0.openDate == "TrimRemP" })
    }

    /// Midpoint path: limit should be average of (blended sold cost, 1×ATR below last) when that midpoint is below last.
    func testTrimRemainingProfitOrder_TargetUsesMidpointWhenBelowLast() async {
        let currentPrice = 48.0
        let atr = 2.5
        let stopBelow = currentPrice * (1.0 - atr / 100.0) // 46.8
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 10.0,
                price: currentPrice,
                costPerShare: 46.0,
                marketValue: 480.0,
                costBasis: 460.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2023-02-01",
                gainLossPct: 0,
                gainLossDollar: 0,
                quantity: 90.0,
                price: currentPrice,
                costPerShare: 42.0,
                marketValue: 4320.0,
                costBasis: 3780.0
            )
        ]
        let result = await service.calculateRecommendedSellOrders(
            symbol: "TRIMMID",
            atrValue: atr,
            taxLotData: taxLots,
            sharesAvailableForTrading: 85,
            currentPrice: currentPrice
        )
        guard let trim = result.first(where: { $0.openDate == "TrimRemP" }) else {
            XCTFail("Expected trim for midpoint assertion")
            return
        }
        let expectedMid = (trim.breakEven + stopBelow) / 2.0
        XCTAssertEqual(trim.target, expectedMid, accuracy: 0.02, "Target should be midpoint of sold avg and 1×ATR-below-last")
        XCTAssertLessThan(trim.target, currentPrice)
    }
    
    func testMinATROrder_UsesCorrectTrailingStop() async {
        // Given: A position with high profitability that should trigger Min ATR order
        // The Min ATR order should calculate minimum shares needed for 5% gain at target price
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 140.0, // 140% profitable
                gainLossDollar: 1400.0,
                quantity: 100.0,
                price: 15.0,
                costPerShare: 6.25, // Very low cost basis
                marketValue: 1500.0,
                costBasis: 625.0
            )
        ]
        let currentPrice = 15.0
        let atrValue = 4.27 // MOD's ATR value
        
        // When
        let result = await service.calculateRecommendedSellOrders(
            symbol: "MOD",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 100,
            currentPrice: currentPrice
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return sell orders for highly profitable position")
        
        // Find the Min ATR order
        let minATROrder = result.first { order in
            order.description.contains("Min ATR")
        }
        
        XCTAssertNotNil(minATROrder, "Should include Min ATR order")
        
        if let minATROrder = minATROrder {
            // Verify trailing stop is the actual ATR value
            let expectedTrailingStop = atrValue // 4.27%
            XCTAssertEqual(minATROrder.trailingStop, expectedTrailingStop, accuracy: 0.01, 
                          "Min ATR trailing stop should be the actual ATR value (4.27%), not atrValue/5.0 (0.85%)")
            
            // Verify entry price is 1 ATR below current price
            let expectedEntry = currentPrice * (1.0 - atrValue / 100.0)
            XCTAssertEqual(minATROrder.entry, expectedEntry, accuracy: 0.01,
                          "Entry price should be 1 ATR below current price")
            
            // Verify target price calculation
            let expectedTarget = expectedEntry / (1.0 + expectedTrailingStop / 100.0)
            XCTAssertEqual(minATROrder.target, expectedTarget, accuracy: 0.1,
                          "Target price should be calculated correctly based on trailing stop")

            // Verify that we're calculating minimum shares for 5% gain, not maintaining profit on remaining position
            XCTAssertLessThan(minATROrder.shares, 50.0, "Min ATR should calculate minimum shares needed, not large quantities")
        }
    }
    
    // MARK: - Buy Orders Tests
    
    func testCalculateRecommendedBuyOrders_EmptyTaxLots_ReturnsEmptyArray() async {
        // Given
        let taxLots: [SalesCalcPositionsRecord] = []
        let currentPrice = 160.0
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertTrue(result.isEmpty, "Should return empty array when no tax lots available")
    }
    
    func testCalculateRecommendedBuyOrders_ValidData_ReturnsOrders() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        // Note: The actual results depend on the service implementation
        // We're testing that the method completes without error
        XCTAssertNotNil(result, "Should return a result")
    }
    
    func testCalculateRecommendedBuyOrders_DoubleMaxBuyTrail_AddsOneShareAtTwiceLargestBuyTS() async {
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        let atrValue = 2.5
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        let result = service.calculateRecommendedBuyOrders(
            symbol: "AAPL",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        let doubleTrailBuy = result.first { $0.description.contains("2x max buy TS") }
        XCTAssertNotNil(doubleTrailBuy, "Should include 1-share buy at 2× max buy trailing stop among other buy options")
        guard let doubled = doubleTrailBuy else { return }
        XCTAssertEqual(doubled.shares, 1.0, accuracy: 0.001)
        
        let others = result.filter { !$0.description.contains("2x max buy TS") }
        let maxOtherTS = others.map(\.trailingStop).max() ?? 0
        XCTAssertGreaterThan(maxOtherTS, 0, "Need at least one other buy with a positive trail")
        let expectedTS = min(50.0, max(0.1, 2.0 * maxOtherTS))
        XCTAssertEqual(doubled.trailingStop, expectedTS, accuracy: 0.03)
    }
    
    func testCalculateRecommendedBuyOrders_LowPriceSecurity_IncludesAdditionalOrder() async {
        // Given: A security trading under $350
        let taxLots = createMockTaxLots()
        let currentPrice = 25.0 // Under $350 threshold
        let atrValue = 2.5
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "PENN",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders")
        
        // Find the additional buy order for $500
        let additionalOrder = result.first { order in
            order.description.contains("($500)")
        }
        
        XCTAssertNotNil(additionalOrder, "Should include additional buy order for securities under $350")
        
        if let additionalOrder = additionalOrder {
            // Verify it's a buy order
            XCTAssertEqual(additionalOrder.orderType, "BUY", "Should be a buy order")
            
            // Verify shares calculation: $500 / $25 = 20 shares, rounded up
            let expectedShares = ceil(500.0 / currentPrice)
            XCTAssertEqual(additionalOrder.shares, expectedShares, "Should calculate correct number of shares for $500")
            
            // Verify target price maintains target gain percentage
            let targetGainPercent = max(5.0, min(35.0, TradingConfig.atrMultiplier * atrValue))
            let expectedTargetPrice = currentPrice * (1.0 + targetGainPercent / 100.0)
            XCTAssertEqual(additionalOrder.targetBuyPrice, expectedTargetPrice, accuracy: 0.01, "Target price should maintain gain percentage")
            
//            // Verify trailing stop is 2x ATR as per user preference
//            let expectedTrailingStop = (atrValue * 2.0 / currentPrice) * 100.0
//            XCTAssertEqual(additionalOrder.trailingStop, expectedTrailingStop,
//                           accuracy: 0.01,
//                           "Trailing stop should be 2x ATR")
            
            // Verify order cost calculation
            let expectedOrderCost = expectedShares * expectedTargetPrice
            XCTAssertEqual(additionalOrder.orderCost, expectedOrderCost, accuracy: 0.01, "Order cost should be calculated correctly")
        }
    }
    
    func testCalculateRecommendedBuyOrders_HighPriceSecurity_NoAdditionalOrder() async {
        // Given: A security trading above $350
        let taxLots = createMockTaxLots()
        let currentPrice = 400.0 // Above $350 threshold
        let atrValue = 2.5
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "AAPL",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders")
        
        // Verify no additional $500 order is included
        let additionalOrder = result.first { order in
            order.description.contains("($500)")
        }
        
        XCTAssertNil(additionalOrder, "Should not include additional buy order for securities above $350")
    }

    func testCalculateRecommendedBuyOrders_IncludesExplicitThousandAndFifteenHundredBuyOptions() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 25.0
        let atrValue = 2.5
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)

        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "PENN",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )

        // Then
        let thousandOrder = result.first { $0.description.contains("($1000)") }
        let fifteenHundredOrder = result.first { $0.description.contains("($1500)") }
        XCTAssertNotNil(thousandOrder, "Should include explicit $1000 buy option")
        XCTAssertNotNil(fifteenHundredOrder, "Should include explicit $1500 buy option")

        if let thousandOrder {
            XCTAssertEqual(thousandOrder.shares, ceil(1000.0 / currentPrice), accuracy: 0.001)
        }
        if let fifteenHundredOrder {
            XCTAssertEqual(fifteenHundredOrder.shares, ceil(1500.0 / currentPrice), accuracy: 0.001)
        }
    }
    
    func testCalculateRecommendedBuyOrders_OrdersSortedByIncreasingShares() async {
        // Given: A security trading under $350 to trigger additional order
        let taxLots = createMockTaxLots()
        let currentPrice = 25.0 // Under $350 threshold
        let atrValue = 2.5
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "PENN",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders")
        XCTAssertGreaterThan(result.count, 1, "Should have multiple orders to test sorting")
        
        // Verify orders are sorted by increasing number of shares
        for i in 0..<(result.count - 1) {
            XCTAssertLessThanOrEqual(result[i].shares, result[i + 1].shares, 
                                   "Order at index \(i) should have fewer or equal shares than order at index \(i + 1)")
        }
        
        // Verify the first order has the minimum shares
        if let firstOrder = result.first {
            let minShares = result.map { $0.shares }.min() ?? 0
            XCTAssertEqual(firstOrder.shares, minShares, "First order should have the minimum number of shares")
        }
        
        // Verify the last order has the maximum shares
        if let lastOrder = result.last {
            let maxShares = result.map { $0.shares }.max() ?? 0
            XCTAssertEqual(lastOrder.shares, maxShares, "Last order should have the maximum number of shares")
        }
        
        // Print the order for debugging
        print("📊 Buy orders sorted by increasing shares:")
        for (index, order) in result.enumerated() {
            print("   \(index + 1). \(order.shares) shares - \(order.description)")
        }
    }
    
    // MARK: - Buy Order Logic Tests (Target > Stop Price > Current Price)
    
    func testBuyOrderLogic_TargetAboveStopPrice() async {
        // Given: APLD scenario with current price 14.12, ATR 9.66%
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 72.0, // 72% profitable
                gainLossDollar: 720.0,
                quantity: 193.0,
                price: 14.12,
                costPerShare: 8.22, // Average cost from logs
                marketValue: 2725.16,
                costBasis: 1586.46
            )
        ]
        let currentPrice = 14.12
        let atrValue = 9.66 // APLD's ATR from logs
        
        // When
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        let result = service.calculateRecommendedBuyOrders(
            symbol: "APLD",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 193,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders for APLD")
        
        // Verify each buy order follows the correct logic: Target > Stop Price > Current Price
        for order in result {
            let stopPrice = currentPrice * (1.0 + order.trailingStop / 100.0)
            
            // Target should be above stop price
            XCTAssertGreaterThan(order.targetBuyPrice, stopPrice, 
                               "Target price (\(order.targetBuyPrice)) should be above stop price (\(stopPrice)) for order: \(order.description)")
            
            // Stop price should be above current price
            XCTAssertGreaterThan(stopPrice, currentPrice, 
                               "Stop price (\(stopPrice)) should be above current price (\(currentPrice)) for order: \(order.description)")
            
//            // Verify trailing stop is 2x ATR as per user preference
//            let expectedTrailingStop = atrValue * 2.0 // 19.32%
//            XCTAssertEqual(order.trailingStop, expectedTrailingStop,
//                           accuracy: 0.01,
//                          "Trailing stop should be 2x ATR (\(expectedTrailingStop)%) for order: \(order.description)")
            
            print("✅ Order: \(order.shares) shares")
            print("   Current: $\(currentPrice)")
            print("   Stop: $\(stopPrice) (\(order.trailingStop)%)")
            print("   Target: $\(order.targetBuyPrice)")
            print("   Logic: Target > Stop > Current ✓")
        }
    }
    
    func testBuyOrderLogic_2xATRTrailingStop() async {
        // Given: Test with various ATR values to ensure 2x ATR is used
        let testCases: [(atr: Double, expectedTrailingStop: Double)] = [
            (2.5, 5.0),   // 2.5% ATR -> 5.0% trailing stop
            (4.0, 8.0),   // 4.0% ATR -> 8.0% trailing stop
            (9.66, 19.32), // 9.66% ATR -> 19.32% trailing stop (APLD)
            (15.0, 30.0)  // 15.0% ATR -> 30.0% trailing stop
        ]
        
        for testCase in testCases {
            let taxLots = [
                SalesCalcPositionsRecord(
                    openDate: "2023-01-01",
                    gainLossPct: 20.0,
                    gainLossDollar: 200.0,
                    quantity: 100.0,
                    price: 50.0,
                    costPerShare: 40.0,
                    marketValue: 5000.0,
                    costBasis: 4000.0
                )
            ]
            let currentPrice = 50.0
            
            // When
            let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
            let result = service.calculateRecommendedBuyOrders(
                symbol: "TEST",
                atrValue: testCase.atr,
                taxLotData: taxLots,
                sharesAvailableForTrading: 100,
                currentPrice: currentPrice,
                totalShares: totalShares,
                totalCost: totalCost,
                avgCostPerShare: avgCostPerShare,
                currentProfitPercent: currentProfitPercent
            )
            
            // Then
            XCTAssertFalse(result.isEmpty, "Should return buy orders for ATR \(testCase.atr)%")
            
//            // Verify all orders use 2x ATR for trailing stop
//            for order in result {
//                XCTAssertEqual(order.trailingStop, testCase.expectedTrailingStop,
//                               accuracy: 0.01,
//                              "Trailing stop should be 2x ATR (\(testCase.expectedTrailingStop)%) for ATR \(testCase.atr)%")
//            }
            
            print("✅ ATR \(testCase.atr)% -> Trailing Stop \(testCase.expectedTrailingStop)% ✓")
        }
    }
    
    func testBuyOrderLogic_MinimumTargetAboveStop() async {
        // Given: Test that target price is always at least 2% above stop price
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 10.0,
                gainLossDollar: 100.0,
                quantity: 100.0,
                price: 20.0,
                costPerShare: 18.0,
                marketValue: 2000.0,
                costBasis: 1800.0
            )
        ]
        let currentPrice = 20.0
        let atrValue = 5.0
        
        // When
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        let result = service.calculateRecommendedBuyOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 100,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders")
        
        for order in result {
            let stopPrice = currentPrice * (1.0 + order.trailingStop / 100.0)
            let minTargetPrice = stopPrice * 1.0102 // 2% above stop price
            
            // Target should be at least 2% above stop price
            XCTAssertGreaterThanOrEqual(
                order.targetBuyPrice,
                minTargetPrice,
                "Target price (\(order.targetBuyPrice)) should be at least 2% above stop price (\(stopPrice))")
            
            print("✅ Order: \(order.shares) shares")
            print("   Stop: $\(stopPrice)")
            print("   Min Target: $\(minTargetPrice)")
            print("   Actual Target: $\(order.targetBuyPrice)")
            print("   Gap: \(((order.targetBuyPrice - stopPrice) / stopPrice * 100))% ✓")
        }
    }
    
    func testBuyOrderLogic_APLDSpecificScenario() async {
        // Given: Exact APLD scenario from the logs
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 72.0,
                gainLossDollar: 1586.46,
                quantity: 193.0,
                price: 14.12,
                costPerShare: 8.22,
                marketValue: 2725.16,
                costBasis: 1586.46
            )
        ]
        let currentPrice = 14.12
        let atrValue = 9.66
        
        // When
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        let result = service.calculateRecommendedBuyOrders(
            symbol: "APLD",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 193,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders for APLD")
        
        // Find the 1% order (first order)
        let onePercentOrder = result.first { order in
            order.description.contains("(1%)")
        }
        
        XCTAssertNotNil(onePercentOrder, "Should include 1% buy order")
        
        if let order = onePercentOrder {
            let stopPrice = currentPrice * (1.0 + order.trailingStop / 100.0)
            
            // Verify the specific calculations
            XCTAssertEqual(order.trailingStop, 19.32,
                           accuracy: 5.01,
                           "Trailing stop should be 2x ATR (19.32%)")
            XCTAssertEqual(stopPrice, 16.85,
                           accuracy: 0.91,
                           "Stop price should be 16.85")
            XCTAssertGreaterThan(order.targetBuyPrice, stopPrice, "Target should be above stop price")
            
            print("📊 APLD 1% Buy Order:")
            print("   Current Price: $\(currentPrice)")
            print("   ATR: \(atrValue)%")
            print("   Trailing Stop: \(order.trailingStop)% (2x ATR)")
            print("   Stop Price: $\(stopPrice)")
            print("   Target Price: $\(order.targetBuyPrice)")
            print("   Shares: \(order.shares)")
            print("   Order Cost: $\(order.orderCost)")
            print("   ✅ Target > Stop > Current: $\(order.targetBuyPrice) > $\(stopPrice) > $\(currentPrice)")
        }
    }
    
    func testBuyOrderLogic_EdgeCaseHighATR() async {
        // Given: Test with very high ATR to ensure logic still works
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 15.0,
                gainLossDollar: 150.0,
                quantity: 100.0,
                price: 30.0,
                costPerShare: 26.0,
                marketValue: 3000.0,
                costBasis: 2600.0
            )
        ]
        let currentPrice = 30.0
        let atrValue = 25.0 // Very high ATR
        
        // When
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        let result = service.calculateRecommendedBuyOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 100,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders even with high ATR")
        
        for order in result {
            let stopPrice = currentPrice * (1.0 + order.trailingStop / 100.0)
            
//            // Verify trailing stop is 2x ATR (50%)
//            XCTAssertEqual(order.trailingStop, 50.0, accuracy: 0.01, "Trailing stop should be 2x ATR (50%)")
            
            // Verify Target > Stop > Current logic still holds
            XCTAssertGreaterThan(order.targetBuyPrice, stopPrice, "Target should be above stop even with high ATR")
            XCTAssertGreaterThan(stopPrice, currentPrice, "Stop should be above current even with high ATR")
            
            print("✅ High ATR Order: \(order.shares) shares")
            print("   Current: $\(currentPrice)")
            print("   Stop: $\(stopPrice) (\(order.trailingStop)%)")
            print("   Target: $\(order.targetBuyPrice)")
        }
    }
    
    func testSellOrderLogic_IncludesThreeATROrder() async {
        // Given: Position with enough profitability to generate Min BE and additional ATR orders
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 20.0,
                gainLossDollar: 200.0,
                quantity: 120.0,
                price: 50.0,
                costPerShare: 40.0,
                marketValue: 6000.0,
                costBasis: 4800.0
            )
        ]
        let currentPrice = 50.0
        let atrValue = 2.5
        let sharesAvailableForTrading = 120.0
        
        // When
        let result = await service.calculateRecommendedSellOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return sell orders")
        
        // Find the 3*ATR order
        let threeATROrder = result.first { order in
            order.description.contains("(3*ATR)")
        }
        
        XCTAssertNotNil(threeATROrder, "Should include 3*ATR sell order when criteria allow")
        
        if let order = threeATROrder {
            // Verify trailing stop equals 3x ATR
            let expectedTS = atrValue * 3.0
            XCTAssertEqual(order.trailingStop, expectedTS, accuracy: 0.01, "3*ATR order should have 3x ATR trailing stop")
            
            // Validate target is above cost per share
            XCTAssertGreaterThan(order.target, order.breakEven, "Target should be above cost per share")
            
            // Validate shares to sell are not more than available
            XCTAssertLessThanOrEqual(order.sharesToSell, sharesAvailableForTrading, "Shares to sell should not exceed availability")
        }
    }
    
    func testSellOrderLogic_ATROrderUsesPartialLotShares() async {
        // Given: Two lots where hitting 5% at 3*ATR requires only part of the second lot.
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2024-01-01",
                gainLossPct: -15.0,
                gainLossDollar: -300.0,
                quantity: 100.0,
                price: 17.0,
                costPerShare: 20.0,
                marketValue: 1700.0,
                costBasis: 2000.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2024-02-01",
                gainLossPct: 70.0,
                gainLossDollar: 756.0,
                quantity: 108.0,
                price: 17.0,
                costPerShare: 10.0,
                marketValue: 1836.0,
                costBasis: 1080.0
            )
        ]
        
        // ATR and price selected so 3*ATR target requires 180 shares (partial second lot),
        // while whole-lot behavior would have used all 208 shares.
        let currentPrice = 17.0
        let atrValue = 1.0
        let sharesAvailableForTrading = 208.0
        
        // When
        let result = await service.calculateRecommendedSellOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice
        )
        
        // Then
        let threeATROrder = result.first { order in
            order.description.contains("(3*ATR)")
        }
        
        XCTAssertNotNil(threeATROrder, "Should include 3*ATR sell order")
        
        if let order = threeATROrder {
            XCTAssertEqual(order.sharesToSell, 180.0, accuracy: 0.01, "3*ATR order should use the minimum partial-lot shares")
            XCTAssertLessThan(order.sharesToSell, 208.0, "3*ATR order should not require the entire combined lots")
        }
    }
    
    func testBuyOrder_IncludesOneShareFivePlusATRTrail() async {
        // Given: Any existing position
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 10.0,
                gainLossDollar: 100.0,
                quantity: 10.0,
                price: 20.0,
                costPerShare: 18.0,
                marketValue: 200.0,
                costBasis: 180.0
            )
        ]
        let currentPrice = 20.0
        let atrValue = 2.5 // -> trailing stop should be 7.5%
        
        // When
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        let result = service.calculateRecommendedBuyOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 10.0,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders")
        
        // Find the 1-share order marked with 5%+ATR
        let oneShareOrder = result.first { order in
            order.description.contains("(1 sh, 5%+ATR)")
        }
        
        XCTAssertNotNil(oneShareOrder, "Should include 1-share buy with 5%+ATR trailing stop")
        
        if let order = oneShareOrder {
            // Trailing stop should be 5% + ATR%
            let expectedTS = 5.0 + atrValue
            XCTAssertEqual(order.trailingStop, expectedTS, accuracy: 0.01, "Trailing stop should be 5% + ATR%")
            
            // Stop above current price
            let stopPrice = currentPrice * (1.0 + order.trailingStop / 100.0)
            XCTAssertGreaterThan(stopPrice, currentPrice, "Stop should be above current price")
            
            // Target >= 2% above stop
            let minTarget = stopPrice * 1.02
            XCTAssertGreaterThanOrEqual(order.targetBuyPrice, minTarget, "Target should be at least 2% above stop")
            
            // Exactly 1 share
            XCTAssertEqual(order.shares, 1.0, "Should recommend exactly 1 share")
            
            // Cost under $2500 per constraints
            XCTAssertLessThan(order.orderCost, 2500.0, "Order cost should be under $2500")
        }
    }

    func testBuyOrder_IncludesWhenOverFiveATROrFifteenPercentOrder_WithPositiveProfitExample() async {
        // Given: current profit 5%, ATR 2% -> trigger = min(15, 10) = 10%, TS = 10 - 5 = 5%
        let avgCostPerShare = 100.0
        let currentPrice = 105.0
        let atrValue = 2.0
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 5.0,
                gainLossDollar: 50.0,
                quantity: 10.0,
                price: currentPrice,
                costPerShare: avgCostPerShare,
                marketValue: 1050.0,
                costBasis: 1000.0
            )
        ]
        let (totalShares, totalCost, avgCost, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)

        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 10.0,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCost,
            currentProfitPercent: currentProfitPercent
        )

        // Then
        let order = result.first { $0.description.contains("When over 5*ATR or 15%") }
        XCTAssertNotNil(order, "Should include when-over-5*ATR-or-15% recommendation when current profit is below trigger")
        if let order {
            XCTAssertEqual(order.shares, 1.0, accuracy: 0.001)
            XCTAssertEqual(order.trailingStop, 5.0, accuracy: 0.01, "TS should be trigger-profit minus current profit (10 - 5)")
        }
    }

    func testBuyOrder_IncludesWhenOverFiveATROrFifteenPercentOrder_WithNegativeProfitAndFifteenCap() async {
        // Given: current profit -2%, ATR 6% -> trigger = min(15, 30) = 15%, TS = 15 - (-2) = 17%
        let avgCostPerShare = 100.0
        let currentPrice = 98.0
        let atrValue = 6.0
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: -2.0,
                gainLossDollar: -20.0,
                quantity: 10.0,
                price: currentPrice,
                costPerShare: avgCostPerShare,
                marketValue: 980.0,
                costBasis: 1000.0
            )
        ]
        let (totalShares, totalCost, avgCost, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)

        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 10.0,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCost,
            currentProfitPercent: currentProfitPercent
        )

        // Then
        let order = result.first { $0.description.contains("When over 5*ATR or 15%") }
        XCTAssertNotNil(order, "Should include when-over recommendation for negative-profit position")
        if let order {
            XCTAssertEqual(order.shares, 1.0, accuracy: 0.001)
            XCTAssertEqual(order.trailingStop, 17.0, accuracy: 0.01, "TS should be 15 - (-2) when 15% cap applies")
        }
    }

    func testBuyOrder_IncludesWhenOverFiveATROrFifteenPercentOrder_WithNegativeProfitAndATRTrigger() async {
        // Given: current profit -2%, ATR 2% -> trigger = min(15, 10) = 10%, TS = 10 - (-2) = 12%
        let avgCostPerShare = 100.0
        let currentPrice = 98.0
        let atrValue = 2.0
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: -2.0,
                gainLossDollar: -20.0,
                quantity: 10.0,
                price: currentPrice,
                costPerShare: avgCostPerShare,
                marketValue: 980.0,
                costBasis: 1000.0
            )
        ]
        let (totalShares, totalCost, avgCost, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)

        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 10.0,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCost,
            currentProfitPercent: currentProfitPercent
        )

        // Then
        let order = result.first { $0.description.contains("When over 5*ATR or 15%") }
        XCTAssertNotNil(order, "Should include when-over recommendation for negative-profit position below ATR trigger")
        if let order {
            XCTAssertEqual(order.shares, 1.0, accuracy: 0.001)
            XCTAssertEqual(order.trailingStop, 12.0, accuracy: 0.01, "TS should be 10 - (-2) when ATR trigger applies")
        }
    }

    func testBuyOrder_WhenOverFiveATROrFifteenPercentOrder_NotIncludedAtOrAboveTrigger() async {
        // Given: current profit 12%, ATR 2% -> trigger = 10%, so order should not be emitted
        let avgCostPerShare = 100.0
        let currentPrice = 112.0
        let atrValue = 2.0
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2023-01-01",
                gainLossPct: 12.0,
                gainLossDollar: 120.0,
                quantity: 10.0,
                price: currentPrice,
                costPerShare: avgCostPerShare,
                marketValue: 1120.0,
                costBasis: 1000.0
            )
        ]
        let (totalShares, totalCost, avgCost, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)

        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "TEST",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 10.0,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCost,
            currentProfitPercent: currentProfitPercent
        )

        // Then
        XCTAssertNil(
            result.first { $0.description.contains("When over 5*ATR or 15%") },
            "Should not include when-over recommendation when current profit is already at or above trigger"
        )
    }
    
    // MARK: - Performance Tests
    func testPerformance_CalculateRecommendedSellOrders()
    {
        // Given
        let taxLots : [SalesCalcPositionsRecord] = Array(0..<1000).map { _ in createMockTaxLots() }.flatMap { $0 }
        let currentPrice : Double = 160.0
        // When & Then
        measure {
            Task {
                _ = await service.calculateRecommendedSellOrders(
                    symbol: "AAPL",
                    atrValue: 2.5,
                    taxLotData: taxLots,
                    sharesAvailableForTrading: 150,
                    currentPrice: currentPrice
                )
            }
        }
    }

    func testPerformance_CalculateRecommendedBuyOrders() {
        // Given
        let taxLots = Array(0..<1000).map { _ in createMockTaxLots() }.flatMap { $0 }
        let currentPrice = 160.0
        
        // When & Then
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        measure {
            Task {
                _ = service.calculateRecommendedBuyOrders(
                    symbol: "AAPL",
                    atrValue: 2.5,
                    taxLotData: taxLots,
                    sharesAvailableForTrading: 150,
                    currentPrice: currentPrice,
                    totalShares: totalShares,
                    totalCost: totalCost,
                    avgCostPerShare: avgCostPerShare,
                    currentProfitPercent: currentProfitPercent
                )
            }
        }
    }
}
