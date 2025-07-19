import SwiftUI

struct RecommendedOCOOrdersSection: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    @State private var selectedOrderIndices: Set<Int> = []
    @State private var recommendedSellOrders: [SalesCalcResultsRecord] = []
    @State private var recommendedBuyOrders: [BuyOrderRecord] = []
    @State private var lastSymbol: String = ""
    @State private var copiedValue: String = "TBD"
    
    private var currentRecommendedSellOrders: [SalesCalcResultsRecord] {
        let orders = calculateRecommendedSellOrders()
        if symbol != lastSymbol {
            DispatchQueue.main.async {
                self.checkAndUpdateSymbol()
            }
        }
        return orders
    }
    
    private var currentRecommendedBuyOrders: [BuyOrderRecord] {
        let orders = calculateRecommendedBuyOrders()
        if symbol != lastSymbol {
            DispatchQueue.main.async {
                self.checkAndUpdateSymbol()
            }
        }
        return orders
    }
    
    private var allOrders: [(String, Any)] {
        var orders: [(String, Any)] = []
        
        // Add sell orders first
        for order in currentRecommendedSellOrders {
            orders.append(("SELL", order))
        }
        
        // Add buy orders
        for order in currentRecommendedBuyOrders {
            orders.append(("BUY", order))
        }
        
        return orders
    }
    
    private func calculateRecommendedSellOrders() -> [SalesCalcResultsRecord] {
        var recommended: [SalesCalcResultsRecord] = []
        
        guard let currentPrice = getCurrentPrice() else {
            print("❌ No current price available for \(symbol)")
            return recommended
        }
        
        let sortedTaxLots = taxLotData.sorted { $0.costPerShare > $1.costPerShare }
        
        print("=== calculateRecommendedSellOrders ===")
        print("Symbol: \(symbol)")
        print("ATR: \(atrValue)%")
        print("Tax lots count: \(taxLotData.count)")
        print("Shares available for trading: \(sharesAvailableForTrading)")
        print("Current price: $\(currentPrice)")
        print("Sorted tax lots by cost per share (highest first): \(sortedTaxLots.count) lots")
        
        // Calculate Top 100 Order
        if let top100Order = calculateTop100Order(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            print("✅ Top 100 order created: \(top100Order.description)")
            recommended.append(top100Order)
        }
        
        // Calculate Min Shares Order
        if let minSharesOrder = calculateMinSharesFor5PercentProfit(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            print("✅ Min shares order created: \(minSharesOrder.description)")
            recommended.append(minSharesOrder)
        }
        
        // Calculate Min Break Even Order
        if let minBreakEvenOrder = calculateMinBreakEvenOrder(currentPrice: currentPrice, sortedTaxLots: sortedTaxLots) {
            print("✅ Min break even order created: \(minBreakEvenOrder.description)")
            recommended.append(minBreakEvenOrder)
        }
        
        print("=== Final result: \(recommended.count) recommended orders ===")
        return recommended
    }
    
    private func calculateRecommendedBuyOrders() -> [BuyOrderRecord] {
        var recommended: [BuyOrderRecord] = []
        
        guard let currentPrice = getCurrentPrice() else {
            print("❌ No current price available for \(symbol)")
            return recommended
        }
        
        // Calculate total shares and average cost
        let totalShares = taxLotData.reduce(0.0) { $0 + $1.quantity }
        let totalCost = taxLotData.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        
        print("=== calculateRecommendedBuyOrders ===")
        print("Symbol: \(symbol)")
        print("ATR: \(atrValue)%")
        print("Tax lots count: \(taxLotData.count)")
        print("Shares available for trading: \(sharesAvailableForTrading)")
        print("Current price: $\(currentPrice)")
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
    
    // MARK: - Sell Order Calculations (copied from RecommendedSellOrdersSection)
    
    private func getCurrentPrice() -> Double? {
        // Get the current price from the first tax lot (they all have the same current price)
        return taxLotData.first?.price
    }
    
    private func getLimitedATR() -> Double {
        return max(1.0, min(7.0, atrValue))
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
    
    // --- Top 100 Standing Sell ---
    private func calculateTop100Order(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        // Remove the sharesAvailableForTrading check - show all orders regardless of available shares
        
        var sharesToConsider: Double = 0
        var totalCost: Double = 0
        
        for lot in sortedTaxLots {
            let needed = min(lot.quantity, 100.0 - sharesToConsider)
            sharesToConsider += needed
            totalCost += needed * lot.costPerShare
            if sharesToConsider >= 100.0 { break }
        }
        guard sharesToConsider >= 100.0 else { return nil }
        let costPerShare = totalCost / sharesToConsider
        
        // ATR for this order is fixed: 1.5 * 0.25 = 0.375%
        let adjustedATR = 1.5 * 0.25
        
        // Target: 4.65% above breakeven (cost per share) - accounting for wash sale adjustments
        let target = costPerShare * 1.0465
        
        // Entry: Target + (1.5 * ATR) above target
        let entry = target * (1.0 + (adjustedATR / 100.0))
        
        // Exit: 0.9% below target
        let exit = target * 0.991
        
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
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "Top100"
        )
    }

    // --- Minimum ATR-based Standing Sell ---
    private func calculateMinSharesFor5PercentProfit(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        let adjustedATR = 1.5 * getLimitedATR()

        // Only show if position is at least 6% and at least (3.5 * ATR) profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        let minProfitPercent = max(6.0, 3.5 * getLimitedATR())
        guard currentProfitPercent >= minProfitPercent else { return nil }

        // Target: 4.65% above breakeven (avg cost per share) - accounting for wash sale adjustments
        let target = avgCostPerShare * 1.0465
        
        // Entry: Target + (1.5 * ATR) above target
        let entry = target * (1.0 + (adjustedATR / 100.0))
        
        // Exit: 0.9% below target
        let exit = target * 0.991
        
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        
        for lot in sortedTaxLots {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            if lotGainPercent >= 5.0 {
                // Remove the sharesAvailableForTrading limitation - use all available shares in the lot
                let needed = lot.quantity
                sharesToSell += needed
                totalGain += needed * (target - lot.costPerShare)
            }
        }
        
        guard sharesToSell > 0 else { return nil }
        
        let gain = (totalGain / sharesToSell) / (target - avgCostPerShare) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min ATR) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToSell, symbol, entry, target, exit, avgCostPerShare, formatReleaseTime(tomorrow))
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: totalGain,
            breakEven: avgCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: adjustedATR,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinATR"
        )
    }

    // --- Minimum Break-even Standing Sell ---
    private func calculateMinBreakEvenOrder(currentPrice: Double, sortedTaxLots: [SalesCalcPositionsRecord]) -> SalesCalcResultsRecord? {
        let adjustedATR = 1.5 * 0.25 // Fixed at 0.375%

        // Only show if position is at least 1% profitable
        let totalShares = sortedTaxLots.reduce(0.0) { $0 + $1.quantity }
        let totalCost = sortedTaxLots.reduce(0.0) { $0 + $1.costBasis }
        let avgCostPerShare = totalCost / totalShares
        let currentProfitPercent = ((currentPrice - avgCostPerShare) / avgCostPerShare) * 100.0
        guard currentProfitPercent >= 1.0 else { return nil }

        // Target: 4.65% above breakeven (avg cost per share) - accounting for wash sale adjustments
        let target = avgCostPerShare * 1.0465
        
        // Entry: Target + (1.5 * ATR) above target
        let entry = target * (1.0 + (adjustedATR / 100.0))
        
        // Exit: 0.9% below target
        let exit = target * 0.991
        
        var sharesToSell: Double = 0
        var totalGain: Double = 0
        
        for lot in sortedTaxLots {
            let lotGainPercent = ((currentPrice - lot.costPerShare) / lot.costPerShare) * 100.0
            if lotGainPercent >= 1.0 {
                // Remove the sharesAvailableForTrading limitation - use all available shares in the lot
                let needed = lot.quantity
                sharesToSell += needed
                totalGain += needed * (target - lot.costPerShare)
            }
        }
        
        guard sharesToSell > 0 else { return nil }
        
        let gain = (totalGain / sharesToSell) / (target - avgCostPerShare) * 100.0
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        let formattedDescription = String(format: "(Min BE) SELL -%.0f %@ Entry %.2f Target %.2f Exit %.2f Cost/Share %.2f GTC SUBMIT AT %@", sharesToSell, symbol, entry, target, exit, avgCostPerShare, formatReleaseTime(tomorrow))
        return SalesCalcResultsRecord(
            shares: sharesToSell,
            rollingGainLoss: totalGain,
            breakEven: avgCostPerShare,
            gain: gain,
            sharesToSell: sharesToSell,
            trailingStop: adjustedATR,
            entry: entry,
            target: target,
            cancel: exit,
            description: formattedDescription,
            openDate: "MinBE"
        )
    }
    
    // MARK: - Buy Order Calculations (copied from RecommendedBuyOrdersSection)
    
    private func calculateBuyOrder(
        currentPrice: Double,
        avgCostPerShare: Double,
        currentProfitPercent: Double,
        targetGainPercent: Double,
        totalShares: Double
    ) -> BuyOrderRecord? {
        
        print("=== calculateBuyOrder (OCO) ===")
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
        
        let (submitDate, isImmediate) = calculateSubmitDate()
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
    
    private func updateRecommendedOrders() {
        recommendedSellOrders = calculateRecommendedSellOrders()
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
    
    private func rowStyle(for orderType: String, item: Any) -> Color {
        switch orderType {
        case "SELL":
            if let sellOrder = item as? SalesCalcResultsRecord {
                if sellOrder.sharesToSell > sharesAvailableForTrading {
                    return .red
                } else if sellOrder.trailingStop < (2.0 * getLimitedATR()) {
                    return .orange
                } else {
                    return .green
                }
            }
        case "BUY":
            if let buyOrder = item as? BuyOrderRecord {
                if buyOrder.orderCost > 500.0 {
                    return .red
                } else if buyOrder.trailingStop < 1.0 {
                    return .orange
                } else {
                    return .blue
                }
            }
        default:
            return .primary
        }
        return .primary
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
            Text("Recommended OCO Orders")
                .font(.headline)
            
            Spacer()
            
            Button(selectedOrderIndices.count == allOrders.count ? "Deselect All" : "Select All") {
                if selectedOrderIndices.count == allOrders.count {
                    // Deselect all
                    selectedOrderIndices.removeAll()
                } else {
                    // Select all
                    selectedOrderIndices = Set(0..<allOrders.count)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(allOrders.isEmpty)
        }
        .padding(.horizontal)
    }
    
    private var contentView: some View {
        Group {
            if allOrders.isEmpty {
                Text("No recommended OCO orders available")
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
            index < allOrders.count ? allOrders[index] : nil
        }
        
        // Create OCO order description
        let ocoDescription = createOCOOrderDescription(orders: selectedOrders)
        copyToClipboard(text: ocoDescription)
        print("Submitted OCO orders: \(ocoDescription)")
    }
    
    private func createOCOOrderDescription(orders: [(String, Any)]) -> String {
        guard !orders.isEmpty else { return "" }
        
        var description = "OCO Orders for \(symbol):\n"
        
        for (index, (_, order)) in orders.enumerated() {
            if let sellOrder = order as? SalesCalcResultsRecord {
                description += "Order \(index + 1) (SELL): \(sellOrder.description)\n"
            } else if let buyOrder = order as? BuyOrderRecord {
                description += "Order \(index + 1) (BUY): \(buyOrder.description)\n"
            }
        }
        
        return description
    }
    
    private var headerRow: some View {
        HStack {
            Text("")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            
            Text("Type")
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
            
            Text("Entry")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Target")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Cancel")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
    }
    
    private var orderRows: some View {
        ForEach(Array(allOrders.enumerated()), id: \.offset) { index, order in
            orderRow(index: index, orderType: order.0, order: order.1)
        }
    }
    
    private func orderRow(index: Int, orderType: String, order: Any) -> some View {
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
            
            Text(orderType)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
                .foregroundColor(orderType == "SELL" ? .red : .blue)
            
            Group {
                if let sellOrder = order as? SalesCalcResultsRecord {
                    Text(sellOrder.description)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            copyToClipboard(text: sellOrder.description)
                        }
                    
                    Text("\(Int(sellOrder.sharesToSell))")
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: Double(sellOrder.sharesToSell), format: "%.0f")
                        }
                    
                    Text(String(format: "%.2f%%", sellOrder.trailingStop))
                        .font(.caption)
                        .frame(width: 100, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.trailingStop, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", sellOrder.entry))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.entry, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", sellOrder.target))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.target, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", sellOrder.cancel))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: sellOrder.cancel, format: "%.2f")
                        }
                } else if let buyOrder = order as? BuyOrderRecord {
                    Text(buyOrder.description)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture {
                            copyToClipboard(text: buyOrder.description)
                        }
                    
                    Text("\(Int(buyOrder.sharesToBuy))")
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: Double(buyOrder.sharesToBuy), format: "%.0f")
                        }
                    
                    Text(String(format: "%.2f%%", buyOrder.trailingStop))
                        .font(.caption)
                        .frame(width: 100, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: buyOrder.trailingStop, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", buyOrder.entryPrice))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: buyOrder.entryPrice, format: "%.2f")
                        }
                    
                    Text(String(format: "%.2f", buyOrder.targetBuyPrice))
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                        .onTapGesture {
                            copyToClipboard(value: buyOrder.targetBuyPrice, format: "%.2f")
                        }
                    
                    Text("")
                        .font(.caption)
                        .frame(width: 80, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .background(selectedOrderIndices.contains(index) ? Color.blue.opacity(0.2) : rowStyle(for: orderType, item: order).opacity(0.1))
        .cornerRadius(4)
    }
} 