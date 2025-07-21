import SwiftUI

struct CurrentOrdersSection: View {
    let symbol: String
    @State private var selectedOrderGroups: Set<Int64> = []
    
    private var openStatuses: [ActiveOrderStatus] {
        return [.awaitingParentOrder, .awaitingCondition, .awaitingSellStopCondition, .awaitingBuyStopCondition, .awaitingManualReview, 
                .accepted, .pendingActivation, .queued, .working, .new, .awaitingReleaseTime, 
                .pendingAcknowledgement, .pendingRecall]
    }
    
    private var currentOrders: [Order] {
        let allOrders = SchwabClient.shared.getOrderList()
        var filteredOrders: [Order] = []
        
        print("[OrderTab] Checking open orders for symbol: \(symbol)")
        print("[OrderTab] Total orders from SchwabClient: \(allOrders.count)")
        
        for order in allOrders {
            // Check if order matches the symbol
            var orderMatchesSymbol = false
            var hasOpenChildOrder = false
            
            // For OCO orders, check if any child orders are open and match the symbol
            if order.orderStrategyType == .OCO, let childOrderStrategies = order.childOrderStrategies {
                for childStrategy in childOrderStrategies {
                    if let legs = childStrategy.orderLegCollection {
                        for leg in legs {
                            if let instrument = leg.instrument, 
                               let symbol = instrument.symbol,
                               symbol == self.symbol {
                                orderMatchesSymbol = true
                                
                                // Check if this child order is open
                                if let childStatus = childStrategy.status,
                                   let childActiveStatus = ActiveOrderStatus(from: childStatus, order: childStrategy),
                                   openStatuses.contains(childActiveStatus) {
                                    hasOpenChildOrder = true
                                    break
                                }
                            }
                        }
                    }
                    if hasOpenChildOrder { break }
                }
            } else {
                // For non-OCO orders, check main order legs
                if let legs = order.orderLegCollection {
                    for leg in legs {
                        if let instrument = leg.instrument, 
                           let symbol = instrument.symbol,
                           symbol == self.symbol {
                            orderMatchesSymbol = true
                            break
                        }
                    }
                }
            }
            
            if orderMatchesSymbol {
                print("[OrderTab] Found order for symbol \(self.symbol): ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil"), StrategyType=\(order.orderStrategyType?.rawValue ?? "nil")")
                
                // For OCO orders, only add if there are open child orders
                if order.orderStrategyType == .OCO {
                    if hasOpenChildOrder {
                        print("[OrderTab] OCO order has open child orders")
                        filteredOrders.append(order)
                    } else {
                        print("[OrderTab] OCO order has no open child orders")
                    }
                } else {
                    // For non-OCO orders, check if order status is open
                    if let status = order.status,
                       let activeStatus = ActiveOrderStatus(from: status, order: order),
                       openStatuses.contains(activeStatus) {
                        print("[OrderTab] Order is open: \(activeStatus.shortDisplayName)")
                        filteredOrders.append(order)
                    } else {
                        print("[OrderTab] Order is not open: \(order.status?.rawValue ?? "nil")")
                    }
                }
            }
        }
        
        print("[OrderTab] Found \(filteredOrders.count) open orders for symbol \(symbol)")
        
        // Debug: Print all order IDs being returned
        print("[OrderTab] Order IDs being returned:")
        for (index, order) in filteredOrders.enumerated() {
            print("[OrderTab]   \(index + 1). ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil")")
        }
        
        return filteredOrders
    }
    
