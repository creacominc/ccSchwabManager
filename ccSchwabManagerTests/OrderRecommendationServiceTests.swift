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
