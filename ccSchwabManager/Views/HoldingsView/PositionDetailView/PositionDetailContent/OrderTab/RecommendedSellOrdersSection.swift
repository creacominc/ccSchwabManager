import SwiftUI

struct RecommendedSellOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    @State private var selectedOrderIndices: Set<Int> = []
    @State private var recommendedSellOrders: [SalesCalcResultsRecord] = []
    @State private var lastSymbol: String = ""
    @State private var copiedValue: String = "TBD"
    @State private var isRadioButtonSelected: Bool = false
    
    private var currentRecommendedSellOrders: [SalesCalcResultsRecord] {
        // This computed property will recalculate whenever symbol, atrValue, taxLotData, or sharesAvailableForTrading changes
        let orders = calculateRecommendedSellOrders()
        // Schedule state update for next run loop to avoid "Modifying state during view update" error
        if symbol != lastSymbol {
            DispatchQueue.main.async {
                self.checkAndUpdateSymbol()
            }
        }
        return orders
    }
    
    private func calculateRecommendedSellOrders() -> [SalesCalcResultsRecord] {
        print("=== calculateRecommendedSellOrders ===")
        print("Symbol: \(symbol)")
        print("ATR: \(atrValue)%")
        print("Tax lots count: \(taxLotData.count)")
        print("Shares available for trading: \(sharesAvailableForTrading)")
        
        var recommended: [SalesCalcResultsRecord] = []
        
        // Get current price from the first tax lot (they all have the same current price)
        guard let currentPrice = taxLotData.first?.price, currentPrice > 0 else {
            print("❌ No valid current price found")
            return recommended
        }
        
        print("Current price: $\(currentPrice)")
        
        // Sort tax lots by cost per share (highest first)
        let sortedTaxLots = taxLotData.sorted { $0.costPerShare > $1.costPerShare }
        print("Sorted tax lots by cost per share (highest first): \(sortedTaxLots.count) lots")
        
        // Order 0: Sell top 100 most expensive shares if profitable
        print("--- Calculating Top 100 Order ---")
        let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = top100Order {
            print("✅ Top 100 order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Top 100 order not created")
        }
        
        // Order 1: Minimum shares needed for 5% profit
        print("--- Calculating Min Shares Order ---")
        let minSharesOrder = calculateMinSharesFor5PercentProfit(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = minSharesOrder {
            print("✅ Min shares order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Min shares order not created")
        }

        // Order 2: Minimum break even order (>1% gain)
        print("--- Calculating Min Break Even Order ---")
        let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots)
        if let order = minBreakEvenOrder {
            print("✅ Min break even order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Min break even order not created")
        }
        
        print("=== Final result: \(recommended.count) recommended orders ===")
        return recommended
    }
    
    private func formatReleaseTime(_ date: Date) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 9
        components.minute = 40
        components.second = 0
        
        let targetDate = calendar.date(from: components) ?? date
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy HH:mm:ss"
        return formatter.string(from: targetDate)
    }
    
    private func getLimitedATR() -> Double {
        // Clamp ATR to the range [1, 7] percent
        return max(1.0, min(atrValue, 7.0))
    }
    
    // --- Top 100 Sell Order ---
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        // Only show if at least 100 shares not under contract and held > 30 days
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let sharesUnderContract = SchwabClient.shared.getContractCountForSymbol(symbol) * 100.0
        let sharesNotUnderContract = totalShares - sharesUnderContract
        guard sharesNotUnderContract >= 100.0 else { return nil }
        let sharesOver30Days = sortedTaxLots.filter { (daysSinceDateString(dateString: $0.openDate) ?? 0) > 30 }.reduce(0.0) { $0 + $1.quantity }
        guard sharesOver30Days >= 100.0 else { return nil }
        // Get the 100 most expensive shares
        var sharesToConsider: Double = 0.0
        var totalCost: Double = 0.0
        for lot in sortedTaxLots {
            let needed = min(lot.quantity, 100.0 - sharesToConsider)
            sharesToConsider += needed
            totalCost += needed * lot.costPerShare
            if sharesToConsider >= 100.0 { break }
        }
        guard sharesToConsider >= 100.0 else { return nil }
        let costPerShare = totalCost / sharesToConsider
        // ATR for this order is fixed: 1.5 * 0.25 = 0.375
        let adjustedATR = 1.5 * 0.25
        // Entry: one AATR above last price
        let entry = currentPrice / (1.0 + (adjustedATR / 100.0))
        // Target: 1% above cost per share
        let target = costPerShare * 1.01
        // Exit: 1% above target
        let exit = target / 1.01
        let gain = ((target - costPerShare) / costPerShare) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Top 100) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToConsider, symbol, entry, target, exit, costPerShare, formatReleaseTime(tomorrow))
        return SalesCalcResultsRecord(
            shares: sharesToConsider,
            rollingGainLoss: (target - costPerShare) * sharesToConsider,
            breakEven: costPerShare,
            gain: gain,
            sharesToSell: sharesToConsider,
            trailingStop: adjustedATR,
            entry: entry,
            cancel: exit,
            description: formattedDescription,
            openDate: "Top100"
        )
    }

    // --- Minimum ATR-based Standing Sell ---
    private func calculateMinSharesFor5PercentProfit(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        let limitedATR = getLimitedATR()
        let adjustedATR = 1.5 * limitedATR

        // Only show if position is at least 6% and at least (3.5 * ATR) profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        let minProfitPercent = max(6.0, 3.5 * limitedATR)
        guard currentProfitPercent >= minProfitPercent else { return nil }

        let entry = currentPrice / (1.0 + (1.5 * adjustedATR / 100))
        let target = entry / (1.0 + (1.5 * adjustedATR / 100))
        let exit = target / 1.01

        var sharesUsed: Double = 0.0
        var totalCostUsed: Double = 0.0
        var found = false
        var minimumShares: Double = 0.0
        var minimumCost: Double = 0.0

        for lot in sortedTaxLots {
            let newShares = sharesUsed + lot.quantity
            let newCost = totalCostUsed + lot.quantity * lot.costPerShare
            let avgCost = newCost / newShares
            let gain = ((target - avgCost) / avgCost) * 100.0
            if gain >= 5.0 {
                let baseShares = sharesUsed
                let baseCost = totalCostUsed
                let lotCostPerShare = lot.costPerShare

                var low: Double = 0.0
                var high: Double = lot.quantity
                var bestShares: Double = lot.quantity

                while high - low > 0.01 {
                    let mid = (low + high) / 2.0
                    let testShares = baseShares + mid
                    let testCost = baseCost + mid * lotCostPerShare
                    let testAvgCost = testCost / testShares
                    let testGain = ((target - testAvgCost) / testAvgCost) * 100.0

                    if testGain >= 5.0 {
                        bestShares = mid
                        high = mid
                    } else {
                        low = mid
                    }
                }

                minimumShares = baseShares + bestShares
                minimumCost = baseCost + bestShares * lotCostPerShare
                found = true
                break
            } else {
                sharesUsed = newShares
                totalCostUsed = newCost
            }
        }

        guard found, minimumShares > 0 else { return nil }
        let roundedShares = ceil(minimumShares)
        let finalAvgCost = minimumCost / roundedShares
        let finalGain = ((target - finalAvgCost) / finalAvgCost) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min ATR) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", roundedShares, symbol, entry, target, exit, finalAvgCost, formatReleaseTime(tomorrow))

        return SalesCalcResultsRecord(
            shares: roundedShares,
            rollingGainLoss: (target - finalAvgCost) * roundedShares,
            breakEven: finalAvgCost,
            gain: finalGain,
            sharesToSell: roundedShares,
            trailingStop: adjustedATR,
            entry: entry,
            cancel: exit,
            description: formattedDescription,
            openDate: "ATR"
        )
    }

    // --- Minimum Break-even Standing Sell ---
    private func calculateMinBreakEvenOrder(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        let adjustedATR = 1.5 * 0.25

        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        guard currentProfitPercent >= 1.0 else { return nil }

        let entry = currentPrice / (1.0 + (1.5 * adjustedATR / 100))
        let target = entry / (1.0 + (1.5 * adjustedATR / 100))
        let exit = target / 1.01

        var sharesUsed: Double = 0.0
        var totalCostUsed: Double = 0.0
        var found = false
        var minimumShares: Double = 0.0
        var minimumCost: Double = 0.0

        for lot in sortedTaxLots {
            let newShares = sharesUsed + lot.quantity
            let newCost = totalCostUsed + lot.quantity * lot.costPerShare
            let avgCost = newCost / newShares
            let gain = ((target - avgCost) / avgCost) * 100.0
            if gain >= 1.0 {
                let baseShares = sharesUsed
                let baseCost = totalCostUsed
                let lotCostPerShare = lot.costPerShare

                var low: Double = 0.0
                var high: Double = lot.quantity
                var bestShares: Double = lot.quantity

                while high - low > 0.01 {
                    let mid = (low + high) / 2.0
                    let testShares = baseShares + mid
                    let testCost = baseCost + mid * lotCostPerShare
                    let testAvgCost = testCost / testShares
                    let testGain = ((target - testAvgCost) / testAvgCost) * 100.0

                    if testGain >= 1.0 {
                        bestShares = mid
                        high = mid
                    } else {
                        low = mid
                    }
                }

                minimumShares = baseShares + bestShares
                minimumCost = baseCost + bestShares * lotCostPerShare
                found = true
                break
            } else {
                sharesUsed = newShares
                totalCostUsed = newCost
            }
        }

        guard found, minimumShares > 0 else { return nil }
        let roundedShares = ceil(minimumShares)
        let finalAvgCost = minimumCost / roundedShares
        let finalGain = ((target - finalAvgCost) / finalAvgCost) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", roundedShares, symbol, entry, target, exit, finalAvgCost, formatReleaseTime(tomorrow))

        return SalesCalcResultsRecord(
            shares: roundedShares,
            rollingGainLoss: (target - finalAvgCost) * roundedShares,
            breakEven: finalAvgCost,
            gain: finalGain,
            sharesToSell: roundedShares,
            trailingStop: adjustedATR,
            entry: entry,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinBE"
        )
    }
    
    private func updateRecommendedOrders() {
        recommendedSellOrders = calculateRecommendedSellOrders()
    }
    
    private func checkAndUpdateSymbol() {
        if symbol != lastSymbol {
            print("Symbol changed from \(lastSymbol) to \(symbol)")
            lastSymbol = symbol
            copiedValue = "TBD"
            selectedOrderIndices.removeAll()
            updateRecommendedOrders()
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
    
    private func rowStyle(for item: SalesCalcResultsRecord) -> Color {
        if item.sharesToSell > sharesAvailableForTrading {
            return .red
        } else if item.trailingStop < (2.0 * getLimitedATR()) {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerView
            contentView
            if copiedValue != "TBD" {
                Text("Copied: \(copiedValue)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text("Recommended OCO")
                .font(.headline)
            
            Spacer()
            
            Button(selectedOrderIndices.count == currentRecommendedSellOrders.count ? "Deselect All" : "Select All") {
                if selectedOrderIndices.count == currentRecommendedSellOrders.count {
                    // Deselect all
                    selectedOrderIndices.removeAll()
                } else {
                    // Select all
                    selectedOrderIndices = Set(0..<currentRecommendedSellOrders.count)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(currentRecommendedSellOrders.isEmpty)
        }
        .padding(.horizontal)
    }
    
    private var contentView: some View {
        Group {
            if currentRecommendedSellOrders.isEmpty {
                Text("No recommended sell orders available")
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
                if !selectedOrderIndices.isEmpty {
                    Button(action: submitOCOOrders) {
                        VStack {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.title2)
                            Text("Submit\nOCO")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                }
                Spacer()
            }
            .padding(.trailing, 8)
        }
    }
    
    private func submitOCOOrders() {
        guard !selectedOrderIndices.isEmpty else { return }
        
        let selectedOrders = selectedOrderIndices.compactMap { index in
            index < currentRecommendedSellOrders.count ? currentRecommendedSellOrders[index] : nil
        }
        
        // Create OCO order description
        let ocoDescription = createOCOOrderDescription(orders: selectedOrders)
        copyToClipboard(text: ocoDescription)
        print("Submitted OCO order: \(ocoDescription)")
    }
    
    private func createOCOOrderDescription(orders: [SalesCalcResultsRecord]) -> String {
        guard !orders.isEmpty else { return "" }
        
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let releaseTime = formatReleaseTime(tomorrow)
        
        var description = "OCO Order Group for \(symbol):\n"
        
        for (index, order) in orders.enumerated() {
            description += "Order \(index + 1): \(order.description)\n"
        }
        
        description += "Submit at: \(releaseTime)"
        return description
    }
    
    private var headerRow: some View {
        HStack {
            Text("")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            
            Text("Description")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Shares")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Trailing Stop")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .trailing)
            
            Text("Entry")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Cancel")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Gain %")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
    }
    
    private var orderRows: some View {
        ForEach(Array(currentRecommendedSellOrders.enumerated()), id: \.offset) { index, order in
            orderRow(index: index, order: order)
        }
    }
    
    private func orderRow(index: Int, order: SalesCalcResultsRecord) -> some View {
        HStack {
            Button(action: {
                if selectedOrderIndices.contains(index) {
                    selectedOrderIndices.remove(index)
                } else {
                    selectedOrderIndices.insert(index)
                }
            }) {
                Image(systemName: selectedOrderIndices.contains(index) ? "checkmark.square.fill" : "square")
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30, alignment: .center)
            
            Text(order.description)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture {
                    copyToClipboard(text: order.description)
                }
            
            Text("\(Int(order.sharesToSell))")
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: Double(order.sharesToSell), format: "%.0f")
                }
            
            Text(String(format: "%.2f%%", order.trailingStop))
                .font(.caption)
                .frame(width: 100, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.trailingStop, format: "%.2f")
                }
            
            Text(String(format: "%.2f", order.entry))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.entry, format: "%.2f")
                }
            
            Text(String(format: "%.2f", order.cancel))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.cancel, format: "%.2f")
                }
            
            Text(String(format: "%.1f%%", order.gain))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.gain, format: "%.1f")
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(selectedOrderIndices.contains(index) ? Color.blue.opacity(0.2) : rowStyle(for: order).opacity(0.1))
        .cornerRadius(4)
    }
} 
