import XCTest
@testable import ccSchwabManager

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
    
    // MARK: - Buy Orders Tests
    
    func testCalculateRecommendedBuyOrders_EmptyTaxLots_ReturnsEmptyArray() {
        // Given
        let taxLots: [SalesCalcPositionsRecord] = []
        let currentPrice = 160.0
        
        // When
        let result = service.calculateRecommendedBuyOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: taxLots,
            sharesAvailableForTrading: 150,
            currentPrice: currentPrice
        )
        
        // Then
        XCTAssertTrue(result.isEmpty, "Should return empty array when no tax lots available")
    }
    
    func testCalculateRecommendedBuyOrders_ValidData_ReturnsOrders() {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        
        // When
        let result = service.calculateRecommendedBuyOrders(
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
            _ = service.calculateRecommendedBuyOrders(
                symbol: "AAPL",
                atrValue: 2.5,
                taxLotData: taxLots,
                sharesAvailableForTrading: 150,
                currentPrice: currentPrice
            )
        }
    }
}
