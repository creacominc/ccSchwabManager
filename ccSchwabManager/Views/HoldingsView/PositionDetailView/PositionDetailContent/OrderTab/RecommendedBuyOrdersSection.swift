import SwiftUI

struct RecommendedBuyOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    @State private var selectedOrderIndices: Set<Int> = []
    @State private var recommendedBuyOrders: [BuyOrderRecord] = []
    @State private var lastSymbol: String = ""
    @State private var copiedValue: String = "TBD"
    
    private var currentRecommendedBuyOrders: [BuyOrderRecord] {
        // This computed property will recalculate whenever symbol, atrValue, taxLotData, or sharesAvailableForTrading changes
        let orders = calculateRecommendedBuyOrders()
        // Schedule state update for next run loop to avoid "Modifying state during view update" error
        if symbol != lastSymbol {
            DispatchQueue.main.async {
                self.checkAndUpdateSymbol()
            }
        }
        return orders
    }
    
    private func calculateRecommendedBuyOrders() -> [BuyOrderRecord] {
        print("=== calculateRecommendedBuyOrders ===")
        print("Symbol: \(symbol)")
        print("ATR: \(atrValue)%")
        print("Tax lots count: \(taxLotData.count)")
        print("Shares available for trading: \(sharesAvailableForTrading)")
        
        var recommended: [BuyOrderRecord] = []
        
        // Get current price from the first tax lot (they all have the same current price)
        guard let currentPrice = taxLotData.first?.price, currentPrice > 0 else {
            print("❌ No valid current price found")
            return recommended
        }
        
        print("Current price: $\(currentPrice)")
        
        // Calculate current position metrics
        let totalShares = taxLotData.reduce(0.0) { $0 + $1.quantity }
        let totalCost = taxLotData.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalShares > 0 ? totalCost / totalShares : 0.0
        let currentProfitPercent = avgCostPerShare > 0 ? ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0 : 0.0
        
        print("Current position - Shares: \(totalShares), Avg Cost: $\(avgCostPerShare), Current P/L%: \(currentProfitPercent)%")
        
        // Only show buy orders if we have an existing position (shares > 0)
        guard totalShares > 0 else {
            print("❌ No existing position for \(symbol), skipping buy orders")
            return recommended
        }
        
        // Calculate target gain percent based on ATR
        let targetGainPercent = max(15.0, 7.0 * atrValue)
        print("Target gain percent: \(targetGainPercent)% (ATR: \(atrValue)%)")
        
        // Calculate buy order
        let buyOrder = calculateBuyOrder(
            currentPrice: currentPrice,
            avgCostPerShare: avgCostPerShare,
            currentProfitPercent: currentProfitPercent,
            targetGainPercent: targetGainPercent,
            totalShares: totalShares
        )
        
        if let order = buyOrder {
            print("✅ Buy order created: \(order.description)")
            recommended.append(order)
        } else {
            print("❌ Buy order not created")
        }
        
        print("=== Final result: \(recommended.count) recommended buy orders ===")
        return recommended
    }
    
    private func calculateBuyOrder(
        currentPrice: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double,
        targetGainPercent: Double,
        totalShares: Double
    ) -> BuyOrderRecord? {
        
        print("=== calculateBuyOrder ===")
        print("Current price: $\(currentPrice)")
        print("Avg cost per share: $\(avgCostPerShare)")
        print("Current P/L%: \(currentProfitPercent)%")
        print("Target gain %: \(targetGainPercent)%")
        print("Total shares: \(totalShares)")
        print("ATR: \(atrValue)%")
        
        // Calculate total cost of current position
        let totalCost = avgCostPerShare * totalShares
        
        // Calculate the target buy price based on current price and target gain percentage
        // If current P/L% is less than target gain, compute the price at which it would meet the target gain
        let targetBuyPrice: Double
        let entryPrice: Double
        
        if currentProfitPercent < targetGainPercent {
            // Current position is below target gain, so we need to buy at a price that would bring us to target gain
            // The target buy price should be the current price (since that's what we can buy at)
            targetBuyPrice = currentPrice
            // Entry price should be 1 ATR above the current price
            entryPrice = currentPrice * (1.0 + atrValue / 100.0)
        } else {
            // Current position is already above target gain, so we should buy at a higher price
            // Target buy price should be the current price
            targetBuyPrice = currentPrice
            // Entry price should be between 2x and 4x ATR above the current price
            let minEntryPrice = currentPrice * (1.0 + (2.0 * atrValue / 100.0))
            let maxEntryPrice = currentPrice * (1.0 + (4.0 * atrValue / 100.0))
            // Use the midpoint between min and max for now (could be randomized)
            entryPrice = (minEntryPrice + maxEntryPrice) / 2.0
        }
        
        print("Current P/L%: \(currentProfitPercent)%")
        print("Target gain %: \(targetGainPercent)%")
        print("Current price: $\(currentPrice)")
        print("Target buy price: $\(targetBuyPrice)")
        print("Entry price: $\(entryPrice)")
        
        // Calculate how many shares we need to buy to bring the combined position to the target gain percentage
        // We want the new average cost to be such that the target buy price represents the target gain percentage
        let sharesToBuy = (totalShares * targetBuyPrice - totalCost) / (targetBuyPrice - avgCostPerShare)
        
        print("Calculated shares to buy: \(sharesToBuy)")
        
        // Apply limits
        var finalSharesToBuy = max(1.0, ceil(sharesToBuy))
        let orderCost = finalSharesToBuy * targetBuyPrice
        
        print("Initial calculation: \(finalSharesToBuy) shares at $\(targetBuyPrice) = $\(orderCost)")
        
        // Limit to $500 maximum investment
        if orderCost > 500.0 {
            finalSharesToBuy = floor(500.0 / targetBuyPrice)
            print("Order cost \(orderCost) exceeds $500 limit, reducing to \(finalSharesToBuy) shares")
        }
        
        // Ensure at least 1 share
        if finalSharesToBuy < 1.0 {
            finalSharesToBuy = 1.0
            print("Ensuring minimum of 1 share")
        }
        
        // Recalculate final order cost
        let finalOrderCost = finalSharesToBuy * targetBuyPrice
        
        print("Final shares to buy: \(finalSharesToBuy)")
        print("Final order cost: $\(finalOrderCost)")
        
        // Check if order is reasonable
        guard finalSharesToBuy > 0 else {
            print("❌ Buy order not reasonable - shares: \(finalSharesToBuy)")
            return nil
        }
        
        // Warn if order cost exceeds $500 but don't reject
        if finalOrderCost > 500.0 {
            print("⚠️ Warning: Order cost $\(finalOrderCost) exceeds $500 limit, but allowing 1 share minimum")
        }
        
        // Calculate submit date/time
        let (submitDate, isImmediate) = calculateSubmitDate()
        
        // Create description
        let formattedDescription = String(
            format: "BUY %.0f %@ Submit %@ BID >= %.2f TS = %.1f%% Target = %.2f TargetGain = %.1f%%",
            finalSharesToBuy,
            symbol,
            submitDate,
            entryPrice,
            atrValue,
            targetBuyPrice,
            targetGainPercent
        )
        
        return BuyOrderRecord(
            shares: finalSharesToBuy,
            targetBuyPrice: targetBuyPrice,
            entryPrice: entryPrice,
            trailingStop: atrValue,
            targetGainPercent: targetGainPercent,
            currentGainPercent: currentProfitPercent,
            sharesToBuy: finalSharesToBuy,
            orderCost: finalOrderCost,
            description: formattedDescription,
            orderType: "BUY",
            submitDate: submitDate,
            isImmediate: isImmediate
        )
    }
    
    private func calculateSubmitDate() -> (String, Bool) {
        // Check if we can submit immediately (more than 7 days since last buy)
        // For now, we'll assume we can submit immediately
        // TODO: Implement logic to check last buy date from transaction history
        
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        
        // Format for 09:40 local time
        var components = calendar.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 9
        components.minute = 40
        components.second = 0
        
        let targetDate = calendar.date(from: components) ?? tomorrow
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy HH:mm:ss"
        let submitDate = formatter.string(from: targetDate)
        
        // For now, always use scheduled submit (not immediate)
        return (submitDate, false)
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
    
    private func updateRecommendedOrders() {
        recommendedBuyOrders = calculateRecommendedBuyOrders()
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
    
    private func rowStyle(for item: BuyOrderRecord) -> Color {
        if item.orderCost > 500.0 {
            return .red
        } else if item.trailingStop < 1.0 {
            return .orange
        } else {
            return .blue // Use blue to distinguish from sell orders
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
    }
    
    private var headerView: some View {
        HStack {
            Text("Recommended Buy Orders")
                .font(.headline)
            
            Spacer()
            
            Button(selectedOrderIndices.count == currentRecommendedBuyOrders.count ? "Deselect All" : "Select All") {
                if selectedOrderIndices.count == currentRecommendedBuyOrders.count {
                    // Deselect all
                    selectedOrderIndices.removeAll()
                } else {
                    // Select all
                    selectedOrderIndices = Set(0..<currentRecommendedBuyOrders.count)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(currentRecommendedBuyOrders.isEmpty)
        }
        .padding(.horizontal)
    }
    
    private var contentView: some View {
        Group {
            if currentRecommendedBuyOrders.isEmpty {
                Text("No recommended buy orders available")
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
                    Button(action: submitBuyOrders) {
                        VStack {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.title2)
                            Text("Submit\nBuy")
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
    
    private func submitBuyOrders() {
        guard !selectedOrderIndices.isEmpty else { return }
        
        let selectedOrders = selectedOrderIndices.compactMap { index in
            index < currentRecommendedBuyOrders.count ? currentRecommendedBuyOrders[index] : nil
        }
        
        // Create buy order description
        let buyOrderDescription = createBuyOrderDescription(orders: selectedOrders)
        copyToClipboard(text: buyOrderDescription)
        print("Submitted buy orders: \(buyOrderDescription)")
    }
    
    private func createBuyOrderDescription(orders: [BuyOrderRecord]) -> String {
        guard !orders.isEmpty else { return "" }
        
        var description = "Buy Orders for \(symbol):\n"
        
        for (index, order) in orders.enumerated() {
            description += "Order \(index + 1): \(order.description)\n"
        }
        
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
            
            Text("Target")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Cost")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
    }
    
    private var orderRows: some View {
        ForEach(Array(currentRecommendedBuyOrders.enumerated()), id: \.offset) { index, order in
            orderRow(index: index, order: order)
        }
    }
    
    private func orderRow(index: Int, order: BuyOrderRecord) -> some View {
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
            
            Text("\(Int(order.sharesToBuy))")
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: Double(order.sharesToBuy), format: "%.0f")
                }
            
            Text(String(format: "%.2f%%", order.trailingStop))
                .font(.caption)
                .frame(width: 100, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.trailingStop, format: "%.2f")
                }
            
            Text(String(format: "%.2f", order.entryPrice))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.entryPrice, format: "%.2f")
                }
            
            Text(String(format: "%.2f", order.targetBuyPrice))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.targetBuyPrice, format: "%.2f")
                }
            
            Text(String(format: "%.0f", order.orderCost))
                .font(.caption)
                .frame(width: 80, alignment: .trailing)
                .onTapGesture {
                    copyToClipboard(value: order.orderCost, format: "%.0f")
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .background(selectedOrderIndices.contains(index) ? Color.blue.opacity(0.2) : rowStyle(for: order).opacity(0.1))
        .cornerRadius(4)
    }
} 