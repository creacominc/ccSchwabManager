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
    
    // MARK: - Caching Properties
    private var cachedOrders: [String: CachedOrderData] = [:]
    private var lastCalculationTime: [String: Date] = [:]
    
    // Cache duration - orders are considered fresh for 5 minutes
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    // MARK: - Cached Data Structure
    private struct CachedOrderData {
        let sellOrders: [SalesCalcResultsRecord]
        let buyOrders: [BuyOrderRecord]
        let allOrders: [(String, Any)]
        let symbol: String
        let atrValue: Double
        let taxLotDataHash: Int
        let sharesAvailableForTrading: Double
        let currentPrice: Double
        let timestamp: Date
    }
    
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
        
        // Check cache first before calculating
        if let cachedData = getCachedOrders(
            symbol: symbol,
            atrValue: atrValue,
            taxLotData: taxLotData,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice
        ) {
            print("✅ Using cached orders for \(symbol)")
            recommendedSellOrders = cachedData.sellOrders
            recommendedBuyOrders = cachedData.buyOrders
            currentOrders = cachedData.allOrders
            return
        }
        
        print("🔄 No cache hit for \(symbol), calculating new orders...")
        
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
        
        AppLogger.shared.debug("=== updateRecommendedOrders: Results received ===")
        AppLogger.shared.debug("Sell results: \(sellResults.count) orders")
        for (index, order) in sellResults.enumerated() {
            AppLogger.shared.debug("  Sell result \(index + 1): trailingStop=\(order.trailingStop)%, shares=\(order.shares), target=\(order.target)")
        }
        
        AppLogger.shared.debug("Buy results: \(buyResults.count) orders")
        for (index, order) in buyResults.enumerated() {
            AppLogger.shared.debug("  Buy result \(index + 1): trailingStop=\(order.trailingStop)%, shares=\(order.shares), target=\(order.targetBuyPrice)")
        }
        
        // Update state
        recommendedSellOrders = sellResults
        recommendedBuyOrders = buyResults
        currentOrders = createAllOrders(sellOrders: sellResults, buyOrders: buyResults)
        
        AppLogger.shared.debug("=== updateRecommendedOrders: State updated ===")
        AppLogger.shared.debug("Current orders count: \(currentOrders.count)")
        for (index, (orderType, order)) in currentOrders.enumerated() {
            if let sellOrder = order as? SalesCalcResultsRecord {
                AppLogger.shared.debug("  Current order \(index + 1) (\(orderType)): trailingStop=\(sellOrder.trailingStop)%, shares=\(sellOrder.shares)")
            } else if let buyOrder = order as? BuyOrderRecord {
                AppLogger.shared.debug("  Current order \(index + 1) (\(orderType)): trailingStop=\(buyOrder.trailingStop)%, shares=\(buyOrder.shares)")
            }
        }
        
        // Cache the results for future use
        cacheOrders(
            symbol: symbol,
            atrValue: atrValue,
            taxLotData: taxLotData,
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice,
            sellOrders: sellResults,
            buyOrders: buyResults,
            allOrders: currentOrders
        )
        
        print("💾 Cached orders for \(symbol) - \(sellResults.count) sell orders, \(buyResults.count) buy orders")
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
    
    // MARK: - Caching Methods
    
    /// Checks if cached orders are available and valid for the given parameters
    private func getCachedOrders(
        symbol: String,
        atrValue: Double,
        taxLotData: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        currentPrice: Double
    ) -> CachedOrderData? {
        
        guard let cachedData = cachedOrders[symbol] else { 
            print("❌ No cached data found for \(symbol)")
            return nil 
        }
        
        // Check if cache is still valid (within time limit)
        let now = Date()
        let timeSinceCalculation = now.timeIntervalSince(cachedData.timestamp)
        guard timeSinceCalculation < cacheValidityDuration else { 
            print("❌ Cache expired for \(symbol) (age: \(String(format: "%.1f", timeSinceCalculation))s)")
            return nil 
        }
        
        // Check if all parameters match
        guard cachedData.symbol == symbol,
              cachedData.atrValue == atrValue,
              cachedData.sharesAvailableForTrading == sharesAvailableForTrading,
              cachedData.currentPrice == currentPrice,
              cachedData.taxLotDataHash == calculateTaxLotDataHash(taxLotData) else {
            
            print("❌ Cache parameters don't match for \(symbol):")
            print("  - symbol: \(cachedData.symbol) vs \(symbol)")
            print("  - atrValue: \(cachedData.atrValue) vs \(atrValue)")
            print("  - sharesAvailableForTrading: \(cachedData.sharesAvailableForTrading) vs \(sharesAvailableForTrading)")
            print("  - currentPrice: \(cachedData.currentPrice) vs \(currentPrice)")
            print("  - taxLotDataHash: \(cachedData.taxLotDataHash) vs \(calculateTaxLotDataHash(taxLotData))")
            return nil
        }
        
        print("✅ Cache hit for \(symbol) - \(cachedData.sellOrders.count) sell orders, \(cachedData.buyOrders.count) buy orders")
        return cachedData
    }
    
    /// Caches the calculated orders for future use
    private func cacheOrders(
        symbol: String,
        atrValue: Double,
        taxLotData: [SalesCalcPositionsRecord],
        sharesAvailableForTrading: Double,
        currentPrice: Double,
        sellOrders: [SalesCalcResultsRecord],
        buyOrders: [BuyOrderRecord],
        allOrders: [(String, Any)]
    ) {
        let cachedData = CachedOrderData(
            sellOrders: sellOrders,
            buyOrders: buyOrders,
            allOrders: allOrders,
            symbol: symbol,
            atrValue: atrValue,
            taxLotDataHash: calculateTaxLotDataHash(taxLotData),
            sharesAvailableForTrading: sharesAvailableForTrading,
            currentPrice: currentPrice,
            timestamp: Date()
        )
        
        cachedOrders[symbol] = cachedData
        lastCalculationTime[symbol] = Date()
    }
    
    /// Calculates a hash for tax lot data to detect changes
    private func calculateTaxLotDataHash(_ taxLotData: [SalesCalcPositionsRecord]) -> Int {
        var hasher = Hasher()
        
        for lot in taxLotData {
            hasher.combine(lot.quantity)
            hasher.combine(lot.costPerShare)
            hasher.combine(lot.costBasis)
            // Add other relevant fields that would affect order calculations
        }
        
        return hasher.finalize()
    }
    
    /// Clears the cache for a specific symbol
    private func clearCacheForSymbol(_ symbol: String) {
        cachedOrders.removeValue(forKey: symbol)
        lastCalculationTime.removeValue(forKey: symbol)
    }
    
    /// Clears all cached data
    private func clearAllCaches() {
        cachedOrders.removeAll()
        lastCalculationTime.removeAll()
    }
    
    private func updateLoadingProgress(_ progress: Double, _ message: String) async {
        loadingProgress = progress
        loadingMessage = message
    }
    
    private func createAllOrders(sellOrders: [SalesCalcResultsRecord], buyOrders: [BuyOrderRecord]) -> [(String, Any)] {
        AppLogger.shared.debug("=== createAllOrders ===")
        AppLogger.shared.debug("Input: \(sellOrders.count) sell orders, \(buyOrders.count) buy orders")
        
        var orders: [(String, Any)] = []
        
        // Add sell orders first
        for (index, order) in sellOrders.enumerated() {
            AppLogger.shared.debug("  Sell order \(index + 1): trailingStop=\(order.trailingStop)%, shares=\(order.shares), target=\(order.target)")
            orders.append(("SELL", order))
        }
        
        // Add buy orders
        for (index, order) in buyOrders.enumerated() {
            AppLogger.shared.debug("  Buy order \(index + 1): trailingStop=\(order.trailingStop)%, shares=\(order.shares), target=\(order.targetBuyPrice)")
            orders.append(("BUY", order))
        }
        
        AppLogger.shared.debug("Created \(orders.count) total orders")
        return orders
    }
}
