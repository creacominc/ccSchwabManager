import SwiftUI

struct BuySequenceOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
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
    
    private func getDataHash() -> String {
        // Create a hash of the data that affects calculations
        let taxLotHash = taxLotData.map { "\($0.quantity)-\($0.costPerShare)" }.joined(separator: "|")
        let quoteHash = quoteData?.quote?.lastPrice?.description ?? "nil"
        return "\(symbol)-\(atrValue)-\(sharesAvailableForTrading)-\(taxLotHash)-\(quoteHash)"
    }
    
    private func getSequenceOrders() -> [BuySequenceOrder] {
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
    
    private func calculateBuySequenceOrders() -> [BuySequenceOrder] {
        var sequenceOrders: [BuySequenceOrder] = []
        
        guard let currentPrice = getCurrentPrice() else {
            AppLogger.shared.debug("❌ No current price available for \(symbol)")
            return sequenceOrders
        }
        
        // Get minimum strike price for the symbol
        guard let minimumStrike = SchwabClient.shared.getMinimumStrikeForSymbol(symbol) else {
            AppLogger.shared.debug("❌ No minimum strike price available for \(symbol)")
            return sequenceOrders
        }
        
        AppLogger.shared.debug("=== calculateBuySequenceOrders ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("Current price: $\(currentPrice)")
        AppLogger.shared.debug("Minimum strike: $\(minimumStrike)")
        
        // Calculate sequence orders
        // Last order target = minimum strike price
        // Prior orders at 6% intervals below that
        // Only enter orders where start price is above current price
        
        let lastOrderTarget = minimumStrike
        let intervalPercent = 6.0 // 6% intervals
        let maxOrders = 4 // Maximum 4 orders
        let sharesPerOrder = 25.0 // 25 shares per order
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
        
        while orderIndex < maxOrders {
            // Calculate target price for this order
            let targetPrice = currentTarget
            
            // Calculate entry price (1 ATR below target)
            let entryPrice = targetPrice * (1.0 - atrValue / 100.0)
            
            // Calculate order cost
            let orderCost = sharesPerOrder * targetPrice
            
            AppLogger.shared.debug("Order \(orderIndex + 1):")
            AppLogger.shared.debug("  Target: $\(targetPrice)")
            AppLogger.shared.debug("  Entry: $\(entryPrice)")
            AppLogger.shared.debug("  Order cost: $\(orderCost)")
            
            // Check if entry price is above current price
            guard entryPrice > currentPrice else {
                AppLogger.shared.debug("  ❌ Entry price $\(entryPrice) is below current price $\(currentPrice), stopping")
                break
            }
            
            // Check if order cost exceeds maximum
            guard orderCost <= maxCostPerOrder else {
                AppLogger.shared.debug("  ❌ Order cost $\(orderCost) exceeds maximum $\(maxCostPerOrder), stopping")
                break
            }
            
            // Create the sequence order
            let sequenceOrder = BuySequenceOrder(
                orderIndex: orderIndex,
                shares: sharesPerOrder,
                targetPrice: targetPrice,
                entryPrice: entryPrice,
                trailingStop: trailingStopPercent,
                orderCost: orderCost,
                description: String(format: "BUY %.0f %@ Target=%.2f Entry=%.2f TS=%.1f%% Cost=%.2f", 
                                   sharesPerOrder, symbol, targetPrice, entryPrice, trailingStopPercent, orderCost)
            )
            
            sequenceOrders.append(sequenceOrder)
            AppLogger.shared.debug("  ✅ Created sequence order \(orderIndex + 1)")
            
            // Calculate next target (6% below current target)
            currentTarget = currentTarget * (1.0 - intervalPercent / 100.0)
            orderIndex += 1
        }
        
        AppLogger.shared.debug("=== Final result: \(sequenceOrders.count) sequence orders ===")
        return sequenceOrders
    }
    
    private func getCurrentPrice() -> Double? {
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
        
        // Last resort: use the price from tax lot data (may be yesterday's close)
        let fallbackPrice = taxLotData.first?.price
        AppLogger.shared.debug("⚠️ Using fallback price from tax lot data: $\(fallbackPrice ?? 0)")
        return fallbackPrice
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
            updateSequenceOrders()
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
    
    private func rowStyle(for order: BuySequenceOrder) -> Color {
        if order.orderCost > 1400.0 {
            return .red
        } else if order.trailingStop < 1.0 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerView
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
            // Initialize sequence orders if not already set
            if sequenceOrders.isEmpty {
                sequenceOrders = getSequenceOrders()
            }
        }
        .onChange(of: getDataHash()) { _, _ in
            // Update orders when underlying data changes
            sequenceOrders = getSequenceOrders()
        }
        .sheet(isPresented: $showingConfirmationDialog) {
            confirmationDialogView
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
    
    private var confirmationDialogView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Confirm Buy Sequence Order Submission")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Cancel") {
                    showingConfirmationDialog = false
                    orderToSubmit = nil
                    orderDescriptions = []
                    orderJson = ""
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            
            // Order Descriptions Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Please review the following sequence orders before submission:")
                    .font(.headline)
                

                
                if orderDescriptions.isEmpty {
                    Text("No order descriptions available")
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(orderDescriptions.enumerated()), id: \.offset) { index, description in
                            Text(description)
                                .font(.body)
                                .foregroundColor(.primary)
                                .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // JSON Section
            VStack(alignment: .leading, spacing: 8) {
                Text("JSON to be submitted:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                

                
                ScrollView {
                    Text(orderJson.isEmpty ? "No JSON available" : orderJson)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            HStack {
                Spacer()
                
                Button("Submit Order") {
                    confirmAndSubmitOrder()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding()
    }
    
    private var headerView: some View {
        HStack {
            Text("Buy Sequence Orders")
                .font(.headline)
            
            Spacer()
            
            if !sequenceOrders.isEmpty {
                Button(selectedSequenceOrderIndices.count == sequenceOrders.count ? "Deselect All" : "Select All") {
                    if selectedSequenceOrderIndices.count == sequenceOrders.count {
                        // Deselect all
                        selectedSequenceOrderIndices.removeAll()
                    } else {
                        // Select all
                        selectedSequenceOrderIndices = Set(0..<sequenceOrders.count)
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(.horizontal)
    }
    
    private var contentView: some View {
        Group {
            if sequenceOrders.isEmpty {
                Text("No buy sequence orders available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                orderTableView
            }
        }
    }
    
    private var orderTableView: some View {
        HStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerRow
                    orderRows
                }
            }
            
            VStack {
                Spacer()
                if !selectedSequenceOrderIndices.isEmpty {
                    Button(action: submitSequenceOrders) {
                        VStack {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.title2)
                            Text("Submit\nSequence")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                }
                Spacer()
            }
            .padding(.trailing, 8)
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
        
        let selectedOrders = selectedSequenceOrderIndices.compactMap { index in
            index < sequenceOrders.count ? sequenceOrders[index] : nil
        }
        
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Selected orders count: \(selectedOrders.count)")
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Selected orders details:")
        for (index, order) in selectedOrders.enumerated() {
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT]   Order \(index + 1): shares=\(order.shares), target=\(order.targetPrice), entry=\(order.entryPrice), cost=\(order.orderCost)")
        }
        
        // Get account number from the position
        guard let accountNumberInt = getAccountNumber() else {
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] ❌ Could not get account number for position")
            return
        }
        AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] Account number: \(accountNumberInt)")
        
        // Create sequence order using SchwabClient
        guard let orderToSubmit = SchwabClient.shared.createSequenceOrder(
            symbol: symbol,
            accountNumber: accountNumberInt,
            selectedOrders: selectedOrders
        ) else {
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] ❌ Failed to create sequence order")
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
            AppLogger.shared.debug(orderJson)
        } catch {
            orderJson = "Error encoding order: \(error)"
            AppLogger.shared.debug("🔄 [SEQUENCE-SUBMIT] ❌ JSON encoding error: \(error)")
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
            AppLogger.shared.debug("  Securities account: \(accountContent.securitiesAccount?.accountNumber ?? "nil")")
            AppLogger.shared.debug("  Positions count: \(accountContent.securitiesAccount?.positions.count ?? 0)")
            
            // Check if this account contains the current symbol
            if let positions = accountContent.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        AppLogger.shared.debug("  ✅ Found position for symbol \(symbol) in this account")
                        if let fullAccountNumber = accountContent.securitiesAccount?.accountNumber,
                           let accountNumberInt = Int64(fullAccountNumber) {
                            AppLogger.shared.debug("  ✅ Using full account number: \(fullAccountNumber)")
                            return accountNumberInt
                        } else {
                            AppLogger.shared.debug("  ❌ Could not convert account number to Int64")
                        }
                    }
                }
            }
        }
        
        // Fallback to the truncated version if full account number not found
        AppLogger.shared.debug("❌ No matching account found for symbol \(symbol), using truncated account number: \(accountNumber)")
        return Int64(accountNumber)
    }
    
    private func createOrderDescriptions(orders: [BuySequenceOrder]) -> [String] {
        AppLogger.shared.debug("=== createOrderDescriptions ===")
        AppLogger.shared.debug("Input orders count: \(orders.count)")
        
        var descriptions: [String] = []
        for (index, order) in orders.enumerated() {
            AppLogger.shared.debug("createOrderDescriptions - Processing order \(index + 1): shares=\(order.shares), target=\(order.targetPrice), entry=\(order.entryPrice)")
            
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
    
    private var headerRow: some View {
        HStack {
            Text("")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            
            Text("Order")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
            
            Text("Description")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Shares")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Stop")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .trailing)
            
            Text("Target")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
    }
    
    private var orderRows: some View {
        return ForEach(Array(sequenceOrders.enumerated()), id: \.offset) { index, order in
            orderRow(index: index, order: order, isSelected: selectedSequenceOrderIndices.contains(index))
        }
    }
    
    private func orderRow(index: Int, order: BuySequenceOrder, isSelected: Bool) -> some View {
        HStack {
            Button(action: {
                if isSelected {
                    selectedSequenceOrderIndices.remove(index)
                } else {
                    selectedSequenceOrderIndices.insert(index)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(.green)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30, alignment: .center)
            
            Text("\(order.orderIndex + 1)")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
                .foregroundColor(.green)
            
            Text(order.description)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    copyToClipboard(text: order.description)
                }
            
            Text("\(Int(order.shares))")
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: Double(order.shares), format: "%.0f")
                }
            
            Text(String(format: "%.2f%%", order.trailingStop))
                .font(.caption)
                .frame(width: 100, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.trailingStop, format: "%.2f")
                }
            
            Text(String(format: "%.2f", order.targetPrice))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.targetPrice, format: "%.2f")
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .background(isSelected ? Color.green.opacity(0.2) : rowStyle(for: order).opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - BuySequenceOrder Data Structure

public struct BuySequenceOrder {
    let orderIndex: Int
    let shares: Double
    let targetPrice: Double
    let entryPrice: Double
    let trailingStop: Double
    let orderCost: Double
    let description: String
} 