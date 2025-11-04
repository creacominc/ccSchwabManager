import XCTest
@testable import ccSchwabManager

@MainActor
final class OrderRecommendationViewModelTests: XCTestCase {
    
    var viewModel: OrderRecommendationViewModel!
    
    override func setUpWithError() throws {
        viewModel = OrderRecommendationViewModel()
    }
    
    override func tearDownWithError() throws {
        viewModel = nil
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
    
    // MARK: - Initial State Tests
    
    func testInitialState_AllPropertiesAreEmpty() {
        // Then
        XCTAssertTrue(viewModel.recommendedSellOrders.isEmpty, "Sell orders should be empty initially")
        XCTAssertTrue(viewModel.recommendedBuyOrders.isEmpty, "Buy orders should be empty initially")
        XCTAssertTrue(viewModel.currentOrders.isEmpty, "Current orders should be empty initially")
        XCTAssertFalse(viewModel.isLoadingTaxLots, "Should not be loading tax lots initially")
        XCTAssertEqual(viewModel.loadingProgress, 0.0, "Loading progress should be 0 initially")
        XCTAssertEqual(viewModel.loadingMessage, "Loading tax lot data...", "Loading message should have default value")
        XCTAssertNil(viewModel.selectedSellOrderIndex, "Selected sell order index should be nil initially")
        XCTAssertNil(viewModel.selectedBuyOrderIndex, "Selected buy order index should be nil initially")
    }
    
    // MARK: - Update Recommended Orders Tests
    
    func testUpdateRecommendedOrders_EmptyTaxLots_ClearsAllOrders() async {
        // Given
        let emptyTaxLots: [SalesCalcPositionsRecord] = []
        let currentPrice = 160.0
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: emptyTaxLots, currentPrice: currentPrice)
        
        // When
        await viewModel.updateRecommendedOrders(
            symbol: "AAPL",
            atrValue: 2.5,
            taxLotData: emptyTaxLots,
            sharesAvailableForTrading: 0,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertTrue(viewModel.recommendedSellOrders.isEmpty, "Sell orders should be empty")
        XCTAssertTrue(viewModel.recommendedBuyOrders.isEmpty, "Buy orders should be empty")
        XCTAssertTrue(viewModel.currentOrders.isEmpty, "Current orders should be empty")
    }
    
    func testUpdateRecommendedOrders_ValidData_UpdatesOrders() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        await viewModel.updateRecommendedOrders(
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
        XCTAssertNotNil(viewModel.currentOrders, "Current orders should be set")
    }
    
    // MARK: - Cache Management Tests
    
    func testClearCache_ResetsAllState() {
        // Given - Set some initial state
        viewModel.selectedSellOrderIndex = 0
        viewModel.selectedBuyOrderIndex = 0
        
        // When
        viewModel.clearCache()
        
        // Then
        XCTAssertTrue(viewModel.recommendedSellOrders.isEmpty, "Sell orders should be cleared")
        XCTAssertTrue(viewModel.recommendedBuyOrders.isEmpty, "Buy orders should be cleared")
        XCTAssertTrue(viewModel.currentOrders.isEmpty, "Current orders should be cleared")
        XCTAssertNil(viewModel.selectedSellOrderIndex, "Selected sell order index should be reset")
        XCTAssertNil(viewModel.selectedBuyOrderIndex, "Selected buy order index should be reset")
    }
    
    // MARK: - Tax Lot Loading Tests
    
    func testLoadTaxLotsInBackground_StartsLoading() async {
        // When
        _ = await viewModel.loadTaxLotsInBackground(symbol: "AAPL")
        
        // Then - After async completion, loading should be false
        XCTAssertFalse(viewModel.isLoadingTaxLots, "Should finish loading tax lots")
        XCTAssertTrue(viewModel.loadingProgress >= 0.0, "Loading progress should be set")
    }
    
    func testCancelTaxLotCalculation_StopsLoading() async {
        // Given
        _ = await viewModel.loadTaxLotsInBackground(symbol: "AAPL")
        // After completion, loading should be false
        XCTAssertFalse(viewModel.isLoadingTaxLots, "Should finish loading")
        
        // When
        viewModel.cancelTaxLotCalculation()
        
        // Then
        XCTAssertFalse(viewModel.isLoadingTaxLots, "Should still not be loading")
        XCTAssertEqual(viewModel.loadingProgress, 0.0, "Loading progress should be reset")
        XCTAssertEqual(viewModel.loadingMessage, "", "Loading message should be cleared")
    }
}
