import Foundation

/// Serializes reusable data derived from accounts, transactions, and market data.
actor DerivedPositionDataStore {
    private struct TaxLotCacheEntry: Sendable {
        let timestamp: Date
        let records: [SalesCalcPositionsRecord]
    }

    private var latestTradeDates: [String: Date] = [:]
    private var priceHistory: [String: CandleList] = [:]
    private var atrValues: [String: Double] = [:]
    private var taxLots: [String: TaxLotCacheEntry] = [:]
    private let taxLotCacheTimeout: TimeInterval

    init(taxLotCacheTimeout: TimeInterval = 300) {
        self.taxLotCacheTimeout = taxLotCacheTimeout
    }

    func replaceLatestTradeDates(with dates: [String: Date]) {
        latestTradeDates = dates
    }

    func latestTradeDate(for symbol: String) -> Date? {
        latestTradeDates[symbol]
    }

    func priceHistory(for symbol: String) -> CandleList? {
        guard let history = priceHistory[symbol], !(history.empty ?? true) else { return nil }
        return history
    }

    func cachePriceHistory(_ history: CandleList, for symbol: String) {
        priceHistory[symbol] = history
    }

    func atr(for symbol: String) -> Double? {
        atrValues[symbol]
    }

    func cacheATR(_ value: Double, for symbol: String) {
        atrValues[symbol] = value
    }

    func cachedTaxLots(for symbol: String) -> [SalesCalcPositionsRecord]? {
        guard let entry = taxLots[symbol] else { return nil }
        guard Date().timeIntervalSince(entry.timestamp) < taxLotCacheTimeout else {
            taxLots.removeValue(forKey: symbol)
            return nil
        }
        return entry.records
    }

    func cacheTaxLots(_ records: [SalesCalcPositionsRecord], for symbol: String) {
        taxLots[symbol] = TaxLotCacheEntry(timestamp: Date(), records: records)
    }

    func invalidateTaxLots(for symbol: String) {
        taxLots.removeValue(forKey: symbol)
    }

    func clearATR() {
        atrValues.removeAll(keepingCapacity: true)
    }

    func clearPriceHistory() {
        priceHistory.removeAll(keepingCapacity: true)
    }

    func clearAll() {
        latestTradeDates.removeAll(keepingCapacity: true)
        priceHistory.removeAll(keepingCapacity: true)
        atrValues.removeAll(keepingCapacity: true)
        taxLots.removeAll(keepingCapacity: true)
    }
}
