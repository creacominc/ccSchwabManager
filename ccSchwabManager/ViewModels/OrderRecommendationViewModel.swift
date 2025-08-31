import Foundation
import SwiftUI

/// ViewModel responsible for managing the state and coordination of order recommendations
@MainActor
class OrderRecommendationViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var recommendedSellOrders: [SalesCalcResultsRecord] = []
    @Published var recommendedBuyOrders: [BuyOrderRecord] = []
    @Published var currentOrders: [(String, Any)] = []
    @Published var isLoadingTaxLots = false
    @Published var loadingProgress: Double = 0.0
    @Published var loadingMessage = "Loading tax lot data..."
    @Published var selectedSellOrderIndex: Int? = nil
    @Published var selectedBuyOrderIndex: Int? = nil
    
    // MARK: - Private Properties
    private let orderService = OrderRecommendationService()
    
    // MARK: - Public Interface
    
    /// Calculates and updates recommended orders based on current data
    /// - Parameters:
    ///   - symbol: The trading symbol
    ///   - atrValue: Average True Range value
    ///   - taxLotData: Tax lot information for the position
    ///   - sharesAvailableForTrading: Number of shares available for trading
    ///   - currentPrice: Current market price
    func updateRecommendedOrders(
        symbol: String,
        atrValue: Double,
        taxLotData: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        currentPrice: Double
    ) async {
        
        // Early validation
        guard !taxLotData.isEmpty, sharesAvailableForTrading > 0 else {
            recommendedSellOrders = []
            recommendedBuyOrders = []
            currentOrders = []
            return
        }
        
        // Calculate orders in parallel
        async let sellOrders = orderService.calculateRecommendedSellOrders(
            symbol: symbol,
            atrValue: atrValue,
            taxLotData: taxLotData,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice
        )
        
        async let buyOrders = orderService.calculateRecommendedBuyOrders(
            symbol: symbol,
            atrValue: atrValue,
            taxLotData: taxLotData,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice
        )
        
        // Wait for both to complete
        let (sellResults, buyResults) = await (sellOrders, buyOrders)
        
        // Update state
        recommendedSellOrders = sellResults
        recommendedBuyOrders = buyResults
        currentOrders = createAllOrders(sellOrders: sellResults, buyOrders: buyResults)
    }
    
    /// Loads tax lots in the background
    /// - Parameter symbol: The trading symbol to load tax lots for
    /// - Returns: The computed tax lots
    func loadTaxLotsInBackground(symbol: String) async -> [SalesCalcPositionsRecord] {
        guard !isLoadingTaxLots else { return [] }
        
        isLoadingTaxLots = true
        loadingProgress = 0.0
        loadingMessage = "Initializing tax lot calculation..."
        
        defer {
            isLoadingTaxLots = false
            loadingProgress = 0.0
            loadingMessage = ""
        }
        
        // Simulate progress updates
        await updateLoadingProgress(0.1, "Fetching transaction history...")
        
        // Use the optimized tax lot calculation
        let taxLots = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = SchwabClient.shared.computeTaxLotsOptimized(symbol: symbol, currentPrice: nil)
                continuation.resume(returning: result)
            }
        }
        
        await updateLoadingProgress(0.8, "Processing tax lot data...")
        
        // Update the UI
        loadingProgress = 1.0
        loadingMessage = "Tax lot calculation complete!"
        
        // Hide the loading message after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.loadingProgress = 0.0
            self.loadingMessage = ""
        }
        
        return taxLots
    }
    
    /// Cancels the current tax lot calculation
    func cancelTaxLotCalculation() {
        // No longer needed as tax lot calculation is not managed by a Task
    }
    
    /// Clears all cached data and resets the view model state
    func clearCache() {
        recommendedSellOrders.removeAll()
        recommendedBuyOrders.removeAll()
        currentOrders.removeAll()
        selectedSellOrderIndex = nil
        selectedBuyOrderIndex = nil
    }
    
    /// Gets the currently selected sell orders
    var selectedSellOrders: [SalesCalcResultsRecord] {
        guard let index = selectedSellOrderIndex,
              index < recommendedSellOrders.count else { return [] }
        return [recommendedSellOrders[index]]
    }
    
    /// Gets the currently selected buy orders
    var selectedBuyOrders: [BuyOrderRecord] {
        guard let index = selectedBuyOrderIndex,
              index < recommendedBuyOrders.count else { return [] }
        return [recommendedBuyOrders[index]]
    }
    
    /// Gets all currently selected orders
    var selectedOrders: [(String, Any)] {
        var orders: [(String, Any)] = []
        
        if let sellIndex = selectedSellOrderIndex,
           sellIndex < recommendedSellOrders.count {
            orders.append(("SELL", recommendedSellOrders[sellIndex]))
        }
        
        if let buyIndex = selectedBuyOrderIndex,
           buyIndex < recommendedBuyOrders.count {
            orders.append(("BUY", recommendedBuyOrders[buyIndex]))
        }
        
        return orders
    }
    
    // MARK: - Private Helper Methods
    
    private func updateLoadingProgress(_ progress: Double, _ message: String) async {
        loadingProgress = progress
        loadingMessage = message
    }
    
    private func createAllOrders(sellOrders: [SalesCalcResultsRecord], buyOrders: [BuyOrderRecord]) -> [(String, Any)] {
        var orders: [(String, Any)] = []
        
        // Add sell orders first
        for order in sellOrders {
            orders.append(("SELL", order))
        }
        
        // Add buy orders
        for order in buyOrders {
            orders.append(("BUY", order))
        }
        
        return orders
    }
}
