import SwiftUI

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
        } else if order.orderStrategyType == .TRIGGER { //  order.orderStrategyType == .SINGLE ||
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
            return "STOP \(String(format: "%.2f", activationPrice))"
        }
        
        // For stop orders, the stop price is the activation condition
        if order.orderType == .STOP || order.orderType == .STOP_LIMIT {
            if let stopPrice = order.stopPrice {
                return "STOP \(String(format: "%.2f", stopPrice))"
            }
        }
        
        // For trailing stop orders, show the stop price if available
        if order.orderType == .TRAILING_STOP || order.orderType == .TRAILING_STOP_LIMIT {
            if let stopPrice = order.stopPrice {
                return "STOP \(String(format: "%.2f", stopPrice))"
            }
        }
        
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

#Preview("OrderDetailRow", traits: .landscapeLeft) {
    VStack(spacing: 16) {
        // Sample limit order
        OrderDetailRow(
            order: Order(
                session: nil,
                duration: .GOOD_TILL_CANCEL,
                orderType: .LIMIT,
                quantity: 100,
                price: 150.50,
                orderLegCollection: [
                    OrderLegCollection(
                        instrument: AccountsInstrument(symbol: "AAPL"),
                        instruction: .BUY_TO_OPEN,
                        positionEffect: .OPENING,
                        quantity: 100
                    )
                ],
                orderStrategyType: .SINGLE,
                orderId: 12345,
                status: .working
            ),
            groupOrderId: 12345
        )
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // Sample trailing stop limit order
        OrderDetailRow(
            order: Order(
                session: nil,
                duration: .GOOD_TILL_CANCEL,
                orderType: .TRAILING_STOP_LIMIT,
                quantity: 200,
                stopPriceLinkBasis: .LAST,
                stopPriceLinkType: .PERCENT,
                stopPriceOffset: 2.0,
                priceLinkBasis: .LAST,
                priceLinkType: .PERCENT,
                priceOffset: 3.0,
                orderLegCollection: [
                    OrderLegCollection(
                        instrument: AccountsInstrument(symbol: "TSLA"),
                        instruction: .SELL_TO_CLOSE,
                        positionEffect: .CLOSING,
                        quantity: 200
                    )
                ],
                orderStrategyType: .SINGLE,
                orderId: 12346,
                status: .working
            ),
            groupOrderId: 12346
        )
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        // Sample OCO order
        OrderDetailRow(
            order: Order(
                session: nil,
                duration: .DAY,
                orderType: .STOP_LIMIT,
                quantity: 150,
                stopPrice: 70.00,
                price: 75.25,
                orderLegCollection: [
                    OrderLegCollection(
                        instrument: AccountsInstrument(symbol: "MSFT"),
                        instruction: .BUY_TO_OPEN,
                        positionEffect: .OPENING,
                        quantity: 150
                    )
                ],
                orderStrategyType: .OCO,
                orderId: 12347,
                status: .working
            ),
            groupOrderId: 12347
        )
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    .padding()
}
