//
//  CurrentOrderDisplayInfo.swift
//  ccSchwabManager
//
//  Display-only helpers that normalize Schwab `Order` data into structured
//  facts (side, quantity, trail percent, estimated stop, etc.) so the
//  Current Orders tab can present and compare them against recommended
//  buy/sell orders.
//

import Foundation

// MARK: - Side

enum CurrentOrderSide {
    case buy
    case sell
    case unknown

    var label: String {
        switch self {
        case .buy: return "BUY"
        case .sell: return "SELL"
        case .unknown: return "?"
        }
    }
}

// MARK: - Current Order Display Info

/// Structured representation of a Schwab `Order` for display in the
/// Current Orders tab. Nothing here mutates the underlying `Order`; this
/// is purely a UI-friendly view of the data already on the order plus a
/// best-effort estimated stop derived from the latest quote.
struct CurrentOrderDisplayInfo: Identifiable {
    let id = UUID()

    let order: Order
    let groupOrderId: Int64?

    let side: CurrentOrderSide
    let symbol: String
    let quantity: Double
    let positionEffect: PositionEffectType?
    let status: ActiveOrderStatus?

    let orderType: OrderType?
    let strategy: OrderStrategyType?

    let limitPrice: Double?
    let priceLinkBasis: PriceLinkBasis?
    let priceLinkType: PriceLinkType?
    let priceOffset: Double?

    let stopPrice: Double?
    let stopPriceLinkBasis: PriceLinkBasis?
    let stopPriceLinkType: PriceLinkType?
    let stopPriceOffset: Double?
    let stopType: StopType?

    /// Stop price derived from the trailing-stop link basis and current
    /// quote, when no fixed `stopPrice` is on the order itself.
    let estimatedStopPrice: Double?

    let activationPrice: Double?
    let duration: DurationType?
    let orderId: Int64?
    let cancelTime: Date?
    let isAwaitingParent: Bool

    /// True when this order carries a percent-based trailing stop
    /// (the most common shape for Schwab Manager-generated orders).
    var hasTrailingStop: Bool {
        guard let linkType = stopPriceLinkType else { return false }
        return linkType == .PERCENT && stopPriceOffset != nil
    }

    /// Trail percent when the stop is link-typed as a percent, else nil.
    var trailPercent: Double? {
        guard stopPriceLinkType == .PERCENT else { return nil }
        return stopPriceOffset
    }
}

// MARK: - Construction From `Order`

extension CurrentOrderDisplayInfo {
    init?(order: Order, groupOrderId: Int64?, quote: Quote?, lastPriceFallback: Double?) {
        guard let firstLeg = order.orderLegCollection?.first else { return nil }
        guard let symbol = firstLeg.instrument?.symbol else { return nil }

        let side: CurrentOrderSide
        if let instruction = firstLeg.instruction {
            switch instruction {
            case .BUY, .BUY_TO_COVER, .BUY_TO_OPEN, .BUY_TO_CLOSE:
                side = .buy
            case .SELL, .SELL_SHORT, .SELL_TO_OPEN, .SELL_TO_CLOSE, .SELL_SHORT_EXEMPT:
                side = .sell
            case .EXCHANGE:
                side = .unknown
            }
        } else {
            side = .unknown
        }

        let quantity = order.quantity ?? firstLeg.quantity ?? 0

        let activeStatus: ActiveOrderStatus?
        if let status = order.status {
            activeStatus = ActiveOrderStatus(from: status, order: order)
        } else {
            activeStatus = nil
        }

        let estimatedStop = CurrentOrderDisplayInfo.estimateStopPrice(
            side: side,
            basis: order.stopPriceLinkBasis,
            linkType: order.stopPriceLinkType,
            offset: order.stopPriceOffset,
            stopType: order.stopType,
            quote: quote,
            lastPriceFallback: lastPriceFallback
        )

        self.order = order
        self.groupOrderId = groupOrderId
        self.side = side
        self.symbol = symbol
        self.quantity = quantity
        self.positionEffect = firstLeg.positionEffect
        self.status = activeStatus
        self.orderType = order.orderType
        self.strategy = order.orderStrategyType
        self.limitPrice = order.price
        self.priceLinkBasis = order.priceLinkBasis
        self.priceLinkType = order.priceLinkType
        self.priceOffset = order.priceOffset
        self.stopPrice = order.stopPrice
        self.stopPriceLinkBasis = order.stopPriceLinkBasis
        self.stopPriceLinkType = order.stopPriceLinkType
        self.stopPriceOffset = order.stopPriceOffset
        self.stopType = order.stopType
        self.estimatedStopPrice = estimatedStop
        self.activationPrice = order.activationPrice
        self.duration = order.duration
        self.orderId = order.orderId
        self.cancelTime = order.cancelTime
        self.isAwaitingParent = order.status == .awaitingParentOrder
    }

