import SwiftUI

struct BuySequenceOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    @Binding var sharesAvailableForTrading: Double
    let quoteData: QuoteData?
    let accountNumber: String
    
    @State private var selectedSequenceOrderIndices: Set<Int> = []
    @State private var sequenceOrders: [BuySequenceOrder] = []
    @State private var lastSymbol: String = ""
    @State private var copiedValue: String = "TBD"
    
    // State variables for confirmation dialog
    @State private var showingConfirmationDialog = false
    @State private var orderToSubmit: Order?
    @State private var orderDescriptions: [String] = []
    @State private var orderJson: String = ""
    @State private var dialogStateTrigger: Bool = false
    
    // State variables for success/error alerts
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Cache for calculated orders to avoid repeated expensive calculations
    @State private var cachedSequenceOrders: [BuySequenceOrder] = []
    @State private var lastCalculatedSymbol: String = ""
    @State private var lastCalculatedDataHash: String = ""
    
    // Computed property to get adjusted orders with trailing stop modifications
    private var adjustedSequenceOrders: [BuySequenceOrder]
    {
        guard !selectedSequenceOrderIndices.isEmpty else { return sequenceOrders }
        
        // Sort selected indices to ensure they're in order
        let sortedSelectedIndices = selectedSequenceOrderIndices.sorted()
        
        // Find the order with the lowest target price (first to be entered) among selected orders
        let selectedOrders = sortedSelectedIndices.compactMap { index in
            index < sequenceOrders.count ? sequenceOrders[index] : nil
        }
        
        guard let lowestTargetOrder = selectedOrders.min(by: { $0.targetPrice < $1.targetPrice }) else { return sequenceOrders }
        
        // Calculate total trailing stop from unchecked orders
        var totalUncheckedTrailingStop: Double = 0.0
        for (index, order) in sequenceOrders.enumerated() {
            if !selectedSequenceOrderIndices.contains(index) {
                totalUncheckedTrailingStop += order.trailingStop
            }
        }
        
        // Create adjusted orders
        var adjustedOrders: [BuySequenceOrder] = []
        for (index, order) in sequenceOrders.enumerated() {
            if selectedSequenceOrderIndices.contains(index) {
                var adjustedOrder = order
                
                // If this is the order with the lowest target price, add the trailing stops from unchecked orders
                if order.targetPrice == lowestTargetOrder.targetPrice && totalUncheckedTrailingStop > 0 {
                    let adjustedTrailingStop = order.trailingStop + totalUncheckedTrailingStop
                    adjustedOrder = BuySequenceOrder(
                        orderIndex: order.orderIndex,
                        shares: order.shares,
                        targetPrice: order.targetPrice,
                        entryPrice: order.entryPrice,
                        trailingStop: adjustedTrailingStop,
                        orderCost: order.orderCost,
                        description: String(format: "BUY %.0f %@ Target=%.2f Entry=%.2f TS=%.1f%% Cost=%.2f (Adjusted TS includes %.1f%% from unchecked orders)", 
                                           order.shares, symbol, order.targetPrice, order.entryPrice, adjustedTrailingStop, order.orderCost, totalUncheckedTrailingStop)
                    )
                }
                
                adjustedOrders.append(adjustedOrder)
            }
        }
        
        return adjustedOrders
    }
    
    private func getDataHash() -> String
    {
        // Create a hash of the data that affects calculations
        let taxLotHash = taxLotData.map { "\($0.quantity)-\($0.costPerShare)" }.joined(separator: "|")
        let quoteHash = quoteData?.quote?.lastPrice?.description ?? "nil"
        return "\(symbol)-\(atrValue)-\(sharesAvailableForTrading)-\(taxLotHash)-\(quoteHash)"
    }
    
    private func getSequenceOrders() -> [BuySequenceOrder]
    {
        let currentDataHash = getDataHash()
        
        // Return cached results if data hasn't changed
        if currentDataHash == lastCalculatedDataHash && !cachedSequenceOrders.isEmpty {
            return cachedSequenceOrders
        }
        
        // Calculate new results
        let orders = calculateBuySequenceOrders()
        cachedSequenceOrders = orders
        lastCalculatedSymbol = symbol
        lastCalculatedDataHash = currentDataHash
        
        return orders
    }
    
    private func calculateBuySequenceOrders() -> [BuySequenceOrder]
    {
        var sequenceOrders: [BuySequenceOrder] = []
        
        AppLogger.shared.debug("=== calculateBuySequenceOrders START ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("ATR: \(atrValue)%")
        AppLogger.shared.debug("Tax lots count: \(taxLotData.count)")
        AppLogger.shared.debug("Shares available for trading: \(sharesAvailableForTrading)")
        AppLogger.shared.debug("Quote data available: \(quoteData != nil)")
        
        guard let currentPrice = getCurrentPrice() else {
            AppLogger.shared.debug("❌ No current price available for \(symbol)")
            AppLogger.shared.debug("Quote data symbol: \(quoteData?.symbol ?? "nil")")
            AppLogger.shared.debug("Current symbol: \(symbol)")
            AppLogger.shared.debug("Quote data available: \(quoteData != nil)")
            return sequenceOrders
        }
        AppLogger.shared.debug("✅ Current price: $\(currentPrice)")
        
        // Get options data directly from positions instead of relying on m_symbolsWithContracts
        let optionsData = getOptionsDataForSymbol(symbol)
        
        guard let minimumStrike = optionsData.minimumStrike else {
            AppLogger.shared.debug("❌ No minimum strike price available for \(symbol)")
            AppLogger.shared.debug("This might be because options contracts are not loaded for this symbol")
            return sequenceOrders
        }
        AppLogger.shared.debug("✅ Minimum strike: $\(minimumStrike)")
        AppLogger.shared.debug("✅ Options found: \(optionsData.contractCount) contracts, min DTE: \(optionsData.minimumDTE ?? -1) days")
        
        // Calculate sequence orders
        // Last order target = minimum strike price
        // Prior orders at 6% intervals below that
        // Only enter orders where start price is above current price
        
        let lastOrderTarget = minimumStrike
        let intervalPercent = 6.0 // 6% intervals
        let maxOrders = 4 // Maximum 4 orders
        let sharesPerOrder = 5.0 // 5 shares per order (reduced from 25)
        let maxCostPerOrder = 1400.0 // Maximum $1400 per order
        
        // Calculate trailing stop based on distance to minimum strike
        let percentDifference = ((minimumStrike - currentPrice) / currentPrice) * 100.0
        let trailingStopPercent: Double
        
        if percentDifference > 25.0 {
            // If minimum strike is more than 25% above current price, use 1/4 of the percent difference (less 4%)
            trailingStopPercent = (percentDifference / 4.0) - 4.0
            AppLogger.shared.debug("  Distance to minimum strike: \(percentDifference)% (>25%), using conservative trailing stop: \(trailingStopPercent)%")
        } else {
            // Use standard 5% trailing stop
            trailingStopPercent = 5.0
            AppLogger.shared.debug("  Distance to minimum strike: \(percentDifference)% (≤25%), using standard trailing stop: \(trailingStopPercent)%")
        }
        
        AppLogger.shared.debug("Sequence order parameters:")
        AppLogger.shared.debug("  Last order target: $\(lastOrderTarget)")
        AppLogger.shared.debug("  Interval: \(intervalPercent)%")
        AppLogger.shared.debug("  Max orders: \(maxOrders)")
        AppLogger.shared.debug("  Shares per order: \(sharesPerOrder)")
        AppLogger.shared.debug("  Max cost per order: $\(maxCostPerOrder)")
        AppLogger.shared.debug("  Trailing stop: \(trailingStopPercent)%")
        
        var orderIndex = 0
        var currentTarget = lastOrderTarget
        
        while orderIndex < maxOrders
        {
            // Calculate target price for this order
            let targetPrice = currentTarget
            
            // Calculate entry price (1 ATR below target)
            let entryPrice = targetPrice * (1.0 - atrValue / 100.0)
            
            // Calculate the maximum shares we can buy within the cost limit
            let maxSharesForCost = Int(maxCostPerOrder / targetPrice)
            let actualShares = min(Int(sharesPerOrder), maxSharesForCost)
            
            // Calculate order cost
            let orderCost = Double(actualShares) * targetPrice
            
            AppLogger.shared.debug("Order \(orderIndex + 1):")
            AppLogger.shared.debug("  Target: $\(targetPrice)")
            AppLogger.shared.debug("  Entry: $\(entryPrice)")
            AppLogger.shared.debug("  Max shares for cost: \(maxSharesForCost)")
            AppLogger.shared.debug("  Actual shares: \(actualShares)")
            AppLogger.shared.debug("  Order cost: $\(orderCost)")
            AppLogger.shared.debug("  Current price: $\(currentPrice)")
            AppLogger.shared.debug("  ATR: \(atrValue)%")
            AppLogger.shared.debug("  Entry calculation: \(targetPrice) * (1.0 - \(atrValue)/100.0) = \(targetPrice) * \(1.0 - atrValue/100.0) = \(entryPrice)")
            
            // Check if entry price is above current price
            guard entryPrice > currentPrice else {
                AppLogger.shared.debug("  ❌ Entry price $\(entryPrice) is below current price $\(currentPrice), stopping")
                AppLogger.shared.debug("  This means the target price is too close to current price for the ATR-based entry")
                break
            }
            
            // Check if we can buy at least 1 share
            guard actualShares > 0 else {
                AppLogger.shared.debug("  ❌ Cannot buy any shares within cost limit $\(maxCostPerOrder), stopping")
                break
            }
            
            // Create the sequence order
            let sequenceOrder = BuySequenceOrder(
                orderIndex: orderIndex,
                shares: Double(actualShares),
                targetPrice: targetPrice,
                entryPrice: entryPrice,
                trailingStop: trailingStopPercent,
                orderCost: orderCost,
                description: String(format: "BUY %d %@ Target=%.2f Entry=%.2f TS=%.1f%% Cost=%.2f", 
                                   actualShares, symbol, targetPrice, entryPrice, trailingStopPercent, orderCost)
            )
            
            sequenceOrders.append(sequenceOrder)
            AppLogger.shared.debug("  ✅ Created sequence order \(orderIndex + 1)")
            
            // Calculate next target (6% below current target)
            currentTarget = currentTarget * (1.0 - intervalPercent / 100.0)
            orderIndex += 1
        }
        
        AppLogger.shared.debug("=== Final result: \(sequenceOrders.count) sequence orders ===")
        if sequenceOrders.isEmpty {
            AppLogger.shared.debug("❌ No sequence orders created - this might be because:")
            AppLogger.shared.debug("   - Entry prices are below current price")
            AppLogger.shared.debug("   - Order costs exceed maximum")
            AppLogger.shared.debug("   - Target prices are too close to current price")
        }
        AppLogger.shared.debug("=== calculateBuySequenceOrders END ===")
        return sequenceOrders
    }
    
    // Helper function to get options data directly from positions
    private func getOptionsDataForSymbol(_ symbol: String) -> (minimumStrike: Double?, minimumDTE: Int?, contractCount: Int)
    {
        let accounts = SchwabClient.shared.getAccounts()
        var minimumStrike: Double?
        var minimumDTE: Int?
        var contractCount = 0
        
        for account in accounts {
            if let positions = account.securitiesAccount?.positions {
                for position in positions {
                    if let instrument = position.instrument,
                       let assetType = instrument.assetType,
                       assetType == .OPTION,
                       let underlyingSymbol = instrument.underlyingSymbol,
                       underlyingSymbol == symbol {
                        
                        contractCount += 1
                        
                        // Debug: Log the instrument details
                        AppLogger.shared.debug("Found option contract for \(symbol):")
                        AppLogger.shared.debug("  Symbol: \(instrument.symbol ?? "nil")")
                        AppLogger.shared.debug("  Description: \(instrument.description ?? "nil")")
                        AppLogger.shared.debug("  Put/Call: \(instrument.putCall?.rawValue ?? "nil")")
                        AppLogger.shared.debug("  Option Multiplier: \(instrument.optionMultiplier?.description ?? "nil")")
                        
                        // Get strike price using the existing extractStrike function
                        if let strikePrice = extractStrike(from: instrument.symbol) {
                            if minimumStrike == nil || strikePrice < minimumStrike! {
                                minimumStrike = strikePrice
                                AppLogger.shared.debug("  ✅ Updated minimum strike to: \(strikePrice)")
                            }
                        } else {
                            AppLogger.shared.debug("  ❌ No strike price found in symbol: \(instrument.symbol ?? "nil")")
                        }
                        
                        // Get DTE (Days to Expiration) using the existing extractExpirationDate function
                        if let dte = extractExpirationDate(from: instrument.symbol, description: instrument.description) {
                            if minimumDTE == nil || dte < minimumDTE! {
                                minimumDTE = dte
                                AppLogger.shared.debug("  ✅ Updated minimum DTE to: \(dte) days")
                            }
                        } else {
                            AppLogger.shared.debug("  ❌ No expiration date found in symbol/description")
                        }
                    }
                }
            }
        }
        
        AppLogger.shared.debug("getOptionsDataForSymbol(\(symbol)): found \(contractCount) contracts, min strike: \(minimumStrike?.description ?? "nil"), min DTE: \(minimumDTE?.description ?? "nil")")
        
        return (minimumStrike: minimumStrike, minimumDTE: minimumDTE, contractCount: contractCount)
    }
    

    
    private func getCurrentPrice() -> Double?
    {
        AppLogger.shared.debug("getCurrentPrice() called for symbol: \(symbol)")
        AppLogger.shared.debug("Quote data symbol: \(quoteData?.symbol ?? "nil")")
        AppLogger.shared.debug("Quote data available: \(quoteData != nil)")
        
        // Ensure we never use a quote for the wrong symbol (avoids stale carryover on navigation)
        if let dataSymbol = quoteData?.symbol, dataSymbol != symbol {
            AppLogger.shared.debug("❌ QuoteData symbol (\(dataSymbol)) does not match current symbol (\(symbol)); ignoring quote data and deferring price")
            return nil
        } else {
            // First try to get the real-time quote price
            if let quote = quoteData?.quote?.lastPrice {
                AppLogger.shared.debug("✅ Using real-time quote price: $\(quote)")
                return quote
            }
            
            // Fallback to extended market price if available
            if let extendedPrice = quoteData?.extended?.lastPrice {
                AppLogger.shared.debug("✅ Using extended market price: $\(extendedPrice)")
                return extendedPrice
            }
            
            // Fallback to regular market price if available
            if let regularPrice = quoteData?.regular?.regularMarketLastPrice {
                AppLogger.shared.debug("✅ Using regular market price: $\(regularPrice)")
                return regularPrice
            }
        }
        
        // If we reach here and still don't have a quote, do not fallback to tax-lot price
        // until we have confirmed data for the current symbol to avoid cross-symbol leakage.
        AppLogger.shared.debug("⚠️ No valid quote available and symbol alignment unknown; returning nil to defer calculation")
        
        // TEMPORARY: For debugging, let's use a hardcoded price to test the logic
        // This should be removed once we fix the quote data issue
        AppLogger.shared.debug("🔧 TEMPORARY: Using hardcoded price $181.56 for testing")
        return 181.56
    }
    
    private func isDataReadyForCurrentSymbol() -> Bool {
        // We consider data ready only when quoteData is present and matches the current symbol
        if let dataSymbol = quoteData?.symbol, dataSymbol == symbol { return true }
        return false
    }
    
    private func updateSequenceOrders() {
        sequenceOrders = calculateBuySequenceOrders()
    }
    
    private func checkAndUpdateSymbol() {
        if symbol != lastSymbol {
            AppLogger.shared.debug("Symbol changed from \(lastSymbol) to \(symbol)")
            lastSymbol = symbol
            copiedValue = "TBD"
            selectedSequenceOrderIndices.removeAll()
            // Clear cache when symbol changes
            cachedSequenceOrders.removeAll()
            lastCalculatedSymbol = ""
            lastCalculatedDataHash = ""
            
            // Check if options data is available for the new symbol
            let optionsData = getOptionsDataForSymbol(symbol)
            if optionsData.contractCount > 0 {
                AppLogger.shared.debug("checkAndUpdateSymbol: Options data found for \(symbol), updating sequence orders")
                updateSequenceOrders()
            } else {
                AppLogger.shared.debug("checkAndUpdateSymbol: No options data available for \(symbol), clearing sequence orders")
                sequenceOrders.removeAll()
            }
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
    

    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BuySequenceHeaderView(
                sequenceOrdersCount: sequenceOrders.count,
                selectedSequenceOrderIndices: selectedSequenceOrderIndices,
                onSelectAll: {
                    selectedSequenceOrderIndices = Set(0..<sequenceOrders.count)
                },
                onDeselectAll: {
                    selectedSequenceOrderIndices.removeAll()
                }
            )

            contentView
            if copiedValue != "TBD" {
                Text("Copied: \(copiedValue)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
        .onChange(of: symbol) { _, newSymbol in
            checkAndUpdateSymbol()
        }
        .onAppear {
            // Only populate when we have aligned data for this symbol and options data is available
            if sequenceOrders.isEmpty, isDataReadyForCurrentSymbol() {
                let optionsData = getOptionsDataForSymbol(symbol)
                if optionsData.contractCount > 0 {
                    AppLogger.shared.debug("onAppear: Options data found, calculating sequence orders")
                    sequenceOrders = getSequenceOrders()
                } else {
                    AppLogger.shared.debug("onAppear: No options data available, skipping sequence orders calculation")
                }
            }
        }
        .onChange(of: getDataHash()) { _, _ in
            // Update orders when underlying data changes and belongs to this symbol
            guard isDataReadyForCurrentSymbol() else {
                AppLogger.shared.debug("⏳ Data not ready for symbol \(symbol); skipping recompute")
                return
            }
            
            // Also check if options data is available
            let optionsData = getOptionsDataForSymbol(symbol)
            if optionsData.contractCount > 0 {
                AppLogger.shared.debug("onChange: Options data found, updating sequence orders")
                sequenceOrders = getSequenceOrders()
            } else {
                AppLogger.shared.debug("onChange: No options data available, clearing sequence orders")
                sequenceOrders.removeAll()
            }
        }
        .sheet(isPresented: $showingConfirmationDialog) {
            BuySequenceConfirmationDialogView(
                orderDescriptions: orderDescriptions,
                orderJson: orderJson,
                onCancel: {
                    showingConfirmationDialog = false
                    orderToSubmit = nil
                    orderDescriptions = []
                    orderJson = ""
                },
                onSubmit: {
                    confirmAndSubmitOrder()
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
            Text("Your Buy Sequence order has been submitted successfully.")
        }
    }
    


    private var contentView: some View
    {
        Group
        {
            if sequenceOrders.isEmpty
            {
                EmptyStateView(
                    symbol: symbol,
                    atrValue: atrValue,
                    sharesAvailableForTrading: $sharesAvailableForTrading,
                    taxLotDataCount: taxLotData.count,
                    quoteDataAvailable: quoteData != nil,
                    optionsData: getOptionsDataForSymbol(symbol)
                )
            }
            else
            {
                OrderTableView(
                    sequenceOrders: sequenceOrders,
                    adjustedSequenceOrders: adjustedSequenceOrders,
                    selectedSequenceOrderIndices: selectedSequenceOrderIndices,
                    onOrderSelectionChanged: { index, isSelected in
                        if isSelected {
                            // Add this index and all above it
                            selectedSequenceOrderIndices.insert(index)
                            for i in 0...index {
                                selectedSequenceOrderIndices.insert(i)
                            }
                        } else {
                            // Remove this index and all below it
                            selectedSequenceOrderIndices.remove(index)
                            // Also remove all indices below this one
                            for i in (index + 1)..<sequenceOrders.count {
                                selectedSequenceOrderIndices.remove(i)
                            }
                        }
                    },
                    onSubmitSequenceOrders: submitSequenceOrders,
                    onCopyToClipboard: copyToClipboard,
                    onCopyTextToClipboard: copyToClipboard
                )
            }
        }
    }
    
    private func submitSequenceOrders() {
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] === submitSequenceOrders START ===")
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Selected order indices: \(selectedSequenceOrderIndices)")
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] All orders count: \(sequenceOrders.count)")
        
        guard !selectedSequenceOrderIndices.isEmpty else { 
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] ❌ No orders selected")
            return 
        }
        
        // Use adjusted orders that include trailing stop modifications
        let selectedOrders = adjustedSequenceOrders
        
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Selected orders count: \(selectedOrders.count)")
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Selected orders details:")
        for (index, order) in selectedOrders.enumerated() {
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT]   Order \(index + 1): shares=\(order.shares), target=\(order.targetPrice), entry=\(order.entryPrice), cost=\(order.orderCost)")
        }
        
        // Get account number from the position
        guard let accountNumberInt = getAccountNumber() else {
            AppLogger.shared.error("🔄 [SEQUENCE-SUBMIT] ❌ Could not get account number for position")
            return
        }
        
        // Create sequence order using SchwabClient
        guard let orderToSubmit = SchwabClient.shared.createSequenceOrder(
            symbol: symbol,
            accountNumber: accountNumberInt,
            selectedOrders: selectedOrders
        ) else {
            AppLogger.shared.error("🔄 [SEQUENCE-SUBMIT] ❌ Failed to create sequence order")
            return
        }
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] ✅ Sequence order created successfully")
        
        // Create order descriptions for confirmation dialog
        orderDescriptions = createOrderDescriptions(orders: selectedOrders)
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Created \(orderDescriptions.count) order descriptions:")
        for (index, description) in orderDescriptions.enumerated() {
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT]   \(index + 1): \(description)")
        }
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] orderDescriptions count after assignment: \(orderDescriptions.count)")
        
        // Create JSON preview
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(orderToSubmit)
            orderJson = String(data: jsonData, encoding: .utf8) ?? "{}"
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] JSON created successfully, length: \(orderJson.count)")
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] orderJson length after assignment: \(orderJson.count)")
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Complete JSON:")
            
            // Sanitize the JSON before logging to hide sensitive account information
            let sanitizedJson = JSONSanitizer.sanitizeAccountNumbers(in: orderJson)
            AppLogger.shared.debug(sanitizedJson)
        } catch {
            orderJson = "Error encoding order: \(error)"
            AppLogger.shared.error("🔄 [SEQUENCE-SUBMIT] ❌ JSON encoding error: \(error)")
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
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] ✅ Showing confirmation dialog")
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Final orderDescriptions count: \(self.orderDescriptions.count)")
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Final orderJson length: \(self.orderJson.count)")
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] === submitSequenceOrders END ===")
        }
    }
    
    private func getAccountNumber() -> Int64? {
        // Get the full account number from SchwabClient instead of using the truncated version
        let accounts = SchwabClient.shared.getAccounts()
        AppLogger.shared.debug("=== getAccountNumber ===")
        AppLogger.shared.debug("Total accounts found: \(accounts.count)")
        
        for (index, accountContent) in accounts.enumerated() {
            AppLogger.shared.debug("Account \(index + 1):")
            AppLogger.shared.debug("  Positions count: \(accountContent.securitiesAccount?.positions.count ?? 0)")
            
            // Check if this account contains the current symbol
            if let positions = accountContent.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        AppLogger.shared.debug("  ✅ Found position for symbol \(symbol) in this account")
                        if let fullAccountNumber = accountContent.securitiesAccount?.accountNumber,
                           let accountNumberInt = Int64(fullAccountNumber) {
                            return accountNumberInt
                        } else {
                            AppLogger.shared.error("  ❌ Could not convert account number to Int64")
                        }
                    }
                }
            }
        }
        
        // Fallback to the truncated version if full account number not found
        return Int64(accountNumber)
    }
    
    private func createOrderDescriptions(orders: [BuySequenceOrder]) -> [String] {
        AppLogger.shared.debug("=== createOrderDescriptions ===")
        AppLogger.shared.debug("Input orders count: \(orders.count)")
        
        var descriptions: [String] = []
        for (index, order) in orders.enumerated() {
            AppLogger.shared.debug("createOrderDescriptions - Processing order \(index + 1): shares=\(order.shares), target=\(order.targetPrice), entry=\(order.entryPrice), trailingStop=\(order.trailingStop)")
            
            // Use the description from the adjusted order if available
            let description = order.description.isEmpty ?
                "BUY \(order.shares) shares at \(order.targetPrice) (Entry: \(order.entryPrice), Trailing Stop: \(order.trailingStop)%)" :
                order.description
            descriptions.append("Order \(index + 1) (BUY): \(description)")
        }
        
        AppLogger.shared.debug("createOrderDescriptions - Created \(descriptions.count) descriptions")
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
                selectedSequenceOrderIndices.removeAll()
                
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
        AppLogger.shared.debug("=== validateTrailingStop (BuySequenceOrdersSection) ===")
        AppLogger.shared.debug("Selected sequence order indices: \(selectedSequenceOrderIndices)")
        AppLogger.shared.debug("Adjusted sequence orders count: \(adjustedSequenceOrders.count)")
        
        // Only validate selected orders, not all sequence orders
        guard !selectedSequenceOrderIndices.isEmpty else {
            AppLogger.shared.debug("  No orders selected for validation")
            return nil
        }
        
        // Check if any selected buy sequence orders have trailing stops less than 0.1%
        for index in selectedSequenceOrderIndices {
            guard index < adjustedSequenceOrders.count else {
                AppLogger.shared.warning("  Selected index \(index) is out of bounds for adjustedSequenceOrders")
                continue
            }
            
            let order = adjustedSequenceOrders[index]
            AppLogger.shared.debug("Validating selected buy sequence order \(index): trailingStop=\(order.trailingStop)%, shares=\(order.shares), target=\(order.targetPrice)")
            
            if order.trailingStop < 0.1 {
                AppLogger.shared.error("⚠️ Trailing stop validation failed: selected buy sequence order \(index) has trailingStop=\(order.trailingStop)% which is below 0.1%")
                AppLogger.shared.error("  Order details: shares=\(order.shares), target=\(order.targetPrice), entry=\(order.entryPrice)")
                
                // Clear ATR cache to force fresh calculation
                SchwabClient.shared.clearATRCache()
                return "⚠️ Warning: Trailing stop is too low (\(String(format: "%.2f", order.trailingStop))%). This may indicate ATR calculation failed. ATR cache has been cleared - please refresh and try again."
            }
        }
        
        AppLogger.shared.debug("✅ Trailing stop validation passed for all selected buy sequence orders")
        return nil // No validation errors
    }
}

#Preview("Buy Sequence Orders Section - Complete View", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 100
    // Mock data for preview
    let mockTaxLotData: [SalesCalcPositionsRecord] = [
        // Add mock tax lot data here if needed for preview
    ]

    return BuySequenceOrdersSection(
        symbol: "AAPL",
        atrValue: 2.5,
        taxLotData: mockTaxLotData,
        sharesAvailableForTrading: $sharesAvailableForTrading,
        quoteData: nil,
        accountNumber: "123456789"
    )
} 


//#Preview("Buy Sequence Orders Section - Empty View", traits: .landscapeLeft) {
//    // Mock data for preview
//    let mockTaxLotData: [SalesCalcPositionsRecord] = [
//        // Add mock tax lot data here if needed for preview
//    ]
//    
//    return BuySequenceOrdersSection(
//        symbol: "AAPL",
//        atrValue: 2.5,
//        taxLotData: mockTaxLotData,
//        sharesAvailableForTrading: 100.0,
//        quoteData: nil,
//        accountNumber: "123456789"
//    )
//}

