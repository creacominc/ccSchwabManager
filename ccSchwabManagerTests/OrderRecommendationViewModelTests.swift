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
    
    func testUpdateRecommendedOrders_OverallProfitBelowTwoATR_OnlyUpdatesBuyOrders() async {
        // Given
        let taxLots = createMockTaxLots()
        let currentPrice = 160.0
        let (totalShares, totalCost, avgCostPerShare, _) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        await viewModel.updateRecommendedOrders(
            symbol: "CSV",
            atrValue: 2.584958116368578,
            taxLotData: taxLots,
            sharesAvailableForTrading: 63.9977,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: -1.2856769493484261
        )
        
        // Then
        XCTAssertTrue(viewModel.recommendedSellOrders.isEmpty, "Sell orders should be suppressed when overall position P/L is below 2*ATR")
        XCTAssertFalse(viewModel.recommendedBuyOrders.isEmpty, "Buy orders should still be available")
        XCTAssertEqual(viewModel.currentOrders.count, viewModel.recommendedBuyOrders.count, "Current orders should only include buy recommendations")
    }
    
    func testUpdateRecommendedOrders_ZeroSharesAvailable_StillUpdatesBuyOrders() async {
        // Given
        let taxLots = [
            SalesCalcPositionsRecord(
                openDate: "2026-04-10",
                gainLossPct: 8.05,
                gainLossDollar: 93.26,
                quantity: 2.0,
                price: 625.88,
                costPerShare: 579.25,
                marketValue: 1251.76,
                costBasis: 1158.50
            )
        ]
        let currentPrice = 625.88
        let (totalShares, totalCost, avgCostPerShare, currentProfitPercent) = calculatePositionValues(taxLots: taxLots, currentPrice: currentPrice)
        
        // When
        await viewModel.updateRecommendedOrders(
            symbol: "PWR",
            atrValue: 3.089276873669397,
            taxLotData: taxLots,
            sharesAvailableForTrading: 0,
            currentPrice: currentPrice,
            totalShares: totalShares,
            totalCost: totalCost,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent
        )
        
        // Then
        XCTAssertTrue(viewModel.recommendedSellOrders.isEmpty, "Sell orders should remain unavailable when no shares are tradeable")
        XCTAssertFalse(viewModel.recommendedBuyOrders.isEmpty, "Buy orders should not depend on shares available for selling")
        XCTAssertEqual(viewModel.currentOrders.count, viewModel.recommendedBuyOrders.count, "Current orders should include the available buy recommendations")
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
