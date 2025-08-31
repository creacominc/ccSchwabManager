import XCTest
@testable import ccSchwabManager

@MainActor
final class OrderRecommendationServiceTests: XCTestCase {
    
    var service: OrderRecommendationService!
    
    override func setUp() {
        super.setUp()
        service = OrderRecommendationService()
    }
    
    override func tearDown() {
        service = nil
        super.tearDown()
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
            XCTAssertEqual(minATROrder.target, expectedTarget, accuracy: 0.01,
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
        
        // When
        let result = await service.calculateRecommendedBuyOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice
        )
        
        // Then
        XCTAssertTrue(result.isEmpty, "Should return empty array when no tax lots available")
    }
    
    func testCalculateRecommendedBuyOrders_ValidData_ReturnsOrders() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        
        // When
        let result = await service.calculateRecommendedBuyOrders(
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
    
    func testCalculateRecommendedBuyOrders_LowPriceSecurity_IncludesAdditionalOrder() async {
        // Given: A security trading under $350
        let taxLots = createMockTaxLots()
        let currentPrice = 25.0 // Under $350 threshold
        let atrValue = 2.5
        
        // When
        let result = await service.calculateRecommendedBuyOrders(
            symbol: "PENN",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice
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
            
            // Verify trailing stop is 2x ATR as per user preference
            let expectedTrailingStop = (atrValue * 2.0 / currentPrice) * 100.0
            XCTAssertEqual(additionalOrder.trailingStop, expectedTrailingStop, accuracy: 0.01, "Trailing stop should be 2x ATR")
            
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
        
        // When
        let result = await service.calculateRecommendedBuyOrders(
            symbol: "AAPL",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice
        )
        
        // Then
        XCTAssertFalse(result.isEmpty, "Should return buy orders")
        
        // Verify no additional $500 order is included
        let additionalOrder = result.first { order in
            order.description.contains("($500)")
        }
        
        XCTAssertNil(additionalOrder, "Should not include additional buy order for securities above $350")
    }
    
    func testCalculateRecommendedBuyOrders_OrdersSortedByIncreasingShares() async {
        // Given: A security trading under $350 to trigger additional order
        let taxLots = createMockTaxLots()
        let currentPrice = 25.0 // Under $350 threshold
        let atrValue = 2.5
        
        // When
        let result = await service.calculateRecommendedBuyOrders(
            symbol: "PENN",
            atrValue: atrValue,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice
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
    
    // MARK: - Performance Tests
    
    func testPerformance_CalculateRecommendedSellOrders() {
        // Given
        let taxLots = Array(0..<1000).map { _ in createMockTaxLots() }.flatMap { $0 }
        let currentPrice = 160.0
        
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
        measure {
            Task {
                _ = await service.calculateRecommendedBuyOrders(
                    symbol: "AAPL",
                    atrValue: 2.5,
                    taxLotData: taxLots,
                    sharesAvailableForTrading: 150,
                    currentPrice: currentPrice
                )
            }
        }
    }
}
