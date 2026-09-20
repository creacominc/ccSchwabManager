import Foundation

/// Owns transaction history and its pagination state. All values crossing this
/// boundary are immutable and `Sendable`.
actor TransactionHistoryStore {
    struct SliceReservation: Sendable {
        let month: Int
    }

    private struct CacheEntry: Sendable {
        let timestamp: Date
        let transactions: [Transaction]
    }

    private var transactions: [Transaction] = []
    private var filteredTransactions: [String: (sourceCount: Int, transactions: [Transaction])] = [:]
    private var historyCache: [String: CacheEntry] = [:]
    private var monthDelta = 0
    private var fetchedMonthSlices: Set<Int> = []
    private var consecutiveEmptyMonths = 0
    private let cacheTimeout: TimeInterval

    init(cacheTimeout: TimeInterval = 600) {
        self.cacheTimeout = cacheTimeout
    }

    func reset() {
        transactions.removeAll(keepingCapacity: true)
        filteredTransactions.removeAll(keepingCapacity: true)
        historyCache.removeAll(keepingCapacity: true)
        monthDelta = 0
        fetchedMonthSlices.removeAll(keepingCapacity: true)
        consecutiveEmptyMonths = 0
    }

    func reserveNextSlice(upTo limit: Int) -> SliceReservation? {
        var candidate = 1
        while candidate <= limit {
            if fetchedMonthSlices.insert(candidate).inserted {
                monthDelta = max(monthDelta, candidate)
                return SliceReservation(month: candidate)
            }
            candidate += 1
        }
        return nil
    }

    func merge(_ newTransactions: [Transaction]) {
        guard !newTransactions.isEmpty else { return }
        var existingActivityIds = Set(transactions.compactMap(\.activityId))
        transactions.append(contentsOf: newTransactions.filter { transaction in
            guard let activityId = transaction.activityId else { return true }
            return existingActivityIds.insert(activityId).inserted
        })
        filteredTransactions.removeAll(keepingCapacity: true)
    }

    func finishSlice(_ reservation: SliceReservation, merging fetchedTransactions: [Transaction]) -> Int {
        let countBeforeMerge = transactions.count
        merge(fetchedTransactions)
        let addedCount = transactions.count - countBeforeMerge
        consecutiveEmptyMonths = addedCount == 0 ? consecutiveEmptyMonths + 1 : 0
        sortTransactions()
        return addedCount
    }

    func finishInitialLoad(months: Int) {
        monthDelta = months
        if months > 0 {
            fetchedMonthSlices.formUnion(1...months)
        }
        sortTransactions()
    }

    func allTransactions() -> [Transaction] {
        transactions
    }

    func transactions(for symbol: String) -> [Transaction] {
        if let cached = filteredTransactions[symbol], cached.sourceCount == transactions.count {
            return cached.transactions
        }
        let filtered = transactions.filter { transaction in
            transaction.transferItems.contains { $0.instrument?.symbol == symbol }
        }
        filteredTransactions[symbol] = (transactions.count, filtered)
        return filtered
    }

    func loadedMonths() -> Int {
        monthDelta
    }

    func emptyMonthCount() -> Int {
        consecutiveEmptyMonths
    }

    func historyIsExhausted(emptyMonthLimit: Int) -> Bool {
        consecutiveEmptyMonths >= emptyMonthLimit
    }

    func cachedTransactions(for symbol: String) -> [Transaction]? {
        guard let entry = historyCache[symbol] else { return nil }
        guard Date().timeIntervalSince(entry.timestamp) < cacheTimeout else {
            historyCache.removeValue(forKey: symbol)
            return nil
        }
        return entry.transactions
    }

    func cache(_ transactions: [Transaction], for symbol: String) {
        historyCache[symbol] = CacheEntry(timestamp: Date(), transactions: transactions)
    }

    func invalidateCaches(for symbol: String) {
        historyCache.removeValue(forKey: symbol)
        filteredTransactions.removeValue(forKey: symbol)
    }

    private func sortTransactions() {
        transactions.sort {
            let firstDate = $0.tradeDate ?? "0000"
            let secondDate = $1.tradeDate ?? "0000"
            if firstDate != secondDate {
                return firstDate > secondDate
            }
            let firstShares = $0.transferItems.lazy.reduce(0.0) { $0 + ($1.amount ?? 0) }
            let secondShares = $1.transferItems.lazy.reduce(0.0) { $0 + ($1.amount ?? 0) }
            return firstShares < secondShares
        }
    }
}