    private func performCancellations() {
        // TODO: Implement cancellation logic
        print("Cancelling order groups: \(selectedOrderGroups)")
        selectedOrderGroups.removeAll()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Current Orders")
                    .font(.headline)
                
                Spacer()
                
                Button(selectedOrderGroups.count == currentOrders.count ? "Deselect All" : "Select All") {
                    if selectedOrderGroups.count == currentOrders.count {
                        // Deselect all
                        selectedOrderGroups.removeAll()
                    } else {
                        // Select all
                        let allOrderIds = currentOrders.compactMap { $0.orderId }
                        selectedOrderGroups = Set(allOrderIds)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(currentOrders.isEmpty)
            }
            .padding(.horizontal)
            
            if currentOrders.isEmpty {
                Text("No open orders for \(symbol)")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
                    .onAppear {
                        print("[OrderTab] No open orders for symbol: \(symbol)")
                    }
            } else {
                HStack(alignment: .top, spacing: 16) {
                    // Orders list
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(currentOrders) { order in
                                OrderGroupView(
                                    order: order,
                                    selectedOrderGroups: $selectedOrderGroups
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Cancel button on the right
                    if !selectedOrderGroups.isEmpty {
                        VStack {
                            Button(action: performCancellations) {
                                VStack {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                    Text("Cancel\nSelected")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(8)
                            }
                            Spacer()
                        }
                        .padding(.trailing, 8)
                    }
                }
            }
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

struct OrderGroupView: View {
    let order: Order
    @Binding var selectedOrderGroups: Set<Int64>
    
    private var openStatuses: [OrderStatus] {
        return [.awaitingParentOrder, .awaitingCondition, .awaitingStopCondition, .awaitingManualReview, 
                .accepted, .pendingActivation, .queued, .working, .new, .awaitingReleaseTime, 
                .pendingAcknowledgement, .pendingRecall]
    }
    
    private var displayableOrders: [Order] {
        var orders: [Order] = []
        
        func collectOrdersRecursively(_ order: Order) {
            // Add the current order if it's open and has order legs (or is not an OCO parent)
            if let status = order.status, openStatuses.contains(status) {
                // For OCO parent orders, only add if they have order legs
                if order.orderStrategyType == .OCO {
                    if let orderLegs = order.orderLegCollection, !orderLegs.isEmpty {
                        orders.append(order)
                    }
                } else {
                    orders.append(order)
                }
            }
            // Recursively add child orders for TRIGGER and OCO
            if let childStrategies = order.childOrderStrategies, !childStrategies.isEmpty {
                for child in childStrategies {
                    collectOrdersRecursively(child)
                }
            }
        }
        
        collectOrdersRecursively(order)
        // Sort: active order (not AWAITING_PARENT_ORDER) first, then children
        let sorted = orders.sorted { lhs, rhs in
            let lhsIsParent = lhs.status != .awaitingParentOrder
            let rhsIsParent = rhs.status != .awaitingParentOrder
            if lhsIsParent == rhsIsParent {
                return (lhs.enteredTime ?? "") < (rhs.enteredTime ?? "")
            }
            return lhsIsParent && !rhsIsParent
        }
        return sorted
    }
    
    private var groupOrderId: Int64? {
        // For OCO orders, use the parent order ID
        if order.orderStrategyType == .OCO {
            return order.orderId
        } else {
            // For single orders, use the order ID
            return order.orderId
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if displayableOrders.count > 1 {
                HStack(alignment: .top, spacing: 8) {
                    // Checkbox for the entire group
                    Button(action: {
                        if let groupId = groupOrderId {
                            if selectedOrderGroups.contains(groupId) {
                                selectedOrderGroups.remove(groupId)
                            } else {
                                selectedOrderGroups.insert(groupId)
                            }
                        }
                    }) {
                        Image(systemName: groupOrderId != nil && selectedOrderGroups.contains(groupOrderId!) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Vertical line spanning all orders, dynamically sized
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .fill(Color.gray.opacity(0.5))
                                .frame(width: 2)
                                .frame(height: geometry.size.height)
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(width: 10)
                    .padding(.vertical, 0)

                    // Order details
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(displayableOrders, id: \.orderId) { displayOrder in
                            OrderDetailRow(order: displayOrder, groupOrderId: groupOrderId)
                                .padding(.vertical, 2)
                        }
                    }
                    .background(GeometryReader { geo in
                        Color.clear.preference(key: OrderGroupHeightKey.self, value: geo.size.height)
                    })
                    .onPreferenceChange(OrderGroupHeightKey.self) { _ in }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(6)
            } else if let singleOrder = displayableOrders.first {
                // Single order - show without vertical line
                HStack(alignment: .top, spacing: 8) {
                    // Checkbox
                    Button(action: {
                        if let groupId = groupOrderId {
                            if selectedOrderGroups.contains(groupId) {
                                selectedOrderGroups.remove(groupId)
                            } else {
                                selectedOrderGroups.insert(groupId)
                            }
                        }
                    }) {
                        Image(systemName: groupOrderId != nil && selectedOrderGroups.contains(groupOrderId!) ? "checkmark.square.fill" : "square")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Order details
                    OrderDetailRow(order: singleOrder, groupOrderId: groupOrderId)
                        .padding(.vertical, 2)

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(6)
            }
        }
        .onAppear {
            print("[OrderTab] Rendering order group: ID=\(order.orderId?.description ?? "nil"), Status=\(order.status?.rawValue ?? "nil")")
        }
    }
}

struct OrderDetailRow: View {
    let order: Order
    let groupOrderId: Int64?
    
    private func formatOrderDescription(order: Order) -> String {
        var description = ""
        
        // Get the first order leg for basic information
        guard let firstLeg = order.orderLegCollection?.first else {
            return "Unknown Order - No order legs"
        }
        
        guard let symbol = firstLeg.instrument?.symbol else {
            return "Unknown Order - No symbol"
        }
        
        guard let instruction = firstLeg.instruction else {
            return "Unknown Order - No instruction"
        }
        
        // 1. Action and Quantity
        let action = formatAction(instruction: instruction)
        let quantity = formatQuantity(order: order, positionEffect: firstLeg.positionEffect)
        description += "\(action) \(quantity) \(symbol)"
        
        // 2. Price Information
        if let priceInfo = formatPriceInformation(order: order) {
            description += " \(priceInfo)"
        }
        
        // 3. Stop/Limit Information
        if let stopLimitInfo = formatStopLimitInformation(order: order) {
            description += " \(stopLimitInfo)"
        }
        
        // 4. Order Type
        if let orderType = order.orderType {
            description += " \(formatOrderType(orderType))"
        } else if order.orderStrategyType == .SINGLE || order.orderStrategyType == .TRIGGER {
            description += " TRSTPLMT"
        }
        
        // 5. Stop Type (for trailing stop orders)
        if let stopType = order.stopType {
            description += " \(formatStopType(stopType))"
        }
        
        // 6. Duration
        if let duration = order.duration {
            description += " \(formatDuration(duration))"
        } else if order.orderStrategyType == .SINGLE || order.orderStrategyType == .TRIGGER {
            description += " GTC"
        }
        
        // 7. Strategy Type (for OCO/TRIGGER orders)
        if let strategyType = order.orderStrategyType {
            if strategyType == .OCO {
                description += " OCO"
            } else if strategyType == .TRIGGER {
                description += " TRG BY"
            }
        }
        
        // 8. Order ID
        if let orderId = order.orderId {
            description += " #\(orderId)"
        }
        
        // 9. Release Time
        if let releaseTime = order.releaseTime {
            description += " SUBMIT AT \(formatReleaseTime(releaseTime))"
        }
        
        // 10. Cancel Time
        if let cancelTimeDate = order.cancelTime {
            let formatter = ISO8601DateFormatter()
            let cancelTimeString = formatter.string(from: cancelTimeDate)
            description += " CANCEL AT \(formatReleaseTime(cancelTimeString))"
        }
        
        // 11. Activation Condition (if applicable)
        if let activationInfo = formatActivationCondition(order: order, symbol: symbol) {
            description += " WHEN \(activationInfo)"
        }
        
        // 12. Cancel Condition (if applicable)
        if let cancelInfo = formatCancelCondition(order: order, symbol: symbol) {
            description += " CANCEL IF \(cancelInfo)"
        }
        
        // 13. Position Effect
        if let positionEffect = firstLeg.positionEffect {
            description += " \(formatPositionEffect(positionEffect))"
        }
        
        return description
    }
    
    private func formatAction(instruction: OrderInstructionType) -> String {
        switch instruction {
        case .BUY, .BUY_TO_COVER, .BUY_TO_OPEN, .BUY_TO_CLOSE:
            return "BUY"
        case .SELL, .SELL_SHORT, .SELL_TO_OPEN, .SELL_TO_CLOSE, .SELL_SHORT_EXEMPT:
            return "SELL"
        case .EXCHANGE:
            return "EXCHANGE"
        }
    }
    
    private func formatQuantity(order: Order, positionEffect: PositionEffectType?) -> String {
        let quantity = order.quantity ?? 0
        
        // Always show quantity as a number of shares
        if let positionEffect = positionEffect {
            switch positionEffect {
            case .OPENING:
                return "+\(Int(quantity))"
            case .CLOSING:
                // For closing positions, show negative quantity
                return "-\(Int(quantity))"
            case .AUTOMATIC:
                return "+\(Int(quantity))"
            case .UNKNOWN:
                return "+\(Int(quantity))"
            }
        }
        
        return "+\(Int(quantity))"
    }
    
    private func formatPriceInformation(order: Order) -> String? {
        // For trailing stop limit orders, show the price link information
        if order.orderType == .TRAILING_STOP_LIMIT || order.orderStrategyType == .SINGLE {
            if let priceLinkBasis = order.priceLinkBasis,
               let priceLinkType = order.priceLinkType,
               let priceOffset = order.priceOffset {
                
                let basisStr = formatPriceLinkBasis(priceLinkBasis)
                let typeStr = formatPriceLinkType(priceLinkType)
                
                // Format offset based on price link type
                let offsetStr: String
                if priceLinkType == .PERCENT {
                    // For percentage, show as whole number (e.g., 3.00 -> 3.00%)
                    offsetStr = String(format: "%.2f", priceOffset)
                } else {
                    // For other types, show as decimal
                    offsetStr = String(format: "%.2f", priceOffset)
                }
                
                let sign = priceOffset >= 0 ? "+" : ""
                
                return "@\(basisStr)\(sign)\(offsetStr)\(typeStr)"
            }
        }
        
        // For regular limit orders, show the price
        if let price = order.price {
            return "@\(String(format: "%.2f", price))"
        }
        
        return nil
    }
    
    private func formatOrderType(_ orderType: OrderType) -> String {
        switch orderType {
        case .MARKET:
            return "MKT"
        case .LIMIT:
            return "LMT"
        case .STOP:
            return "STP"
        case .STOP_LIMIT:
            return "STPLMT"
        case .TRAILING_STOP:
            return "TRSTP"
        case .TRAILING_STOP_LIMIT:
            return "TRSTPLMT"
        case .MARKET_ON_CLOSE:
            return "MOC"
        case .LIMIT_ON_CLOSE:
            return "LOC"
        default:
            return orderType.rawValue
        }
    }
    
    private func formatStopLimitInformation(order: Order) -> String? {
        // For trailing stop limit orders, show the stop price information
        if order.orderType == .TRAILING_STOP_LIMIT || order.orderStrategyType == .SINGLE {
            if let stopPriceLinkBasis = order.stopPriceLinkBasis,
               let stopPriceLinkType = order.stopPriceLinkType,
               let stopPriceOffset = order.stopPriceOffset {
                
                let basisStr = formatPriceLinkBasis(stopPriceLinkBasis)
                let typeStr = formatPriceLinkType(stopPriceLinkType)
                
                // Format offset based on price link type
                let offsetStr: String
                if stopPriceLinkType == .PERCENT {
                    // For percentage, show as whole number (e.g., 3.00 -> 3.00%)
                    offsetStr = String(format: "%.2f", stopPriceOffset)
                } else {
                    // For other types, show as decimal
                    offsetStr = String(format: "%.2f", stopPriceOffset)
                }
                
                let sign = stopPriceOffset >= 0 ? "+" : ""
                
                return "\(basisStr)\(sign)\(offsetStr)\(typeStr)"
            }
        }
        
        // For regular stop limit orders
        if order.orderType == .STOP_LIMIT {
            var parts: [String] = []
            
            if let stopPrice = order.stopPrice {
                parts.append(String(format: "%.2f", stopPrice))
            }
            
            if let price = order.price {
                parts.append(String(format: "%.2f", price))
            }
            
            if !parts.isEmpty {
                return parts.joined(separator: " ")
            }
        }
        
        return nil
    }
    
    private func formatDuration(_ duration: DurationType) -> String {
        switch duration {
        case .DAY:
            return "DAY"
        case .GOOD_TILL_CANCEL:
            return "GTC"
        case .FILL_OR_KILL:
            return "FOK"
        case .IMMEDIATE_OR_CANCEL:
            return "IOC"
        case .END_OF_WEEK:
            return "EOW"
        case .END_OF_MONTH:
            return "EOM"
        case .NEXT_END_OF_MONTH:
            return "NEOM"
        case .UNKNOWN:
            return "UNK"
        }
    }
    
    private func formatReleaseTime(_ releaseTime: String) -> String {
        // Parse the ISO8601 date string and format it
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: releaseTime) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            return outputFormatter.string(from: date)
        }
        return releaseTime
    }
    
    private func formatActivationCondition(order: Order, symbol: String) -> String? {
        // For orders with activation price
        if let activationPrice = order.activationPrice {
            return "\(symbol) BID AT OR ABOVE \(String(format: "%.2f", activationPrice))"
        }
        
        // For stop orders, the stop price is the activation condition
        if order.orderType == .STOP || order.orderType == .STOP_LIMIT {
            if let stopPrice = order.stopPrice {
                return "\(symbol) BID AT OR ABOVE \(String(format: "%.2f", stopPrice))"
            }
        }
        
        return nil
    }
    
    private func formatCancelCondition(order: Order, symbol: String) -> String? {
        // This would be implemented based on the specific cancel conditions
        // For now, return nil as this would need to be determined from the order data
        return nil
    }
    
    private func formatPriceLinkBasis(_ basis: PriceLinkBasis) -> String {
        switch basis {
        case .BID:
            return "BID"
        case .ASK:
            return "ASK"
        case .LAST:
            return "LAST"
        case .MARK:
            return "MARK"
        case .AVERAGE:
            return "AVG"
        case .BASE:
            return "BASE"
        case .TRIGGER:
            return "TRIG"
        case .ASK_BID:
            return "ASK_BID"
        case .MANUAL:
            return "MANUAL"
        }
    }
    
    private func formatPriceLinkType(_ type: PriceLinkType) -> String {
        switch type {
        case .VALUE:
            return ""
        case .PERCENT:
            return "%"
        case .TICK:
            return "T"
        }
    }
    
    private func formatStrategyType(_ strategyType: OrderStrategyType) -> String {
        switch strategyType {
        case .SINGLE:
            return ""
        case .OCO:
            return "OCO"
        case .TRIGGER:
            return "TRIGGER"
        case .PAIR:
            return "PAIR"
        case .FLATTEN:
            return "FLATTEN"
        case .TWO_DAY_SWAP:
            return "TWO_DAY_SWAP"
        case .BLAST_ALL:
            return "BLAST_ALL"
        case .CANCEL:
            return "CANCEL"
        case .RECALL:
            return "RECALL"
        }
    }
    
    private func formatPositionEffect(_ positionEffect: PositionEffectType) -> String {
        switch positionEffect {
        case .OPENING:
            return "[TO OPEN]"
        case .CLOSING:
            return "[TO CLOSE]"
        case .AUTOMATIC:
            return "[AUTO]"
        case .UNKNOWN:
            return ""
        }
    }
    
    private func formatStopType(_ stopType: StopType) -> String {
        switch stopType {
        case .STANDARD:
            return "STD"
        case .BID:
            return "BID"
        case .ASK:
            return "ASK"
        case .LAST:
            return "LAST"
        case .MARK:
            return "MARK"
        }
    }
    
    var body: some View {
        Text(formatOrderDescription(order: order))
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
            .onTapGesture {
                // Only copy to clipboard, don't toggle checkbox
                copyToClipboard(text: formatOrderDescription(order: order))
            }
            .onAppear {
                let description = formatOrderDescription(order: order)
                print("=== ORDER DESCRIPTION DEBUG ===")
                print("Order ID: \(order.orderId?.description ?? "nil")")
                print("Order Status: \(order.status?.rawValue ?? "nil")")
                print("Order Type: \(order.orderType?.rawValue ?? "nil")")
                print("Strategy Type: \(order.orderStrategyType?.rawValue ?? "nil")")
                print("Duration: \(order.duration?.rawValue ?? "nil")")
                print("Release Time: \(order.releaseTime ?? "nil")")
                print("Price: \(order.price?.description ?? "nil")")
                print("Stop Price: \(order.stopPrice?.description ?? "nil")")
                print("Activation Price: \(order.activationPrice?.description ?? "nil")")
                print("Price Link Basis: \(order.priceLinkBasis?.rawValue ?? "nil")")
                print("Price Link Type: \(order.priceLinkType?.rawValue ?? "nil")")
                print("Price Offset: \(order.priceOffset?.description ?? "nil")")
                print("Stop Price Link Basis: \(order.stopPriceLinkBasis?.rawValue ?? "nil")")
                print("Stop Price Link Type: \(order.stopPriceLinkType?.rawValue ?? "nil")")
                print("Stop Price Offset: \(order.stopPriceOffset?.description ?? "nil")")
                print("Stop Type: \(order.stopType?.rawValue ?? "nil")")
                print("---")
                print("FORMATTED DESCRIPTION:")
                print(description)
                print("=== END DEBUG ===")
            }
    }
    
    private func copyToClipboard(text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
} 

private struct OrderGroupHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
} 
