import Foundation

/// Snapshot of the data required to render the position detail tabs for a security.
struct SecurityDataSnapshot {
    let symbol: String
    let fetchedAt: Date
    let priceHistory: CandleList?
    let transactions: [Transaction]
    let quoteData: QuoteData?
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
}

/// LRU cache that keeps recently loaded security detail data in memory.
final class SecurityDataCacheManager {
    static let shared = SecurityDataCacheManager()

    private let maxCacheSize = 10
    private var cache: [String: SecurityDataSnapshot] = [:]
    private var accessOrder: [String] = []
    private let lock = NSLock()

    private init() {}

    func snapshot(for symbol: String) -> SecurityDataSnapshot? {
        lock.lock()
        defer { lock.unlock() }

        guard let snapshot = cache[symbol] else {
            return nil
        }

        touch(symbol: symbol)
        return snapshot
    }

    func store(_ snapshot: SecurityDataSnapshot) {
        lock.lock()
        defer { lock.unlock() }

        cache[snapshot.symbol] = snapshot
        touch(symbol: snapshot.symbol)
        trimIfNeeded()
    }

    func remove(symbol: String) {
        lock.lock()
        defer { lock.unlock() }

        cache.removeValue(forKey: symbol)
        accessOrder.removeAll { $0 == symbol }
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }

        cache.removeAll(keepingCapacity: false)
        accessOrder.removeAll(keepingCapacity: false)
    }

    private func touch(symbol: String) {
        accessOrder.removeAll { $0 == symbol }
        accessOrder.append(symbol)
    }

    private func trimIfNeeded() {
        while accessOrder.count > maxCacheSize {
            let symbolToRemove = accessOrder.removeFirst()
            cache.removeValue(forKey: symbolToRemove)
        }
    }
}