    /// Estimate the working stop price for a trailing-stop order from the
    /// latest quote. Schwab does not return the live trailing stop value,
    /// so the best the UI can do is estimate from the link basis and
    /// offset (mirroring how new orders are constructed in
    /// `SchwabClient.createSimplifiedChildOrder`).
    static func estimateStopPrice(
        side: CurrentOrderSide,
        basis: PriceLinkBasis?,
        linkType: PriceLinkType?,
        offset: Double?,
        stopType: StopType?,
        quote: Quote?,
        lastPriceFallback: Double?
    ) -> Double? {
        guard let offset = offset, let linkType = linkType else { return nil }

        let last = quote?.lastPrice ?? lastPriceFallback
        let mark = quote?.mark ?? last
        let bid = quote?.bidPrice
        let ask = quote?.askPrice

        let reference: Double?
        switch basis {
        case .ASK?: reference = ask ?? mark
        case .BID?: reference = bid ?? mark
        case .LAST?: reference = last
        case .MARK?: reference = mark
        case .AVERAGE?:
            if let bid = bid, let ask = ask {
                reference = (bid + ask) / 2.0
            } else {
                reference = mark
            }
        case .ASK_BID?:
            reference = side == .buy ? (ask ?? mark) : (bid ?? mark)
        case .MANUAL?, .BASE?, .TRIGGER?:
            reference = nil
        case .none:
            // Fall back to a side-appropriate reference using `stopType`.
            switch stopType {
            case .ASK?: reference = ask ?? mark
            case .BID?: reference = bid ?? mark
            case .LAST?: reference = last
            case .MARK?, .STANDARD?, .none: reference = mark
            }
        }

        guard let reference = reference else { return nil }

        switch linkType {
        case .PERCENT:
            switch side {
            case .sell: return reference * (1.0 - offset / 100.0)
            case .buy: return reference * (1.0 + offset / 100.0)
            case .unknown: return nil
            }
        case .VALUE:
            switch side {
            case .sell: return reference - offset
            case .buy: return reference + offset
            case .unknown: return nil
            }
        case .TICK:
            return nil
        }
    }
}

// MARK: - Recommendation Display Info

/// Structured representation of a recommended buy/sell order for display
/// alongside the current orders. Built from `SalesCalcResultsRecord` and
/// `BuyOrderRecord` so the comparison table mirrors the OCO tab.
struct RecommendedOrderDisplayInfo: Identifiable {
    enum Kind {
        case sell
        case buy

        var side: CurrentOrderSide {
            switch self {
            case .sell: return .sell
            case .buy: return .buy
            }
        }
    }

    let id = UUID()
    let kind: Kind
    let quantity: Double
    let targetPrice: Double
    let trailPercent: Double
    let estimatedStopPrice: Double?
    /// Free-form label like `Top 100`, `Min ATR`, or `Buy`.
    let sourceLabel: String
    let description: String
}

extension RecommendedOrderDisplayInfo {
    static func from(
        sell: SalesCalcResultsRecord,
        quote: Quote?,
        lastPriceFallback: Double?
    ) -> RecommendedOrderDisplayInfo {
        let estimated = CurrentOrderDisplayInfo.estimateStopPrice(
            side: .sell,
            basis: .ASK,
            linkType: .PERCENT,
            offset: sell.trailingStop,
            stopType: .ASK,
            quote: quote,
            lastPriceFallback: lastPriceFallback
        )
        return RecommendedOrderDisplayInfo(
            kind: .sell,
            quantity: sell.sharesToSell,
            targetPrice: sell.target,
            trailPercent: sell.trailingStop,
            estimatedStopPrice: estimated,
            sourceLabel: extractSourceLabel(from: sell.description, fallback: "Sell"),
            description: sell.description
        )
    }

