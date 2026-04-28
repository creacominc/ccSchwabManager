import SwiftUI

struct OrderDetailRow: View {
    let order: Order
    let groupOrderId: Int64?
    /// Latest quote for the symbol; used to estimate the live trailing stop price.
    var quote: Quote? = nil
    /// Last-price fallback for trailing-stop estimation when the quote is missing.
    var lastPriceFallback: Double? = nil
    /// Current recommended sell/buy orders for the symbol, used to find a closest match.
    var recommendedSellOrders: [SalesCalcResultsRecord] = []
    var recommendedBuyOrders: [BuyOrderRecord] = []
    /// True when the recommendations have been loaded (even if both arrays are empty).
    /// Distinguishes "no match" from "recommendations not yet loaded".
    var recommendationsAvailable: Bool = false

    private var displayInfo: CurrentOrderDisplayInfo? {
        CurrentOrderDisplayInfo(
            order: order,
            groupOrderId: groupOrderId,
            quote: quote,
            lastPriceFallback: lastPriceFallback
        )
    }

    private var sellRecommendations: [RecommendedOrderDisplayInfo] {
        recommendedSellOrders.map {
            RecommendedOrderDisplayInfo.from(sell: $0, quote: quote, lastPriceFallback: lastPriceFallback)
        }
    }

    private var buyRecommendations: [RecommendedOrderDisplayInfo] {
        recommendedBuyOrders.map {
            RecommendedOrderDisplayInfo.from(buy: $0, quote: quote, lastPriceFallback: lastPriceFallback)
        }
    }

    private var comparison: OrderComparisonInfo? {
        guard let info = displayInfo else { return nil }
        let suggestion = OrderComparisonMatcher.bestMatch(
            for: info,
            sells: sellRecommendations,
            buys: buyRecommendations
        )
        return OrderComparisonInfo(current: info, suggestion: suggestion)
    }

