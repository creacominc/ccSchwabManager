import SwiftUI

/// Refactored view for recommended OCO orders that separates business logic from presentation
struct RecommendedOCOOrdersSection: View {
    
    // MARK: - Properties
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let quoteData: QuoteData?
    let accountNumber: String
    let position: Position
    

    
    // MARK: - State
    @StateObject private var viewModel = OrderRecommendationViewModel()
    @State private var taxLotData: [SalesCalcPositionsRecord] = []
    @State private var copiedValue: String = "TBD"
    @State private var showingConfirmationDialog = false
    @State private var orderToSubmit: Order?
    @State private var orderDescriptions: [String] = []
    @State private var orderJson: String = ""
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var dialogStateTrigger = false
    
    // MARK: - Computed Properties
    private var currentPrice: Double? {
        // First try to get the real-time quote price
        if let quote = quoteData?.quote?.lastPrice {
            return quote
        }
        
        // Fallback to extended market price if available
        if let extendedPrice = quoteData?.extended?.lastPrice {
            return extendedPrice
        }
        
        // Fallback to regular market price if available
        if let regularPrice = quoteData?.regular?.regularMarketLastPrice {
            return regularPrice
        }
        
        return nil
    }
    
    private var hasSelectedOrders: Bool {
        viewModel.selectedSellOrderIndex != nil || viewModel.selectedBuyOrderIndex != nil
    }
    
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Loading indicator for tax lot calculation
            TaxLotLoadingIndicator(
                isLoading: viewModel.isLoadingTaxLots,
                progress: viewModel.loadingProgress,
                message: viewModel.loadingMessage,
                onCancel: {
                    viewModel.cancelTaxLotCalculation()
                }
            )

            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 8) {
                    // Sell Orders Section
                    SellOrdersSection(
                        sellOrders: viewModel.recommendedSellOrders,
                        selectedIndex: viewModel.selectedSellOrderIndex,
                        sharesAvailableForTrading: sharesAvailableForTrading,
                        onOrderSelection: { index in
                            viewModel.selectedSellOrderIndex = index
                        },
                        onCopyValue: copyToClipboard,
                        onCopyText: copyToClipboard
                    )

                    // Buy Orders Section
                    BuyOrdersSection(
                        buyOrders: viewModel.recommendedBuyOrders,
                        selectedIndex: viewModel.selectedBuyOrderIndex,
                        onOrderSelection: { index in
                            viewModel.selectedBuyOrderIndex = index
                        },
                        onCopyValue: copyToClipboard,
                        onCopyText: copyToClipboard
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Submit Button Section
                SubmitButtonSection(
                    hasSelectedOrders: hasSelectedOrders,
                    onSubmit: submitOrders
                )
                .frame(maxHeight: .infinity)
            }

            // Copy feedback text
            if copiedValue != "TBD" {
                HStack {
                    Spacer()
                    Text("Copied: \(copiedValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .cornerRadius(8)
        .onChange(of: symbol) { _, newSymbol in
            handleSymbolChange(newSymbol)
        }
        .onAppear {
            loadTaxLotsInBackground()
        }
        .onChange(of: atrValue) { _, _ in
            updateOrdersIfReady()
        }
        .onChange(of: sharesAvailableForTrading) { _, _ in
            updateOrdersIfReady()
        }
        .onChange(of: quoteData?.quote?.lastPrice) { _, _ in
            updateOrdersIfReady()
        }
        .sheet(isPresented: $showingConfirmationDialog) {
            OrderConfirmationDialog(
                isPresented: $showingConfirmationDialog,
                orderDescriptions: orderDescriptions,
                orderJson: orderJson,
                onConfirm: confirmAndSubmitOrder,
                onCancel: {
                    showingConfirmationDialog = false
                    orderToSubmit = nil
                    orderDescriptions = []
                    orderJson = ""
                },
                trailingStopValidation: validateTrailingStop
            )
        }
        .onChange(of: dialogStateTrigger) { _, _ in
            // Force UI update when trigger changes
        }
        .alert("Order Submission Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Order Submitted Successfully", isPresented: $showingSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your order has been submitted successfully.")
        }
    }
    
    // MARK: - Private Methods
    
    private func handleSymbolChange(_ newSymbol: String) {
        // Clear cache when symbol changes
        viewModel.clearCache()
        taxLotData.removeAll()
        copiedValue = "TBD"
        
        // Load tax lots for new symbol
        loadTaxLotsInBackground()
    }
    
    private func loadTaxLotsInBackground() {
        print("🔄 loadTaxLotsInBackground called for symbol: \(symbol)")
        Task {
            // Load tax lots and get the result
            let computedTaxLots = await viewModel.loadTaxLotsInBackground(symbol: symbol)
            
            print("📦 Received \(computedTaxLots.count) tax lots for \(symbol)")
            
            // Update the local tax lot data
            await MainActor.run {
                taxLotData = computedTaxLots
                print("💾 Updated taxLotData with \(taxLotData.count) tax lots")
            }
            
            // Only populate when we have aligned data for this symbol and tax lots are ready
            if viewModel.currentOrders.isEmpty && isDataReadyForCurrentSymbol() && !taxLotData.isEmpty {
                print("🚀 Calling updateOrdersIfReady for \(symbol)")
                updateOrdersIfReady()
            } else {
                print("⏸️ Not calling updateOrdersIfReady:")
                print("  - viewModel.currentOrders.isEmpty: \(viewModel.currentOrders.isEmpty)")
                print("  - isDataReadyForCurrentSymbol(): \(isDataReadyForCurrentSymbol())")
                print("  - !taxLotData.isEmpty: \(!taxLotData.isEmpty)")
            }
        }
    }
    
    private func isDataReadyForCurrentSymbol() -> Bool {
        // We consider data ready only when quoteData is present, matches the current symbol, and tax lots are available
        let hasQuoteData = quoteData != nil
        let hasMatchingSymbol = quoteData?.symbol == symbol
        let hasTaxLots = !taxLotData.isEmpty
        
        print("🔍 isDataReadyForCurrentSymbol debug:")
        print("  - hasQuoteData: \(hasQuoteData)")
        print("  - hasMatchingSymbol: \(hasMatchingSymbol)")
        print("  - hasTaxLots: \(hasTaxLots)")
        print("  - quoteData?.symbol: \(quoteData?.symbol ?? "nil")")
        print("  - symbol: \(symbol)")
        print("  - taxLotData.count: \(taxLotData.count)")
        
        if let dataSymbol = quoteData?.symbol, dataSymbol == symbol && !taxLotData.isEmpty { 
            print("✅ Data is ready for symbol \(symbol)")
            return true 
        }
        
        print("❌ Data is NOT ready for symbol \(symbol)")
        return false
    }
    
    private func updateOrdersIfReady() {
        print("🔄 updateOrdersIfReady called for symbol: \(symbol)")
        
        // Only recalculate if we have data, the symbol matches, and tax lots are ready
        guard isDataReadyForCurrentSymbol() && !taxLotData.isEmpty else { 
            print("❌ updateOrdersIfReady guard failed")
            return 
        }
        
        guard let currentPrice = currentPrice else { 
            print("❌ updateOrdersIfReady: no current price")
            return 
        }
        
        // Check if we already have orders for this exact combination of parameters
        // This prevents unnecessary recalculations when switching tabs for the same security
        if !viewModel.recommendedSellOrders.isEmpty || !viewModel.recommendedBuyOrders.isEmpty {
            // Check if the orders are for the current symbol by looking at the first order
            let hasOrdersForCurrentSymbol = viewModel.currentOrders.first { order in
                if case ("SELL", let sellOrder as SalesCalcResultsRecord) = order {
                    return sellOrder.description.contains(symbol)
                } else if case ("BUY", let buyOrder as BuyOrderRecord) = order {
                    return buyOrder.description.contains(symbol)
                }
                return false
            } != nil
            
            if hasOrdersForCurrentSymbol {
                print("✅ Using existing orders for \(symbol) - no recalculation needed")
                print("  - Current sell orders: \(viewModel.recommendedSellOrders.count)")
                print("  - Current buy orders: \(viewModel.recommendedBuyOrders.count)")
                return
            } else {
                print("⚠️ Orders exist but not for current symbol \(symbol), will recalculate")
            }
        } else {
            print("📝 No existing orders found, will calculate new ones")
        }
        
        print("✅ updateOrdersIfReady: calling viewModel.updateRecommendedOrders")
        print("  - symbol: \(symbol)")
        print("  - atrValue: \(atrValue)")
        print("  - taxLotData.count: \(taxLotData.count)")
        print("  - sharesAvailableForTrading: \(sharesAvailableForTrading)")
        print("  - currentPrice: \(currentPrice)")
        
        // Calculate position values from Position object (same as DetailsTab)
        let totalShares = (position.longQuantity ?? 0) + (position.shortQuantity ?? 0)
        let avgCostPerShare = position.averagePrice ?? 0
        let totalCost = avgCostPerShare * totalShares
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        let currentProfitPercent = costBasis != 0 ? (pl / costBasis) * 100 : 0
        
        Task {
            await viewModel.updateRecommendedOrders(
                symbol: symbol,
                atrValue: atrValue,
                taxLotData: taxLotData,
                sharesAvailableForTrading: sharesAvailableForTrading,
                currentPrice: currentPrice,
                totalShares: totalShares,
                totalCost: totalCost,
                avgCostPerShare: avgCostPerShare,
                currentProfitPercent: currentProfitPercent
            )
            
            print("✅ updateRecommendedOrders completed")
            print("  - recommendedSellOrders.count: \(viewModel.recommendedSellOrders.count)")
            print("  - recommendedBuyOrders.count: \(viewModel.recommendedBuyOrders.count)")
        }
    }
    
    private func copyToClipboard(value: Double, format: String) {
        let formattedValue = String(format: format, value)
#if os(iOS)
        UIPasteboard.general.string = formattedValue
        copiedValue = UIPasteboard.general.string ?? "no value"
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedValue, forType: .string)
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no value"
#endif
    }
    
    private func copyToClipboard(text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
        copiedValue = UIPasteboard.general.string ?? "no value"
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no value"
#endif
    }
    
    private func submitOrders() {
        // Allow single orders - at least one must be selected
        guard hasSelectedOrders else { 
            AppLogger.shared.error("❌ submitOrders: No orders selected")
            return 
        }
        
        let selectedOrders = viewModel.selectedOrders
        AppLogger.shared.info("📊 submitOrders: Selected orders count: \(selectedOrders.count)")
        
        // Debug: Print selected orders
        for (index, (orderType, order)) in selectedOrders.enumerated() {
            AppLogger.shared.info("Order \(index + 1): \(orderType) - \(String(describing: order))")
        }
        
        // Get account number from the position
        guard let accountNumberInt = getAccountNumber() else {
            errorMessage = "Could not get account number for position"
            showingErrorAlert = true
            return
        }
        
        // Create order using SchwabClient (single order or OCO)
        guard let orderToSubmit = SchwabClient.shared.createOrder(
            symbol: symbol,
            accountNumber: accountNumberInt,
            selectedOrders: selectedOrders,
            releaseTime: "" // No release time for simplified orders
        ) else {
            errorMessage = "Failed to create order"
            showingErrorAlert = true
            return
        }
        
        AppLogger.shared.info("📊 submitOrders: Order created successfully")
        
        // Create order descriptions for confirmation dialog
        orderDescriptions = createOrderDescriptions(orders: selectedOrders)
        AppLogger.shared.info("📊 submitOrders: Order descriptions count: \(orderDescriptions.count)")
        for (index, description) in orderDescriptions.enumerated() {
            AppLogger.shared.info("   Description \(index + 1): \(description)")
        }
        
        // Create JSON preview
        do {
            let encoder: JSONEncoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData: Data = try encoder.encode(orderToSubmit)
            orderJson = String(data: jsonData, encoding: .utf8) ?? "{}"
            AppLogger.shared.info("📊 submitOrders: JSON created successfully, length: \(orderJson.count)")
            
            // Sanitize the JSON before logging to hide sensitive account information
            let sanitizedJson = JSONSanitizer.sanitizeAccountNumbers(in: orderJson)
            AppLogger.shared.info("📊 submitOrders: JSON: \(sanitizedJson)")
        } catch {
            orderJson = "Error encoding order: \(error)"
            AppLogger.shared.error("❌ submitOrders: JSON encoding error: \(error)")
        }
        
        // Store the order and show confirmation dialog
        self.orderToSubmit = orderToSubmit
        
        // Force immediate UI update by triggering state change on main thread
        Task { @MainActor in
            // Trigger state update to force UI refresh
            self.dialogStateTrigger.toggle()
            
            // Small delay to ensure all state is properly set
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            self.showingConfirmationDialog = true
            AppLogger.shared.info("📊 submitOrders: ✅ Showing confirmation dialog")
            AppLogger.shared.info("📊 submitOrders: Final orderDescriptions count: \(self.orderDescriptions.count)")
            AppLogger.shared.info("📊 submitOrders: Final orderJson length: \(self.orderJson.count)")
        }
        
        AppLogger.shared.info("📊 submitOrders: Dialog should now show with data")
    }
    
    private func getAccountNumber() -> Int64? {
        // Get the full account number from SchwabClient instead of using the truncated version
        let accounts = SchwabClient.shared.getAccounts()
        
        for accountContent in accounts {
            // Check if this account contains the current symbol
            if let positions = accountContent.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        if let fullAccountNumber = accountContent.securitiesAccount?.accountNumber,
                           let accountNumberInt = Int64(fullAccountNumber) {
                            return accountNumberInt
                        }
                    }
                }
            }
        }
        
        // Fallback to the truncated version if full account number not found
        return Int64(accountNumber)
    }
    
    private func createOrderDescriptions(orders: [(String, Any)]) -> [String] {
        AppLogger.shared.info("🔍 createOrderDescriptions: Processing \(orders.count) orders")
        var descriptions: [String] = []
        
        for (index, (orderType, order)) in orders.enumerated() {
            AppLogger.shared.info("Processing order \(index + 1): \(orderType) - \(type(of: order))")
            
            if let sellOrder = order as? SalesCalcResultsRecord {
                AppLogger.shared.info("Sell order: description='\(sellOrder.description)', shares=\(sellOrder.sharesToSell)")
                let description = sellOrder.description.isEmpty ?
                    "SELL \(sellOrder.sharesToSell) shares at \(sellOrder.entry) (Target: \(sellOrder.target), Cancel: \(sellOrder.cancel))" :
                    sellOrder.description
                descriptions.append("Order \(index + 1) (SELL): \(description)")
                AppLogger.shared.info("Final sell description: \(description)")
            } else if let buyOrder = order as? BuyOrderRecord {
                AppLogger.shared.info("Buy order: description='\(buyOrder.description)', shares=\(buyOrder.sharesToBuy)")
                let description = buyOrder.description.isEmpty ?
                    "BUY \(buyOrder.sharesToBuy) shares at \(buyOrder.targetBuyPrice) (Entry: \(buyOrder.entryPrice), Target: \(buyOrder.targetGainPercent)%)" :
                    buyOrder.description
                descriptions.append("Order \(index + 1) (BUY): \(description)")
                AppLogger.shared.info("Final buy description: \(description)")
            } else {
                AppLogger.shared.warning("Unknown order type: \(type(of: order))")
            }
        }
        
        AppLogger.shared.info("🔍 createOrderDescriptions: Created \(descriptions.count) descriptions")
        return descriptions
    }
    
    private func confirmAndSubmitOrder() {
        guard let order = orderToSubmit else { return }
        
        // Submit the order asynchronously
        Task {
            let result = await SchwabClient.shared.placeOrder(order: order)
            
            await MainActor.run {
                // Clear the dialog state
                showingConfirmationDialog = false
                orderToSubmit = nil
                orderDescriptions = []
                orderJson = ""
                viewModel.selectedSellOrderIndex = nil
                viewModel.selectedBuyOrderIndex = nil
                
                // Show success or error dialog
                if result.success {
                    showingSuccessAlert = true
                } else {
                    errorMessage = result.errorMessage ?? "Unknown error occurred"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    // MARK: - Trailing Stop Validation
    
    private func validateTrailingStop() -> String? {
        AppLogger.shared.debug("=== validateTrailingStop ===")
        AppLogger.shared.debug("Selected sell order index: \(viewModel.selectedSellOrderIndex?.description ?? "nil")")
        AppLogger.shared.debug("Selected buy order index: \(viewModel.selectedBuyOrderIndex?.description ?? "nil")")
        
        // Only validate selected orders, not all recommended orders
        var selectedOrdersToValidate: [(String, Any)] = []
        
        // Add selected sell order if any
        if let sellIndex = viewModel.selectedSellOrderIndex,
           sellIndex < viewModel.recommendedSellOrders.count {
            let sellOrder = viewModel.recommendedSellOrders[sellIndex]
            selectedOrdersToValidate.append(("SELL", sellOrder))
            AppLogger.shared.debug("  Selected sell order: index=\(sellIndex), trailingStop=\(sellOrder.trailingStop)%, shares=\(sellOrder.shares), target=\(sellOrder.target)")
        }
        
        // Add selected buy order if any
        if let buyIndex = viewModel.selectedBuyOrderIndex,
           buyIndex < viewModel.recommendedBuyOrders.count {
            let buyOrder = viewModel.recommendedBuyOrders[buyIndex]
            selectedOrdersToValidate.append(("BUY", buyOrder))
            AppLogger.shared.debug("  Selected buy order: index=\(buyIndex), trailingStop=\(buyOrder.trailingStop)%, shares=\(buyOrder.shares), target=\(buyOrder.targetBuyPrice)")
        }
        
        AppLogger.shared.debug("Selected orders to validate: \(selectedOrdersToValidate.count)")
        
        // Check if any selected orders have trailing stops less than 0.1%
        for (index, (orderType, order)) in selectedOrdersToValidate.enumerated() {
            AppLogger.shared.debug("Validating selected order \(index + 1): type=\(orderType)")
            
            if let sellOrder = order as? SalesCalcResultsRecord {
                AppLogger.shared.debug("  Selected sell order: trailingStop=\(sellOrder.trailingStop)%, shares=\(sellOrder.shares), target=\(sellOrder.target)")
                
                if sellOrder.trailingStop < 0.1 {
                    AppLogger.shared.error("⚠️ Trailing stop validation failed: selected sell order has trailingStop=\(sellOrder.trailingStop)% which is below 0.1%")
                    AppLogger.shared.error("  Order details: shares=\(sellOrder.shares), target=\(sellOrder.target), entry=\(sellOrder.entry)")
                    
                    // Clear ATR cache to force fresh calculation
                    SchwabClient.shared.clearATRCache()
                    return "⚠️ Warning: Trailing stop is too low (\(String(format: "%.2f", sellOrder.trailingStop))%). This may indicate ATR calculation failed. ATR cache has been cleared - please refresh and try again."
                }
            } else if let buyOrder = order as? BuyOrderRecord {
                AppLogger.shared.debug("  Selected buy order: trailingStop=\(buyOrder.trailingStop)%, shares=\(buyOrder.shares), target=\(buyOrder.targetBuyPrice)")
                
                if buyOrder.trailingStop < 0.1 {
                    AppLogger.shared.error("⚠️ Trailing stop validation failed: selected buy order has trailingStop=\(buyOrder.trailingStop)% which is below 0.1%")
                    AppLogger.shared.error("  Order details: shares=\(buyOrder.shares), target=\(buyOrder.targetBuyPrice), entry=\(buyOrder.entryPrice)")
                    
                    // Clear ATR cache to force fresh calculation
                    SchwabClient.shared.clearATRCache()
                    return "⚠️ Warning: Trailing stop is too low (\(String(format: "%.2f", buyOrder.trailingStop))%). This may indicate ATR calculation failed. ATR cache has been cleared - please refresh and try again."
                }
            } else {
                AppLogger.shared.warning("  Unknown selected order type: \(type(of: order))")
            }
        }
        
        AppLogger.shared.debug("✅ Trailing stop validation passed for all selected orders")
        return nil // No validation errors
    }
}

// MARK: - Previews
#Preview("RecommendedOCOOrdersSection - Full View", traits: .landscapeLeft) {
    ScrollView {
        RecommendedOCOOrdersSection(
            symbol: "AAPL",
            atrValue: 2.5,
            sharesAvailableForTrading: 150,
            quoteData: QuoteData(
                assetMainType: "EQUITY",
                assetSubType: "COE",
                quoteType: "NBBO",
                realtime: true,
                ssid: 123456789,
                symbol: "AAPL",
                extended: nil,
                fundamental: nil,
                quote: Quote(
                    m52WeekHigh: 200.0,
                    m52WeekLow: 120.0,
                    askMICId: "XNAS",
                    askPrice: 175.5,
                    askSize: 100,
                    askTime: 1736557200000,
                    bidMICId: "XNAS",
                    bidPrice: 174.5,
                    bidSize: 100,
                    bidTime: 1736557200000,
                    closePrice: 172.5,
                    highPrice: 176.0,
                    lastMICId: "XNAS",
                    lastPrice: 175.0,
                    lastSize: 100,
                    lowPrice: 174.0,
                    mark: 175.0,
                    markChange: 2.5,
                    markPercentChange: 1.45,
                    netChange: 2.5,
                    netPercentChange: 1.45,
                    openPrice: 172.5,
                    postMarketChange: 0.0,
                    postMarketPercentChange: 0.0,
                    quoteTime: 1736557200000,
                    securityStatus: "Normal",
                    totalVolume: 50000000,
                    tradeTime: 1736557200000,
                    volatility: 0.25
                ),
                reference: nil,
                regular: nil
            ),
            accountNumber: "123456789",
            position: Position(shortQuantity: 0, averagePrice: 150.0, longQuantity: 150, marketValue: 26250.0, longOpenProfitLoss: 3750.0)
        )
    }
    .padding()
}

#Preview("RecommendedOCOOrdersSection - Simple UI", traits: .landscapeLeft) {
    ScrollView {
        RecommendedOCOOrdersSection(
            symbol: "TSLA",
            atrValue: 1.8,
            sharesAvailableForTrading: 25,
            quoteData: QuoteData(
                assetMainType: "EQUITY",
                assetSubType: "COE",
                quoteType: "NBBO",
                realtime: true,
                ssid: 987654321,
                symbol: "TSLA",
                extended: nil,
                fundamental: nil,
                quote: Quote(
                    m52WeekHigh: 250.0,
                    m52WeekLow: 150.0,
                    askMICId: "XNAS",
                    askPrice: 180.5,
                    askSize: 100,
                    askTime: 1736557200000,
                    bidMICId: "XNAS",
                    bidPrice: 179.5,
                    bidSize: 100,
                    bidTime: 1736557200000,
                    closePrice: 185.0,
                    highPrice: 182.0,
                    lastMICId: "XNAS",
                    lastPrice: 180.0,
                    lastSize: 100,
                    lowPrice: 178.0,
                    mark: 180.0,
                    markChange: -5.0,
                    markPercentChange: -2.7,
                    netChange: -5.0,
                    netPercentChange: -2.7,
                    openPrice: 185.0,
                    postMarketChange: 0.0,
                    postMarketPercentChange: 0.0,
                    quoteTime: 1736557200000,
                    securityStatus: "Normal",
                    totalVolume: 30000000,
                    tradeTime: 1736557200000,
                    volatility: 0.35
                ),
                reference: nil,
                regular: nil
            ),
            accountNumber: "987654321",
            position: Position(shortQuantity: 0, averagePrice: 180.0, longQuantity: 25, marketValue: 4750.0, longOpenProfitLoss: 250.0)
        )
    }
    .padding()
}

#Preview("RecommendedOCOOrdersSection - Minimal Data", traits: .landscapeLeft) {
    ScrollView {
        RecommendedOCOOrdersSection(
            symbol: "MSFT",
            atrValue: 1.0,
            sharesAvailableForTrading: 0,
            quoteData: nil, // No quote data to avoid calculations
            accountNumber: "111222333",
            position: Position(shortQuantity: 0, averagePrice: 300.0, longQuantity: 0, marketValue: 0.0, longOpenProfitLoss: 0.0)
        )
    }
    .padding()
}