    static func from(
        buy: BuyOrderRecord,
        quote: Quote?,
        lastPriceFallback: Double?
    ) -> RecommendedOrderDisplayInfo {
        let estimated = CurrentOrderDisplayInfo.estimateStopPrice(
            side: .buy,
            basis: .BID,
            linkType: .PERCENT,
            offset: buy.trailingStop,
            stopType: .BID,
            quote: quote,
            lastPriceFallback: lastPriceFallback
        )
        return RecommendedOrderDisplayInfo(
            kind: .buy,
            quantity: buy.sharesToBuy,
            targetPrice: buy.targetBuyPrice,
            trailPercent: buy.trailingStop,
            estimatedStopPrice: estimated,
            sourceLabel: extractSourceLabel(from: buy.description, fallback: "Buy"),
            description: buy.description
        )
    }

    /// Recommendation descriptions look like "(Top 100) SELL ..." or
    /// "BUY 100 AAPL (10%) ...". Extract the first parenthesized chunk
    /// for use as a compact source label.
    private static func extractSourceLabel(from description: String, fallback: String) -> String {
        guard let openParen = description.firstIndex(of: "(") else { return fallback }
        let afterOpen = description.index(after: openParen)
        guard afterOpen < description.endIndex,
              let closeParen = description[afterOpen...].firstIndex(of: ")") else {
            return fallback
        }
        let raw = description[afterOpen..<closeParen]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

// MARK: - Comparison

/// Pairing of a current order with the closest matching recommendation
/// (if any). All deltas are computed as `recommendation - current` so the
/// UI can render `+`/`-` labels without further math.
struct OrderComparisonInfo {
    let current: CurrentOrderDisplayInfo
    let suggestion: RecommendedOrderDisplayInfo?
    let qtyDelta: Double?
    let targetDelta: Double?
    let trailDelta: Double?
    let estStopDelta: Double?

    init(current: CurrentOrderDisplayInfo, suggestion: RecommendedOrderDisplayInfo?) {
        self.current = current
        self.suggestion = suggestion

        if let suggestion = suggestion {
            self.qtyDelta = suggestion.quantity - current.quantity
            if let limit = current.limitPrice {
                self.targetDelta = suggestion.targetPrice - limit
            } else {
                self.targetDelta = nil
            }
            if let curTrail = current.trailPercent {
                self.trailDelta = suggestion.trailPercent - curTrail
            } else {
                self.trailDelta = nil
            }
            if let curStop = current.stopPrice ?? current.estimatedStopPrice,
               let suggStop = suggestion.estimatedStopPrice {
                self.estStopDelta = suggStop - curStop
            } else {
                self.estStopDelta = nil
            }
        } else {
            self.qtyDelta = nil
            self.targetDelta = nil
            self.trailDelta = nil
            self.estStopDelta = nil
        }
    }
}

enum OrderComparisonMatcher {
    /// Pick the recommendation closest to `current` based on side, then a
    /// normalized blend of target-price difference and quantity difference.
    static func bestMatch(
        for current: CurrentOrderDisplayInfo,
        sells: [RecommendedOrderDisplayInfo],
        buys: [RecommendedOrderDisplayInfo]
    ) -> RecommendedOrderDisplayInfo? {
        let candidates: [RecommendedOrderDisplayInfo]
        switch current.side {
        case .sell: candidates = sells
        case .buy: candidates = buys
        case .unknown: return nil
        }
        guard !candidates.isEmpty else { return nil }

        let curTarget = current.limitPrice ?? current.stopPrice ?? current.estimatedStopPrice ?? 0
        let curQty = current.quantity

        var best: (RecommendedOrderDisplayInfo, Double)?
        for candidate in candidates {
            let priceWeight = max(curTarget, candidate.targetPrice, 1.0)
            let qtyWeight = max(curQty, candidate.quantity, 1.0)
            let priceDiff = curTarget > 0 ? abs(candidate.targetPrice - curTarget) / priceWeight : 0
            let qtyDiff = abs(candidate.quantity - curQty) / qtyWeight
            let score = priceDiff + qtyDiff
            if let cur = best {
                if score < cur.1 { best = (candidate, score) }
            } else {
                best = (candidate, score)
            }
        }
        return best?.0
    }
}