    var body: some View {
        if let info = displayInfo {
            structuredBody(info: info)
        } else {
            Text(formatOrderDescription(order: order))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func structuredBody(info: CurrentOrderDisplayInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            headerLine(info: info)
            orderFactsLine(info: info)
            comparisonLine(info: info)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            copyToClipboard(text: copySummary(info: info))
        }
    }

    // MARK: - Header

    private func headerLine(info: CurrentOrderDisplayInfo) -> some View {
        HStack(spacing: 8) {
            Text(info.side.label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(sideColor(info.side))

            Text(quantityLabel(info: info))
                .font(.caption)
                .fontWeight(.semibold)

            Text(info.symbol)
                .font(.caption)
                .fontWeight(.semibold)

            if let typeLabel = orderTypeLabel(info: info) {
                Text(typeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let badge = statusBadge(info.status) {
                Text(badge)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(statusBadgeBackground(info.status))
                    .foregroundColor(.primary)
                    .cornerRadius(4)
            }

            if info.strategy == .OCO {
                Text("OCO")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(4)
            } else if info.strategy == .TRIGGER {
                Text("TRG")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
            }

            Spacer(minLength: 4)

            if let orderId = info.orderId {
                Text("#\(orderId)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Facts line

    private func orderFactsLine(info: CurrentOrderDisplayInfo) -> some View {
        HStack(spacing: 6) {
            ForEach(orderFacts(info: info), id: \.self) { fact in
                factChip(fact)
            }
            Spacer(minLength: 0)
        }
    }

    private func orderFacts(info: CurrentOrderDisplayInfo) -> [String] {
        var facts: [String] = []

        if let limit = info.limitPrice {
            let label = info.orderType == .TRAILING_STOP_LIMIT ? "Target" : "Limit"
            facts.append("\(label) $\(format(limit))")
        }

        if let trail = info.trailPercent {
            let basis = info.stopPriceLinkBasis.map(formatBasis) ?? ""
            facts.append("Trail \(format(trail))%\(basis.isEmpty ? "" : " \(basis)")")
        } else if let stopOffset = info.stopPriceOffset, info.stopPriceLinkType == .VALUE {
            facts.append("Trail $\(format(stopOffset))")
        }

        // Trailing-stop / stop-limit variants: `activationPrice` returned by Schwab IS the
        // current stop trigger, so fold it into the stop chip rather than showing a
        // duplicate "Activation" label. Estimated stops are only used as a last resort
        // when neither the API stop nor activation is provided.
        let stopForOrder = info.stopPrice ?? (isStopOrderType(info) ? info.activationPrice : nil)
        if let stop = stopForOrder {
            facts.append("Stop $\(format(stop))")
        } else if let est = info.estimatedStopPrice, info.hasTrailingStop {
            facts.append("Est Stop $\(format(est))")
        }

        // "Activation" only makes sense when it is a *separate* conditional trigger
        // (TRIGGER child orders awaiting parent, or non-stop order types). For ordinary
        // STOP / TRAILING_STOP variants it just repeats the stop, so suppress it.
        if let activation = info.activationPrice,
           stopForOrder != activation,
           shouldShowActivation(info) {
            facts.append("Activation $\(format(activation))")
        }

        if let duration = info.duration {
            facts.append(formatDuration(duration))
        } else if info.strategy == .SINGLE || info.strategy == .TRIGGER {
            facts.append("GTC")
        }

        if let positionEffect = info.positionEffect {
            switch positionEffect {
            case .OPENING: facts.append("Open")
            case .CLOSING: facts.append("Close")
            case .AUTOMATIC, .UNKNOWN: break
            }
        }

        return facts
    }

    private func isStopOrderType(_ info: CurrentOrderDisplayInfo) -> Bool {
        switch info.orderType {
        case .STOP?, .STOP_LIMIT?, .TRAILING_STOP?, .TRAILING_STOP_LIMIT?:
            return true
        default:
            return false
        }
    }

    private func shouldShowActivation(_ info: CurrentOrderDisplayInfo) -> Bool {
        // Trailing-stop / stop-limit orders use activation price as the stop trigger.
        if isStopOrderType(info) { return false }
        // TRIGGER children awaiting parent activation, or any non-stop order with an
        // explicit activation condition, get a dedicated chip.
        return true
    }

    private func factChip(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(4)
    }

    // MARK: - Comparison line

    @ViewBuilder
    private func comparisonLine(info: CurrentOrderDisplayInfo) -> some View {
        if !recommendationsAvailable {
            EmptyView()
        } else if let suggestion = comparison?.suggestion {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Suggested")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(suggestion.kind == .sell ? "SELL" : "BUY") \(quantityString(suggestion.quantity)) @ $\(format(suggestion.targetPrice))")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(sideColor(suggestion.kind.side))
                    Text("TS \(format(suggestion.trailPercent))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let est = suggestion.estimatedStopPrice {
                        Text("Est Stop $\(format(est))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("(\(suggestion.sourceLabel))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer(minLength: 0)
                }

                if let comparison = comparison, hasAnyDelta(comparison) {
                    HStack(spacing: 6) {
                        ForEach(deltaLabels(comparison), id: \.self) { label in
                            Text(label)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(3)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.leading, 6)
        } else {
            Text(comparisonMissingLabel(info: info))
                .font(.caption2)
                .italic()
                .foregroundColor(.secondary)
                .padding(.leading, 6)
        }
    }

    private func comparisonMissingLabel(info: CurrentOrderDisplayInfo) -> String {
        switch info.side {
        case .sell:
            return recommendedSellOrders.isEmpty ? "No sell recommendations to compare" : "No matching sell recommendation"
        case .buy:
            return recommendedBuyOrders.isEmpty ? "No buy recommendations to compare" : "No matching buy recommendation"
        case .unknown:
            return "No matching recommendation"
        }
    }

    private func hasAnyDelta(_ comparison: OrderComparisonInfo) -> Bool {
        comparison.qtyDelta != nil
            || comparison.targetDelta != nil
            || comparison.trailDelta != nil
            || comparison.estStopDelta != nil
    }

    private func deltaLabels(_ comparison: OrderComparisonInfo) -> [String] {
        var labels: [String] = []
        if let qty = comparison.qtyDelta {
            labels.append("ΔQty \(signed(qty, format: "%.0f"))")
        }
        if let target = comparison.targetDelta {
            labels.append("ΔTarget \(signed(target, format: "%.2f"))")
        }
        if let trail = comparison.trailDelta {
            labels.append("ΔTrail \(signed(trail, format: "%.2f"))%")
        }
        if let stop = comparison.estStopDelta {
            labels.append("ΔStop \(signed(stop, format: "%.2f"))")
        }
        return labels
    }

    private func signed(_ value: Double, format: String) -> String {
        let prefix = value > 0 ? "+" : ""
        return prefix + String(format: format, value)
    }

    // MARK: - Helpers

    private func sideColor(_ side: CurrentOrderSide) -> Color {
        switch side {
        case .buy: return .blue
        case .sell: return .red
        case .unknown: return .primary
        }
    }

    private func quantityLabel(info: CurrentOrderDisplayInfo) -> String {
        let sign: String
        switch info.positionEffect {
        case .CLOSING:
            sign = "-"
        case .OPENING, .AUTOMATIC, .UNKNOWN, .none:
            sign = info.side == .sell ? "-" : "+"
        }
        return "\(sign)\(quantityString(info.quantity))"
    }

    private func quantityString(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func orderTypeLabel(info: CurrentOrderDisplayInfo) -> String? {
        if let type = info.orderType {
            return formatOrderType(type)
        }
        if info.strategy == .TRIGGER { return "TRSTPLMT" }
        return nil
    }

    private func formatBasis(_ basis: PriceLinkBasis) -> String {
        switch basis {
        case .BID: return "BID"
        case .ASK: return "ASK"
        case .LAST: return "LAST"
        case .MARK: return "MARK"
        case .AVERAGE: return "AVG"
        case .BASE: return "BASE"
        case .TRIGGER: return "TRIG"
        case .ASK_BID: return "ASK/BID"
        case .MANUAL: return "MANUAL"
        }
    }

    private func statusBadge(_ status: ActiveOrderStatus?) -> String? {
        status?.shortDisplayName
    }

    private func statusBadgeBackground(_ status: ActiveOrderStatus?) -> Color {
        guard let status = status else { return Color.secondary.opacity(0.15) }
        switch status {
        case .working: return Color.green.opacity(0.18)
        case .awaitingSellStopCondition, .awaitingBuyStopCondition, .awaitingCondition,
             .awaitingParentOrder, .awaitingReleaseTime:
            return Color.orange.opacity(0.18)
        case .awaitingManualReview, .pendingAcknowledgement, .pendingRecall:
            return Color.yellow.opacity(0.20)
        case .accepted, .pendingActivation, .queued, .new:
            return Color.blue.opacity(0.15)
        }
    }

    // MARK: - Format helpers (kept identical to legacy single-line description for the clipboard summary)

    private func formatOrderType(_ orderType: OrderType) -> String {
        switch orderType {
        case .MARKET: return "MKT"
        case .LIMIT: return "LMT"
        case .STOP: return "STP"
        case .STOP_LIMIT: return "STPLMT"
        case .TRAILING_STOP: return "TRSTP"
        case .TRAILING_STOP_LIMIT: return "TRSTPLMT"
        case .MARKET_ON_CLOSE: return "MOC"
        case .LIMIT_ON_CLOSE: return "LOC"
        default: return orderType.rawValue
        }
    }

    private func formatDuration(_ duration: DurationType) -> String {
        switch duration {
        case .DAY: return "DAY"
        case .GOOD_TILL_CANCEL: return "GTC"
        case .FILL_OR_KILL: return "FOK"
        case .IMMEDIATE_OR_CANCEL: return "IOC"
        case .END_OF_WEEK: return "EOW"
        case .END_OF_MONTH: return "EOM"
        case .NEXT_END_OF_MONTH: return "NEOM"
        case .UNKNOWN: return "UNK"
        }
    }

    private func formatReleaseTime(_ releaseTime: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: releaseTime) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
            return outputFormatter.string(from: date)
        }
        return releaseTime
    }

    // MARK: - Clipboard summary (legacy formatter, used as the copied text)

    private func formatOrderDescription(order: Order) -> String {
        var description = ""
        guard let firstLeg = order.orderLegCollection?.first else {
            return "Unknown Order - No order legs"
        }
        guard let symbol = firstLeg.instrument?.symbol else {
            return "Unknown Order - No symbol"
        }
        guard let instruction = firstLeg.instruction else {
            return "Unknown Order - No instruction"
        }

        let action: String
        switch instruction {
        case .BUY, .BUY_TO_COVER, .BUY_TO_OPEN, .BUY_TO_CLOSE: action = "BUY"
        case .SELL, .SELL_SHORT, .SELL_TO_OPEN, .SELL_TO_CLOSE, .SELL_SHORT_EXEMPT: action = "SELL"
        case .EXCHANGE: action = "EXCHANGE"
        }

        let quantity = order.quantity ?? 0
        let qtyPrefix: String
        switch firstLeg.positionEffect {
        case .CLOSING: qtyPrefix = "-"
        default: qtyPrefix = action == "SELL" ? "-" : "+"
        }
        description += "\(action) \(qtyPrefix)\(Int(quantity)) \(symbol)"

        if let price = order.price {
            description += " @\(String(format: "%.2f", price))"
        }
        if order.orderType == .TRAILING_STOP_LIMIT,
           let basis = order.stopPriceLinkBasis,
           let type = order.stopPriceLinkType,
           let offset = order.stopPriceOffset {
            let basisStr = formatBasis(basis)
            let suffix = type == .PERCENT ? "%" : (type == .TICK ? "T" : "")
            description += " STOP \(basisStr)\(offset >= 0 ? "+" : "")\(String(format: "%.2f", offset))\(suffix)"
        }
        if let stopPrice = order.stopPrice {
            description += " STOP \(String(format: "%.2f", stopPrice))"
        }
        if let orderType = order.orderType {
            description += " \(formatOrderType(orderType))"
        }
        if let duration = order.duration {
            description += " \(formatDuration(duration))"
        }
        if let strategy = order.orderStrategyType {
            if strategy == .OCO { description += " OCO" }
            else if strategy == .TRIGGER { description += " TRG BY" }
        }
        if let orderId = order.orderId {
            description += " #\(orderId)"
        }
        if let cancelTimeDate = order.cancelTime {
            let formatter = ISO8601DateFormatter()
            description += " CANCEL AT \(formatReleaseTime(formatter.string(from: cancelTimeDate)))"
        }
        if let positionEffect = firstLeg.positionEffect {
            switch positionEffect {
            case .OPENING: description += " [TO OPEN]"
            case .CLOSING: description += " [TO CLOSE]"
            case .AUTOMATIC: description += " [AUTO]"
            case .UNKNOWN: break
            }
        }
        return description
    }

    private func copySummary(info: CurrentOrderDisplayInfo) -> String {
        var lines: [String] = [formatOrderDescription(order: order)]
        if let est = info.estimatedStopPrice, info.stopPrice == nil, info.hasTrailingStop {
            lines.append("Est Stop $\(String(format: "%.2f", est))")
        }
        if recommendationsAvailable, let suggestion = comparison?.suggestion {
            let sideStr = suggestion.kind == .sell ? "SELL" : "BUY"
            var sugg = "Suggested: \(sideStr) \(quantityString(suggestion.quantity)) @ $\(format(suggestion.targetPrice)) TS \(format(suggestion.trailPercent))% (\(suggestion.sourceLabel))"
            if let est = suggestion.estimatedStopPrice {
                sugg += " Est Stop $\(format(est))"
            }
            lines.append(sugg)
        }
        return lines.joined(separator: "\n")
    }

    private func copyToClipboard(text: String) {
#if os(visionOS)
        UIPasteboard.general.string = text
#elseif os(iOS)
        UIPasteboard.general.string = text
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
}

#Preview("OrderDetailRow", traits: .landscapeLeft) {
    let aaplLeg = OrderLegCollection(
        instrument: AccountsInstrument(symbol: "AAPL"),
        instruction: .BUY_TO_OPEN,
        positionEffect: .OPENING,
        quantity: 100
    )
    let limitOrder = Order(
        session: nil,
        duration: .GOOD_TILL_CANCEL,
        orderType: .LIMIT,
        quantity: 100,
        price: 150.50,
        orderLegCollection: [aaplLeg],
        orderStrategyType: .SINGLE,
        orderId: 12345,
        status: .working
    )

    let tslaLeg = OrderLegCollection(
        instrument: AccountsInstrument(symbol: "TSLA"),
        instruction: .SELL_TO_CLOSE,
        positionEffect: .CLOSING,
        quantity: 200
    )
    let trailingOrder = Order(
        session: nil,
        duration: .GOOD_TILL_CANCEL,
        orderType: .TRAILING_STOP_LIMIT,
        quantity: 200,
        stopPriceLinkBasis: .ASK,
        stopPriceLinkType: .PERCENT,
        stopPriceOffset: 2.0,
        priceLinkBasis: .MANUAL,
        price: 175.0,
        orderLegCollection: [tslaLeg],
        orderStrategyType: .SINGLE,
        orderId: 12346,
        status: .working
    )

    let mockQuote = Quote(askPrice: 180.0, bidPrice: 179.5, lastPrice: 179.75, mark: 179.75)
    let mockSell = SalesCalcResultsRecord(
        shares: 200, sharesToSell: 200, trailingStop: 2.5,
        target: 176.0, description: "(Top 100) SELL -200 TSLA Target 176.00 TS 2.50%"
    )

    return VStack(spacing: 16) {
        OrderDetailRow(order: limitOrder, groupOrderId: 12345, recommendationsAvailable: false)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

        OrderDetailRow(
            order: trailingOrder,
            groupOrderId: 12346,
            quote: mockQuote,
            lastPriceFallback: 179.75,
            recommendedSellOrders: [mockSell],
            recommendedBuyOrders: [],
            recommendationsAvailable: true
        )
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    .padding()
}
