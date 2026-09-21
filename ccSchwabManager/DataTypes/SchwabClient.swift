import Foundation
import AuthenticationServices
import Compression
import os.log

// Import the LoadingStateDelegate protocol
@_exported import struct Foundation.URL
@_exported import class Foundation.URLSession
@_exported import class Foundation.JSONDecoder
@_exported import class Foundation.NSError
@_exported import var Foundation.NSLocalizedDescriptionKey

// MARK: - DateFormatter Extension for Schwab API

extension DateFormatter {
    static let schwabDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}

// connection
private let schwabWeb           : String = "https://api.schwabapi.com"

// OAUTH API
private let oauthWeb            : String = "\(schwabWeb)/v1/oauth"
private let authorizationWeb    : String = "\(oauthWeb)/authorize"
private let accessTokenWeb      : String = "\(oauthWeb)/token"

// traderAPI
private let traderAPI           : String = "\(schwabWeb)/trader/v1"
private let accountWeb          : String = "\(traderAPI)/accounts"
private let accountNumbersWeb   : String = "\(accountWeb)/accountNumbers"
private let ordersWeb           : String = "\(traderAPI)/orders"

// marketAPI
private let marketdataAPI       : String = "\(schwabWeb)/marketdata/v1"
private let priceHistoryWeb     : String = "\(marketdataAPI)/pricehistory"

/**
   SchwabClient - interaction with Schwab web site.
    Members:
        - secrets : a Secrets object with the configuration for this connection.
    Methods:
        - getAuthorizationUrl : Executes the completion with the URL for logging into and authenticating the connection.
        - getAccessToken : given the URL returned by the authentication process, extract the code and get the access token.
 */
class SchwabClient
{
    /// Absolute safety cap for per-symbol backfill (see `TransactionHistoryConfig`).
    public var maxMonthDelta: Int { TransactionHistoryConfig.maxBackfillMonths }

    /// Month fetch limit for bulk/startup loads and symbols with complete share history.
    public var initialTransactionHistoryMonths: Int { TransactionHistoryConfig.initialLoadMonths }

    /// Month fetch limit when a symbol's share history still does not reconcile to zero.
    public var extendedTransactionHistoryMonths: Int { TransactionHistoryConfig.maxBackfillMonths }

    private func transactionFetchLimit(for symbol: String?, sourceTransactions: [Transaction]) -> Int {
        guard let symbol else { return initialTransactionHistoryMonths }
        if shareHistoryIsComplete(for: symbol, in: sourceTransactions) {
            return initialTransactionHistoryMonths
        }
        return extendedTransactionHistoryMonths
    }

    public func transactionFetchLimit(for symbol: String?) async -> Int {
        let transactions: [Transaction]
        if let symbol {
            transactions = await transactionHistoryStore.transactions(for: symbol)
        } else {
            transactions = []
        }
        return transactionFetchLimit(for: symbol, sourceTransactions: transactions)
    }

    public func consecutiveEmptyHistoryMonths() async -> Int {
        await transactionHistoryStore.emptyMonthCount()
    }

    public func transactionHistoryExhausted() async -> Bool {
        await transactionHistoryStore.historyIsExhausted(
            emptyMonthLimit: TransactionHistoryConfig.consecutiveEmptyMonthsToStop
        )
    }
    private let requestTimeout : TimeInterval = 30
    static let shared = SchwabClient()
    @Published var showIncompleteDataWarning = false
    private var m_secrets : Secrets
    private let transactionHistoryStore = TransactionHistoryStore()
    private var m_selectedAccountName : String = "All"
    private var m_accounts : [AccountContent] = []
    private var m_refreshTokenTask: Task<Void, Never>?
    private var m_tokenRefreshInFlight: (id: UUID, task: Task<Bool, Never>)?
    private var m_accessTokenExpiration: Date?
    private let accessTokenRefreshLeeway: TimeInterval = 120
    private let derivedPositionDataStore = DerivedPositionDataStore()
    private var m_symbolsWithOrders: [String: [ActiveOrderStatus]] = [:]
    private var m_lastFilteredTaxLotSymbol : String? = nil
    private var m_lastFilteredTransactionSharesAvailableToTrade : Double? = nil
    private var m_lastfilteredTransactionsYears : Int = 0
    private var m_lastFilteredPositionRecords : [SalesCalcPositionsRecord] = []
    private var m_orderList : [Order] = []
    
    // Create a logger for this class
    private let logger = Logger(subsystem: "com.creacom.ccSchwabManager", category: "SchwabClient")
    
    /// Presentation-only loading state. UI ownership is isolated to the main actor;
    /// networking code updates it by explicitly hopping to `MainActor`.
    @MainActor weak var loadingDelegate: LoadingStateDelegate?

    private func recordNetworkRequest(
        operation: String,
        startedAt: Date,
        data: Data,
        response: URLResponse,
        metadata: [String: String] = [:]
    ) async {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        let duration = Date().timeIntervalSince(startedAt)
        var details = metadata
        details["bytes"] = String(data.count)
        details["status"] = String(statusCode)
        await PerformanceBenchmark.shared.recordNetworkRequest(
            operation: operation,
            duration: duration,
            metadata: details
        )
        AppLogger.shared.debug(
            "🌐 \(operation) status=\(statusCode) bytes=\(data.count) duration=\(String(format: "%.3f", duration))s"
        )
    }

    /**
     * dump the contents of this object for debugging.
     */
    func dump() -> String
    {
        var retVal : String = "\n\t   vvvvvvvvvvvvvvv"
        retVal += "\n\t  secrets: \(self.m_secrets.dump())"
        retVal += "\n\t  selectedAccountName: \(self.m_selectedAccountName)"
        for account in self.m_secrets.getAccountNumbers()
        {
            retVal += "\n\t     account: \(account)"
        }
        retVal += "\n\t   ^^^^^^^^^^^^^^^"
        return retVal
    }
    
    // MARK: - Optimized Caching Methods
    private func getCachedTaxLots(for symbol: String) async -> [SalesCalcPositionsRecord]? {
        guard let cached = await derivedPositionDataStore.cachedTaxLots(for: symbol) else { return nil }
        let cachedShareTotal = roundedShareAmount(cached.reduce(0.0) { $0 + $1.quantity })
        let positionShareTotal = roundedShareAmount(getShareCount(symbol: symbol))
        guard abs(cachedShareTotal - positionShareTotal) <= minLotQuantityThreshold else {
            AppLogger.shared.debug("📦 Invalidating stale tax lot cache for \(symbol) (\(cachedShareTotal) cached vs \(positionShareTotal) position shares)")
            await derivedPositionDataStore.invalidateTaxLots(for: symbol)
            return nil
        }
        return cached
    }
    
    private func cacheTaxLots(_ taxLots: [SalesCalcPositionsRecord], for symbol: String) async {
        await derivedPositionDataStore.cacheTaxLots(taxLots, for: symbol)
        AppLogger.shared.debug("📦 Cached \(taxLots.count) tax lots for \(symbol)")
    }
    
    /// Clears per-symbol tax lot, transaction, and filtered caches so recomputation sees newly fetched history.
    public func invalidateSymbolDerivedCaches(symbol: String) async {
        await derivedPositionDataStore.invalidateTaxLots(for: symbol)
        await transactionHistoryStore.invalidateCaches(for: symbol)
        m_lastFilteredTransactionSharesAvailableToTrade = 0.0
        if m_lastFilteredTaxLotSymbol == symbol {
            m_lastFilteredTaxLotSymbol = nil
        }
    }

    public func loadedTransactionHistoryMonths() async -> Int {
        await transactionHistoryStore.loadedMonths()
    }

    public func canFetchMoreTransactionHistory(for symbol: String? = nil) async -> Bool {
        if await transactionHistoryExhausted() {
            return false
        }
        let limit = await transactionFetchLimit(for: symbol)
        return await transactionHistoryStore.loadedMonths() < limit
    }

    /// Why incremental history backfill stopped (nil while backfill can continue).
    public func historyBackfillStopReason(for symbol: String) async -> String? {
        if await hasCompleteShareHistory(for: symbol) {
            return "share history reached zero"
        }
        if await transactionHistoryExhausted() {
            return "no more transaction history (\(await consecutiveEmptyHistoryMonths()) consecutive empty months)"
        }
        if !(await canFetchMoreTransactionHistory(for: symbol)) {
            let loaded = await loadedTransactionHistoryMonths()
            let limit = await transactionFetchLimit(for: symbol)
            return "month safety limit reached (\(loaded)/\(limit))"
        }
        return nil
    }

    @discardableResult
    public func fetchNextTransactionHistoryMonth(for symbol: String? = nil) async -> Bool {
        guard await canFetchMoreTransactionHistory(for: symbol) else { return false }
        // fetchTransactionHistory returns -1 only when no unfetched slice remains within
        // the limit. Any value >= 0 means a slice was consumed (even an empty one), which
        // is real backfill progress — including filling a hole below the high-water mark.
        let added = await fetchTransactionHistory(allowExtendedFor: symbol)
        return added >= 0
    }

    /// Returns true when walking trade history backward reaches zero shares for the current position.
    public func hasCompleteShareHistory(for symbol: String) async -> Bool {
        shareHistoryIsComplete(for: symbol, in: await getTransactionsFor(symbol: symbol))
    }

    private func shareHistoryIsComplete(for symbol: String, in sourceTransactions: [Transaction]) -> Bool {
        let currentShareCount = getShareCount(symbol: symbol)
        if isNearZero(currentShareCount) {
            return true
        }

        let relevantTransactions = tradeRelevantTransactionsForLogic(symbol: symbol, sourceTransactions: sourceTransactions)
        guard !relevantTransactions.isEmpty else {
            return false
        }

        var workingShareCount = currentShareCount

        for transaction in relevantTransactions {
            for transferItem in transaction.transferItems where transferItem.instrument?.symbol == symbol {
                guard let shares = transferItem.amount, !isNearZero(shares) else { continue }
                if shares > 0 {
                    workingShareCount = roundedShareAmount(workingShareCount - shares)
                } else {
                    workingShareCount = roundedShareAmount(workingShareCount + abs(shares))
                }
            }
        }

        return isNearZero(workingShareCount)
    }
    
    // MARK: - Optimized Transaction Fetching
    private func getTransactionsForOptimized(symbol: String) async -> [Transaction] {
        // First check cache
        if let cachedTransactions = await transactionHistoryStore.cachedTransactions(for: symbol) {
            return cachedTransactions
        }
        
        // If not cached, fetch and cache
        let transactions = await getTransactionsFor(symbol: symbol)
        await transactionHistoryStore.cache(transactions, for: symbol)
        return transactions
    }
    
    // MARK: - Smart Tax Lot Calculation
    /// Minimum month slices to pull for tax-lot work (same calendar depth as former quarter counts × 3).
    private func calculateOptimalHistoryMonths(for symbol: String, currentShares: Double) -> Int {
        if currentShares > 1000 {
            return 24
        } else if currentShares > 100 {
            return 18
        } else if currentShares > 10 {
            return 12
        } else {
            return 9
        }
    }

    // MARK: - Transfer pairing (exclude internal ACAT/journal pairs from tax-lot logic)

    private struct TransferPairingKey: Hashable {
        let tradeDate: String
        let absShares: Int64
        let absPrice: Int64
    }

    private struct TradeLogicCandidate {
        let transaction: Transaction
        let shares: Double
        let key: TransferPairingKey
        let accountNumber: String
        let transferLike: Bool
    }

    private func roundedShareAmount(_ value: Double) -> Double {
        ((value * 100000).rounded()) / 100000
    }

    /// Smallest open-lot quantity retained after partial sell matching (Schwab keeps fractional lots).
    private let minLotQuantityThreshold = 0.0001

    private func isRetainedLotQuantity(_ quantity: Double) -> Bool {
        quantity >= minLotQuantityThreshold
    }

    private func roundedKeyComponent(_ value: Double, scale: Double = 100000) -> Int64 {
        Int64((value * scale).rounded())
    }

    private func symbolShareAmount(for transaction: Transaction, symbol: String) -> Double {
        transaction.transferItems.lazy.reduce(0.0) { sum, item in
            guard item.instrument?.symbol == symbol else { return sum }
            return sum + (item.amount ?? 0.0)
        }
    }

    private func symbolPrice(for transaction: Transaction, symbol: String) -> Double {
        transaction.transferItems.first(where: { $0.instrument?.symbol == symbol })?.price ?? 0.0
    }

    private func isTradeTypeForShareLogic(_ transaction: Transaction) -> Bool {
        (transaction.type == .trade) || (transaction.type == .receiveAndDeliver)
    }

    private func isTransferLikeTransaction(_ transaction: Transaction) -> Bool {
        if transaction.activityType == .TRANSFER || transaction.activityType == .UNKNOWN {
            return true
        }
        if transaction.type == .receiveAndDeliver {
            return true
        }
        if abs(transaction.netAmount ?? 0.0) < 0.0001 {
            return true
        }
        let lowerDescription = (transaction.description ?? "").lowercased()
        return lowerDescription.contains("transfer") || lowerDescription.contains("journal")
    }

    /// A pure share-movement journal/transfer (e.g. "Journaled Shares"): no cash changed
    /// hands, or an explicit journal / receive-and-deliver / transfer record. Real trades
    /// always move cash (netAmount != 0), so they are never matched by this.
    private func isJournalShareTransfer(_ transaction: Transaction) -> Bool {
        if transaction.type == .journal || transaction.type == .receiveAndDeliver {
            return true
        }
        if transaction.activityType == .TRANSFER {
            return true
        }
        let lower = (transaction.description ?? "").lowercased()
        if lower.contains("journal") || lower.contains("transfer") {
            return true
        }
        return abs(transaction.netAmount ?? 0.0) < 0.0001
    }

    private func tradeRelevantTransactionsForLogic(symbol: String, sourceTransactions: [Transaction]) -> [Transaction] {
        var candidates: [TradeLogicCandidate] = []
        candidates.reserveCapacity(sourceTransactions.count)

        for transaction in sourceTransactions where isTradeTypeForShareLogic(transaction) {
            let shareAmount = roundedShareAmount(symbolShareAmount(for: transaction, symbol: symbol))
            guard !isNearZero(shareAmount) else { continue }

            let key = TransferPairingKey(
                tradeDate: transaction.tradeDate ?? "",
                absShares: roundedKeyComponent(abs(shareAmount)),
                absPrice: roundedKeyComponent(abs(symbolPrice(for: transaction, symbol: symbol)), scale: 10000)
            )

            candidates.append(
                TradeLogicCandidate(
                    transaction: transaction,
                    shares: shareAmount,
                    key: key,
                    accountNumber: transaction.accountNumber ?? "",
                    transferLike: isTransferLikeTransaction(transaction)
                )
            )
        }

        guard !candidates.isEmpty else { return [] }

        var transferBuckets: [TransferPairingKey: (positive: [TradeLogicCandidate], negative: [TradeLogicCandidate])] = [:]
        for candidate in candidates where candidate.transferLike {
            var bucket = transferBuckets[candidate.key] ?? (positive: [], negative: [])
            if candidate.shares > 0 {
                bucket.positive.append(candidate)
            } else {
                bucket.negative.append(candidate)
            }
            transferBuckets[candidate.key] = bucket
        }

        var pairedTransfers: Set<String> = []
        for (_, bucket) in transferBuckets {
            var positives = bucket.positive
            var negatives = bucket.negative

            while let positive = positives.popLast() {
                guard let negativeIndex = negatives.firstIndex(where: { $0.accountNumber != positive.accountNumber }) else {
                    continue
                }
                let negative = negatives.remove(at: negativeIndex)
                pairedTransfers.insert(positive.transaction.id)
                pairedTransfers.insert(negative.transaction.id)
            }
        }

        if !pairedTransfers.isEmpty {
            AppLogger.shared.debug("↔️ Excluding \(pairedTransfers.count) transfer-side transactions from trade logic for \(symbol)")
        }

        // Same-day, same-quantity Journaled-Shares / transfer pairs: a share movement that
        // matches an opposite-sign record on the same day for the same number of shares.
        // These move shares without a real buy/sell, so both legs are removed entirely
        // (ignores price and account — keyed only on trade date + |shares|).
        var journalDayBuckets: [String: (positive: [TradeLogicCandidate], negative: [TradeLogicCandidate])] = [:]
        for candidate in candidates where isJournalShareTransfer(candidate.transaction) {
            let dayKey = "\(candidate.key.tradeDate)#\(candidate.key.absShares)"
            var bucket = journalDayBuckets[dayKey] ?? (positive: [], negative: [])
            if candidate.shares > 0 {
                bucket.positive.append(candidate)
            } else {
                bucket.negative.append(candidate)
            }
            journalDayBuckets[dayKey] = bucket
        }

        var journalPairedExclusions: Set<String> = []
        for (_, bucket) in journalDayBuckets {
            var negatives = bucket.negative
            for positive in bucket.positive {
                guard !negatives.isEmpty else { break }
                let negative = negatives.removeLast()
                journalPairedExclusions.insert(positive.transaction.id)
                journalPairedExclusions.insert(negative.transaction.id)
            }
        }

        if !journalPairedExclusions.isEmpty {
            AppLogger.shared.debug("↔️ Removing \(journalPairedExclusions.count) same-day same-quantity journal/transfer records for \(symbol)")
        }

        return candidates.compactMap { candidate in
            // Pure same-day journal/transfer pairs are dropped entirely.
            if journalPairedExclusions.contains(candidate.transaction.id) {
                return nil
            }
            if pairedTransfers.contains(candidate.transaction.id) {
                // Zero-cost cross-account transfer journals stay in FIFO; same-day
                // sell-before-buy sort nets them out. Same-account consolidation
                // journals are removed later by removeConsolidationJournalRecords.
                if isNearZero(abs(symbolPrice(for: candidate.transaction, symbol: symbol))) {
                    return candidate.transaction
                }
                return nil
            }
            return candidate.transaction
        }
    }

    /// Same-day $0 receive/deliver journals that sell the entire open buy queue and
    /// immediately rebuy are lot-consolidation no-ops. Excluding both legs preserves
    /// underlying cost lots (e.g. ASML 2026-05-14 ±10.157).
    private func removeConsolidationJournalRecords(_ records: [SalesCalcPositionsRecord]) -> [SalesCalcPositionsRecord] {
        guard records.count > 1 else { return records }

        let sortedIndices = records.indices.sorted { lhs, rhs in
            let a = records[lhs]
            let b = records[rhs]
            return (a.openDate < b.openDate)
                || (a.openDate == b.openDate && a.costPerShare > b.costPerShare)
                || (a.openDate == b.openDate && a.costPerShare == b.costPerShare && a.quantity < b.quantity)
        }

        var skipIndices: Set<Int> = []
        var buyQueue: [SalesCalcPositionsRecord] = []

        for idx in sortedIndices {
            if skipIndices.contains(idx) { continue }
            let record = records[idx]

            if record.quantity > 0 {
                buyQueue.append(record)
                continue
            }

            let buyQueueTotal = roundedShareAmount(buyQueue.reduce(0.0) { $0 + $1.quantity })
            let sellQty = abs(record.quantity)

            if isNearZero(record.costPerShare),
               buyQueueTotal > 0.0001,
               abs(sellQty - buyQueueTotal) < 0.0001,
               let buyIdx = sortedIndices.first(where: { other in
                   !skipIndices.contains(other)
                       && other != idx
                       && records[other].openDate == record.openDate
                       && records[other].quantity > 0
                       && isNearZero(records[other].costPerShare)
                       && abs(records[other].quantity - sellQty) < 0.0001
               }) {
                skipIndices.insert(idx)
                skipIndices.insert(buyIdx)
                AppLogger.shared.debug("↔️ Excluding consolidation journal pair on \(record.openDate): ±\(sellQty) shares at $0")
                buyQueue.removeAll()
                continue
            }

            buyQueue.sort { (0.0 == $0.costPerShare) || ($0.costPerShare > $1.costPerShare) }
            var remaining = sellQty
            while remaining > 0 && !buyQueue.isEmpty {
                var buyRecord = buyQueue.removeFirst()
                let buyQuantity = buyRecord.quantity
                if buyQuantity <= remaining {
                    remaining = roundedShareAmount(remaining - buyQuantity)
                } else {
                    buyRecord.quantity = roundedShareAmount(buyQuantity - remaining)
                    if isRetainedLotQuantity(buyRecord.quantity) {
                        buyQueue.insert(buyRecord, at: 0)
                    }
                    remaining = 0
                }
            }
        }

        return records.enumerated().compactMap { skipIndices.contains($0.offset) ? nil : $0.element }
    }

    private func journalDateKey(from openDate: String) -> String {
        String(openDate.prefix(10))
    }

    /// Stock splits produce ratios close to small whole numbers or their reciprocals.
    /// Transfer-journal remnants (e.g. 0.157 shares) must not be treated as splits.
    private func isPlausibleStockSplitRatio(_ ratio: Double) -> Bool {
        guard ratio > 0 else { return false }
        let commonRatios: [Double] = [
            2, 3, 4, 5, 6, 7, 8, 9, 10, 20,
            1.5, 2.5, 3.5,
            0.5, 1.0 / 3.0, 0.25, 0.2, 0.1
        ]
        return commonRatios.contains { abs(ratio - $0) / $0 < 0.02 }
    }

    /// When a $0 journal sell consumes real lots and a matching $0 buy follows the same day,
    /// inherit the consumed cost basis so journal remnants are not left at $0.
    private func inheritJournalBuyCostBasis(
        _ record: SalesCalcPositionsRecord,
        journalConsumedCostByDate: [String: (quantity: Double, basis: Double)]
    ) -> SalesCalcPositionsRecord {
        guard record.quantity > 0, isNearZero(record.costPerShare) else { return record }

        let dateKey = journalDateKey(from: record.openDate)
        guard let consumed = journalConsumedCostByDate[dateKey], consumed.quantity > 0.0001 else {
            return record
        }

        var updated = record
        let inheritedCost = consumed.basis / consumed.quantity
        updated.costPerShare = inheritedCost
        updated.costBasis = updated.quantity * inheritedCost
        AppLogger.shared.debug("↔️ Inherited journal cost basis on \(record.openDate): \(updated.quantity) shares at $\(inheritedCost)")
        return updated
    }

    private init()
    {
        self.m_secrets = Secrets()
    }


    @MainActor
    func configure(with secrets: inout Secrets) {
        AppLogger.shared.debug("=== configure - scheduling token refresh ===")
        let tokenChanged = secrets.accessToken != m_secrets.accessToken
            || secrets.refreshToken != m_secrets.refreshToken
        self.m_secrets = secrets
        guard tokenChanged || (m_refreshTokenTask == nil && m_tokenRefreshInFlight == nil) else {
            return
        }
        m_refreshTokenTask?.cancel()
        m_refreshTokenTask = nil
        guard !secrets.accessToken.isEmpty, !secrets.refreshToken.isEmpty else { return }
        Task { [weak self] in
            _ = await self?.refreshAccessToken()
        }
    }
    
    public func hasAccounts() -> Bool
    {
        return self.m_accounts.count > 0
    }
    
    public func getAccounts() -> [AccountContent]
    {
        AppLogger.shared.debug( "=== getAccounts: accounts: \(self.m_accounts.count) ===" )
        return self.m_accounts
    }
    
    public func hasSymbols() -> Bool
    {
        AppLogger.shared.debug( "=== hasSymbols: accounts: \(self.m_accounts.count) ===" )
        var symbolCount : Int = 0
        for account in self.m_accounts
        {
            symbolCount += account.securitiesAccount?.positions.count ?? 0
        }
        AppLogger.shared.debug( "=== hasSymbols symbols: \(symbolCount) ===" )
        return (symbolCount > 0)
    }

    private func getShareCount(symbol: String) -> Double {
        AppLogger.shared.debug("=== getShareCount \(symbol) ===")

        var shareCount: Double = 0.0
        
        // Find the position for this symbol
        for account in m_accounts {
            if let positions = account.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        shareCount += ((position.longQuantity ?? 0.0) + (position.shortQuantity ?? 0.0))
                        // break out of the inner loop and continue with accounts.
                        break
                    }
                }
            }
        }
        // AppLogger.shared.debug( "  -- getShareCount: returning \(shareCount) shares for symbol \(symbol)" )
        return shareCount
    }

    private func getAveragePrice(symbol: String) -> Double {
        AppLogger.shared.debug("=== getAveragePrice \(symbol) ===")

        var averagePrice: Double = 0.0
        
        // Find the position for this symbol
        for account in m_accounts {
            if let positions = account.securitiesAccount?.positions {
                for position in positions {
                    if position.instrument?.symbol == symbol {
                        averagePrice = position.averagePrice ?? 0.0
                        AppLogger.shared.debug("  --- Found average price: $\(averagePrice)")
                        return averagePrice
                    }
                }
            }
        }
        
        AppLogger.shared.debug("  --- No position found for symbol \(symbol), returning 0.0")
        return averagePrice
    }

    /**
     * getComputedPriceForTransaction - get the computed price for a transaction
     * 
     * For merged/renamed securities, the original transaction may have a price of 0.00.
     * This function returns the computed cost-per-share from the tax lots if available,
     * otherwise returns the original price from the transaction.
     */
    public func getComputedPriceForTransaction(_ transaction: Transaction, symbol: String) async -> Double {
        guard let transferItem = transaction.transferItems.first(where: { $0.instrument?.symbol == symbol }) else {
            return 0.0
        }

        let originalPrice = transferItem.price ?? 0.0
        if originalPrice > 0.0 {
            return originalPrice
        }

        // Use optimized path + per-symbol cache (computeTaxLots reloads global state and toggles loading UI per call).
        let taxLots = await computeTaxLotsOptimized(symbol: symbol)
        guard !taxLots.isEmpty else {
            return originalPrice
        }

        guard let tradeDate = transaction.tradeDate,
              let resolved = TaxLotPriceLookup.costPerShare(
                taxLots: taxLots,
                tradeDateISO8601: tradeDate,
                transferItemAmount: transferItem.amount ?? 0.0
              ) else {
            return originalPrice
        }
        return resolved
    }

    public func getSecrets() -> Secrets
    {
        return self.m_secrets
    }
    
    public func setSecrets( secrets: inout Secrets )
    {
        //AppLogger.shared.debug( "client setting secrets to: \(secrets.dump())")
        m_secrets = secrets
    }
    
    public func getSelectedAccountName() -> String
    {
        return self.m_selectedAccountName
    }
    
    public func setSelectedAccountName( name: String )
    {
        AppLogger.shared.debug( "setSelectedAccountName to \(name)" )
        self.m_selectedAccountName = name
    }
    
    /**
     * getAuthorizationUrl : Executes the completion with the URL for logging into and authenticating the connection.
     *
     */
    func getAuthorizationUrl(completion: @escaping (Result<URL, ErrorCodes>) -> Void)
    {
        AppLogger.shared.debug( "=== getAuthorizationUrl ===" )
        // provide the URL for authentication.
        let AUTHORIZE_URL : String  = "\(authorizationWeb)" +
            "?client_id=\( self.m_secrets.appId )" +
            "&redirect_uri=\( self.m_secrets.redirectUrl )"
        guard let url = URL( string: AUTHORIZE_URL ) else {
            completion(.failure(.invalidResponse))
            return
        }
        completion( .success( url ) )
        return
    }
    
    /**
     * getAccessToken : given the URL returned by the authentication process, extract the code and get the access token.
     *
     */
    @MainActor
    func getAccessToken() async -> Result<Void, ErrorCodes> {
        // Access Token Request
        AppLogger.shared.debug( "=== getAccessToken ===" )
        //AppLogger.shared.debug("🔍 getAccessToken - Setting loading to TRUE")
        
        let loadingDelegate = self.loadingDelegate
        Task { @MainActor in
            loadingDelegate?.setLoading(true)
        }
        
        let url: URL = URL( string: "\(accessTokenWeb)" )!
        //AppLogger.shared.debug( "accessTokenUrl: \(url)" )
        var accessTokenRequest: URLRequest = URLRequest( url: url )
        // set a 10 second timeout on this request
        accessTokenRequest.timeoutInterval = self.requestTimeout
        accessTokenRequest.httpMethod = "POST"
        // headers
        let authStringUnencoded: String = String("\( self.m_secrets.appId ):\( self.m_secrets.appSecret )")
        let authStringEncoded: String = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        
        accessTokenRequest.setValue( "Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization" )
        accessTokenRequest.setValue( "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type" )
        // body
        let bodyString = "grant_type=authorization_code" +
            "&code=\( self.m_secrets.code )" +
            "&redirect_uri=\( self.m_secrets.redirectUrl )"
        accessTokenRequest.httpBody = bodyString.data(using: .utf8)!
        AppLogger.shared.debug( "Posting access token request:  \(accessTokenRequest)" )
        
        defer {
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: accessTokenRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(.notAuthenticated)
            }
            if( httpResponse.statusCode == 200 )
            {
                if let tokenDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                {
                    self.m_secrets.accessToken = ( tokenDict["access_token"] as? String ?? "" )
                    self.m_secrets.refreshToken = ( tokenDict["refresh_token"] as? String ?? "" )
                    if( !KeychainManager.saveSecrets(secrets: &self.m_secrets) )
                    {
                        AppLogger.shared.error( "Failed to save secrets with access and refresh tokens." )
                        return .failure(.failedToSaveSecrets)
                    }
                    let expiresIn = (tokenDict["expires_in"] as? NSNumber)?.doubleValue ?? 1_800
                    scheduleAccessTokenRefresh(expiresIn: expiresIn)
                    return .success(())
                }
                else
                {
                    AppLogger.shared.error( "Failed to parse token response" )
                    return .failure(.notAuthenticated)
                }
            }
            else
            {
                let errorMsg = "Failed to fetch account numbers. " +
                    "error: \(httpResponse.statusCode). " +
                    "\(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))"
                AppLogger.shared.error(errorMsg)
                return .failure(.notAuthenticated)
            }
        } catch {
            AppLogger.shared.error("getAccessToken failed: \(error.localizedDescription)")
            return .failure(.notAuthenticated)
        }
    }
    
    
    /**
     *  refreshAccessToken - create a thread to get the refresh token every 10 minutes.
     *
     *  A Trader API access token is valid for 30 minutes. A Trader API refresh token is valid for 7 days.
     *
     *  Step 2 was:
     *     curl -X POST https://api.schwabapi.com/v1/oauth/token \
     *     -H 'Authorization: Basic {BASE64_ENCODED_Client_ID:Client_Secret} \
     *     -H 'Content-Type: application/x-www-form-urlencoded' \
     *     -d 'grant_type=authorization_code&code={AUTHORIZATION_CODE_VALUE}&redirect_uri=https://example_url.com/callback_example'
     *
     *   Step 3:
     *       curl -X POST https://api.schwabapi.com/v1/oauth/token \
     *     -H 'Authorization: Basic {BASE64_ENCODED_Client_ID:Client_Secret} \
     *     -H 'Content-Type: application/x-www-form-urlencoded' \
     *     -d 'grant_type=refresh_token&refresh_token={REFRESH_TOKEN_GENERATED_FROM_PRIOR_STEP}
     *
     *  Example - Refresh Token Response
     *   {
     *      "expires_in": 1800, //Number of seconds access_token is valid for
     *      "token_type": "Bearer",
     *      "scope": "api",
     *      "refresh_token": "{REFRESH_TOKEN_HERE}", //Valid for 7 days
     *      "access_token": "{NEW_ACCESS_TOKEN_HERE}",//Valid for 30 minutes
     *      "id_token": "{JWT_HERE}"
     *    }
     *
     *
     */
    @MainActor
    private func refreshAccessToken() async -> Bool {
        if let inFlight = m_tokenRefreshInFlight {
            return await inFlight.task.value
        }

        let refreshID = UUID()
        let task = Task { @MainActor [weak self] in
            guard let self else { return false }
            return await self.performAccessTokenRefresh()
        }
        m_tokenRefreshInFlight = (refreshID, task)
        let succeeded = await task.value
        if m_tokenRefreshInFlight?.id == refreshID {
            m_tokenRefreshInFlight = nil
        }
        return succeeded
    }

    @MainActor
    private func performAccessTokenRefresh() async -> Bool {
        AppLogger.shared.debug("=== refreshAccessToken: Refreshing access token...")

        // if the accessToken or refreshToken are empty, call getAccessToken instead
        if ( self.m_secrets.accessToken == "" ) || ( self.m_secrets.refreshToken == "" ) {
            AppLogger.shared.debug("Access token or refresh token is empty, getting initial access token...")
            switch await getAccessToken() {
            case .success:
                AppLogger.shared.debug("refreshAccessToken - Successfully got access token")
                return true
            case .failure(let error):
                AppLogger.shared.error("refreshAccessToken - Failed to get access token: \(error.localizedDescription)")
                self.m_secrets.code = ""
                return false
            }
        }
        
        //AppLogger.shared.debug("🔍 refreshAccessToken - Setting loading to TRUE")
        Task { @MainActor in
            loadingDelegate?.setLoading(true)
        }
        defer {
            //AppLogger.shared.debug("🔍 refreshAccessToken - Setting loading to FALSE")
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }

        // Access Token Refresh Request
        guard let url = URL(string: "\(accessTokenWeb)") else {
            AppLogger.shared.error("Invalid URL for refreshing access token")
            return false
        }

        var refreshTokenRequest = URLRequest(url: url)
        // set a 10 second timeout on this request
        refreshTokenRequest.timeoutInterval = self.requestTimeout
        refreshTokenRequest.httpMethod = "POST"

        // Headers
        let authStringUnencoded = "\(self.m_secrets.appId):\(self.m_secrets.appSecret)"
        let authStringEncoded = authStringUnencoded.data(using: .utf8)!.base64EncodedString()
        refreshTokenRequest.setValue("Basic \(authStringEncoded)", forHTTPHeaderField: "Authorization")
        refreshTokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Body
        let refreshBodyString = "grant_type=refresh_token" +
            "&refresh_token=\(self.m_secrets.refreshToken)"
        refreshTokenRequest.httpBody = refreshBodyString.data(using: .utf8)!
        
        do {
            let (data, response) = try await URLSession.shared.data(for: refreshTokenRequest)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            guard httpResponse.statusCode == 200 else {
                AppLogger.shared.error("Token refresh failed with status code: \(httpResponse.statusCode)")
                if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                    serviceError.printErrors(prefix: "refreshAccessToken ")
                }
                return false
            }
            guard let tokenDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                AppLogger.shared.error("Failed to parse token response.")
                return false
            }
            m_secrets.accessToken = tokenDict["access_token"] as? String ?? ""
            if let refreshToken = tokenDict["refresh_token"] as? String, !refreshToken.isEmpty {
                m_secrets.refreshToken = refreshToken
            }
            guard KeychainManager.saveSecrets(secrets: &m_secrets) else {
                AppLogger.shared.error("Failed to save refreshed tokens.")
                return false
            }
            let expiresIn = (tokenDict["expires_in"] as? NSNumber)?.doubleValue ?? 1_800
            scheduleAccessTokenRefresh(expiresIn: expiresIn)
            AppLogger.shared.debug("Successfully refreshed and saved access token.")
            return true
        } catch {
            AppLogger.shared.error("Network error during token refresh: \(error.localizedDescription)")
            return false
        }
    }
    
    @MainActor
    private func scheduleAccessTokenRefresh(expiresIn: TimeInterval) {
        let validLifetime = max(expiresIn, 60)
        let delay = max(validLifetime - accessTokenRefreshLeeway, 30)
        m_accessTokenExpiration = Date().addingTimeInterval(validLifetime)
        m_refreshTokenTask?.cancel()
        AppLogger.shared.debug("Scheduling access-token refresh in \(Int(delay)) seconds")
        m_refreshTokenTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            _ = await self?.refreshAccessToken()
        }
    }
    
    // Add cleanup method
    @MainActor
    func cleanup() {
        m_refreshTokenTask?.cancel()
        m_refreshTokenTask = nil
        m_tokenRefreshInFlight?.task.cancel()
        m_tokenRefreshInFlight = nil
        m_accessTokenExpiration = nil
    }
    

    /**
     * fetch account numbers and hashes from schwab
     *
     *
     *[
     {
     "accountNumber": "...767",
     "hashValue": "980170564C529B2EF04942AA...."
     }
     ]
     *
     */
    func fetchAccountNumbers() async
    {
        AppLogger.shared.debug(" === fetchAccountNumbers ===  \(accountNumbersWeb)")
        //AppLogger.shared.debug("🔍 fetchAccountNumbers - Setting loading to TRUE")
        await MainActor.run {
            loadingDelegate?.setLoading(true)
        }
        defer {
            //AppLogger.shared.debug("🔍 fetchAccountNumbers - Setting loading to FALSE")
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }
        
        guard let url = URL(string: accountNumbersWeb) else {
            AppLogger.shared.debug("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // set a 10 second timeout on this request
        request.timeoutInterval = self.requestTimeout

        do
        {
            let (data, response) = try await URLSession.shared.data(for: request)
            let httpResponse = response as! HTTPURLResponse
            if( httpResponse.statusCode != 200 )
            {
                AppLogger.shared.error( "Failed to fetch account numbers.  Status: \(httpResponse.statusCode).  Error: \(httpResponse.description)" )
                return
            }
            // AppLogger.shared.debug( "response: \(response)" )
            //            AppLogger.shared.debug( "data:  \(String(data: data, encoding: .utf8) ?? "Missing data" )" )
            
            let decoder = JSONDecoder()
            let accountNumberHashes = try decoder.decode([AccountNumberHash].self, from: data)
            AppLogger.shared.debug("accountNumberHashes: \(accountNumberHashes.count)")
            
            if !accountNumberHashes.isEmpty
            {
                await MainActor.run
                {
                    self.m_secrets.acountNumberHash = accountNumberHashes
                    if KeychainManager.saveSecrets(secrets: &self.m_secrets)
                    {
                        AppLogger.shared.debug("Save \(self.m_secrets.acountNumberHash.count)  account numbers")
                    }
                    else
                    {
                        AppLogger.shared.error("Error saving account numbers")
                    }
                }
            } else {
                AppLogger.shared.debug("No account numbers returned")
            }
        } catch {
            AppLogger.shared.error("fetchAccountNumbers Error: \(error.localizedDescription)")
            AppLogger.shared.error("   detail:  \(error)")
        }
    }
    
    /**
     * fetchAccounts - get the account numbers and balances.
     */
    func fetchAccounts( retry : Bool = false ) async
    {
        AppLogger.shared.debug("=== fetchAccounts: selected: \(self.m_selectedAccountName) ===")
        //AppLogger.shared.debug("🔍 fetchAccounts - Setting loading to TRUE")
        await MainActor.run {
            loadingDelegate?.setLoading(true)
        }
        defer {
            //AppLogger.shared.debug("🔍 fetchAccounts - Setting loading to FALSE")
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }
        
        var accountUrl = accountWeb
        if self.m_selectedAccountName != "All"
        {
            AppLogger.shared.debug( "fetching for account: \(self.m_selectedAccountName)" )
            accountUrl += "/\(self.m_selectedAccountName)"
        }
        accountUrl += "?fields=positions"
        
        guard let url = URL(string: accountUrl) else {
            AppLogger.shared.debug("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        // set a 10 second timeout on this request
        request.timeoutInterval = self.requestTimeout

        do
        {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.shared.debug("Invalid response type")
                return
            }
            
            if httpResponse.statusCode != 200 {
                // decode data as a ServiceError
                AppLogger.shared.warning( "fetchAccounts: decoding json as ServiceError" )
                let serviceError = try JSONDecoder().decode(ServiceError.self, from: data)
                serviceError.printErrors(prefix: "fetchAccounts ")
                // if the status is 401 and retry is true, call fetchAccounts again after refreshing the access token
                if httpResponse.statusCode == 401 && retry {
                    AppLogger.shared.warning( "=== retrying fetchAccounts after refreshing access token ===" )
                    if await refreshAccessToken() {
                        await fetchAccounts(retry: false)
                    }
                } else {
                    // Log the error for debugging
                    AppLogger.shared.error("fetchAccounts failed with status code: \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        AppLogger.shared.error("Error response: \(errorData)")
                    }
                }
                return
            }
            
            let decoder = JSONDecoder()
            AppLogger.shared.debug( "=== decoding accounts ===" )
            m_accounts  = try decoder.decode([AccountContent].self, from: data)
            AppLogger.shared.debug( "  decoded \(m_accounts.count) accounts" )
            return
        }
        catch
        {
            AppLogger.shared.error("fetchAccounts Error: \(error.localizedDescription)")
            AppLogger.shared.error("   detail:  \(error)")
            return
        }
    }
    
    
    /**
     * fettchPriceHistory  get the history of prices for all securities
     */
    func fetchPriceHistory(symbol: String) async -> CandleList?
    {
        AppLogger.shared.debug("=== fetchPriceHistory \(symbol) ===")

        if let cached = await derivedPositionDataStore.priceHistory(for: symbol) {
            AppLogger.shared.debug( "  fetchPriceHistory - returning cached." )
            return cached
        }

        //AppLogger.shared.debug("🔍 fetchPriceHistory - Setting loading to TRUE")
        Task { @MainActor in
            loadingDelegate?.setLoading(true)
        }
        defer {
            //AppLogger.shared.debug("🔍 fetchPriceHistory - Setting loading to FALSE")
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }
        
        let millisecondsSinceEpoch : Int64 = Int64(Date().timeIntervalSince1970 * 1000)
        // AppLogger.shared.debug date
        AppLogger.shared.debug( "      endDate = \(Date( timeIntervalSince1970: Double(millisecondsSinceEpoch)/1000.0 ) )")

        var priceHistoryUrl = "\(priceHistoryWeb)"
        priceHistoryUrl += "?symbol=\(symbol)"
        priceHistoryUrl += "&periodType=year"
        priceHistoryUrl += "&period=1"
        priceHistoryUrl += "&frequencyType=daily"
//        priceHistoryUrl += "&endDate=\(millisecondsSinceEpoch)"
        //AppLogger.shared.debug( "     priceHistoryUrl: \(priceHistoryUrl)" )
        
        guard let url = URL( string: priceHistoryUrl ) else {
            AppLogger.shared.debug("fetchPriceHistory. Invalid URL for \(symbol)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        // set a 10 second timeout on this request
        request.timeoutInterval = self.requestTimeout

        do {
            let requestStartedAt = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            await recordNetworkRequest(
                operation: "price_history",
                startedAt: requestStartedAt,
                data: data,
                response: response,
                metadata: ["symbol": symbol]
            )
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                AppLogger.shared.error("fetchPriceHistory - Failed to fetch price history for \(symbol). code = \(statusCode)")
            // Try to decode error response for debugging
                if let errorString = String(data: data, encoding: .utf8) {
                    AppLogger.shared.error("fetchPriceHistory - Error response for \(symbol): \(errorString)")
                }
                return nil
            }
            let candleList = try JSONDecoder().decode(CandleList.self, from: data)
            
            // Check if we have valid candles
            let validCandles = candleList.candles.filter { candle in
                guard let high = candle.high, let low = candle.low, let close = candle.close else {
                    return false
                }
                return high > 0 && low > 0 && close > 0 && high >= low
            }
            
            AppLogger.shared.debug("fetchPriceHistory - Fetched \(candleList.candles.count) total candles, \(validCandles.count) valid candles for \(symbol)")
            
            if validCandles.count < 2 {
                AppLogger.shared.warning("fetchPriceHistory - Warning: Insufficient valid candles for ATR calculation for \(symbol)")
            }
            
            await derivedPositionDataStore.cachePriceHistory(candleList, for: symbol)
            return candleList
        } catch {
            AppLogger.shared.error("fetchPriceHistory - Error decoding data for \(symbol): \(error.localizedDescription)")
            AppLogger.shared.error("   detail:  \(error)")
            return nil
        }
    }
    
    /**
     * fetchQuote - get quote data including fundamental information for a symbol
     */
    func fetchQuote(symbol: String) async -> QuoteData? {
        AppLogger.shared.debug("=== fetchQuote \(symbol) ===")
        
        let quoteUrl = "\(marketdataAPI)/\(symbol)/quotes"
        
        guard let url = URL(string: quoteUrl) else {
            AppLogger.shared.debug("fetchQuote. Invalid URL")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.timeoutInterval = self.requestTimeout

        do {
            let requestStartedAt = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            await recordNetworkRequest(
                operation: "quote",
                startedAt: requestStartedAt,
                data: data,
                response: response,
                metadata: ["symbol": symbol]
            )
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                AppLogger.shared.error("fetchQuote - Failed to fetch quote. code = \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            let decoder = JSONDecoder()
            let quoteResponse = try decoder.decode(QuoteResponse.self, from: data)
            
            // Get the quote data for the requested symbol
            guard let quoteData = quoteResponse.quotes[symbol] else {
                AppLogger.shared.debug("fetchQuote - No quote data found for symbol \(symbol)")
                return nil
            }
            
            // AppLogger.shared.debug("fetchQuote - Successfully fetched quote for \(symbol)")
            //
            // // Log detailed fundamental information
            // if let fundamental = quoteData.fundamental {
            //     AppLogger.shared.debug("fetchQuote - Fundamental data for \(symbol):")
            //     AppLogger.shared.debug("  divYield: \(fundamental.divYield ?? 0)")
            //     AppLogger.shared.debug("  divAmount: \(fundamental.divAmount ?? 0)")
            //     AppLogger.shared.debug("  divFreq: \(fundamental.divFreq ?? 0)")
            //     AppLogger.shared.debug("  eps: \(fundamental.eps ?? 0)")
            //     AppLogger.shared.debug("  peRatio: \(fundamental.peRatio ?? 0)")
            //
            //     if let divYield = fundamental.divYield {
            //         AppLogger.shared.debug("fetchQuote - Raw dividend yield for \(symbol): \(divYield)%")
            //         AppLogger.shared.debug("fetchQuote - Dividend yield is already a percentage value")
            //     }
            // } else {
            //     AppLogger.shared.debug("fetchQuote - No fundamental data available for \(symbol)")
            // }
            
            return quoteData
        } catch {
            AppLogger.shared.error("fetchQuote - Error: \(error.localizedDescription)")
            AppLogger.shared.error("   detail: \(error)")
            return nil
        }
    }
    
    /**
     * compute ATR for given symbol
     */
    public func computeATR(symbol: String) async -> Double
    {
        AppLogger.shared.debug("=== computeATR \(symbol) ===")

        if let cachedATR = await derivedPositionDataStore.atr(for: symbol) {
            AppLogger.shared.debug( "  computeATR - returning cached." )
            return cachedATR
        }

        guard let priceHistory = await fetchPriceHistory(symbol: symbol) else {
            AppLogger.shared.error("computeATR Failed to fetch price history for \(symbol).")
            // Don't set the symbol if we failed to get data - this allows retry on next call
            return 0.0
        }

        // Get a local copy of the candles array to prevent race conditions
        let candles = priceHistory.candles
        let candlesCount = candles.count
        
        // Need at least 2 candles to compute ATR
        guard candlesCount > 1 else {
            AppLogger.shared.debug("computeATR: Need at least 2 candles, got \(candlesCount) for \(symbol)")
            // Don't set the symbol if we don't have enough data - this allows retry on next call
            return 0.0
        }
        
        // Validate that we have valid price data
        let validCandles = candles.filter { candle in
            guard let high = candle.high, let low = candle.low, let close = candle.close else {
                return false
            }
            return high > 0 && low > 0 && close > 0 && high >= low
        }
        
        guard validCandles.count > 1 else {
            AppLogger.shared.debug("computeATR: Need at least 2 valid candles, got \(validCandles.count) for \(symbol)")
            // Don't set the symbol if we don't have valid data - this allows retry on next call
            return 0.0
        }
        
        var close : Double  = priceHistory.previousClose ?? 0.0
        var localATR : Double  = 0.0
        
        /*
         * Compute the ATR as the average of the True Range.
         * The True Range is the maximum of absolute values of the High - Low, High - previous Close, and Low - previous Close
         */
        let length : Int  =  min( validCandles.count, 21 )
        let startIndex : Int = validCandles.count - length
        
        // Additional safety check
        guard startIndex >= 0 && startIndex < validCandles.count else {
            AppLogger.shared.debug("computeATR: Invalid startIndex \(startIndex) for validCandlesCount \(validCandles.count) for \(symbol)")
            // Don't set the symbol if we have invalid data - this allows retry on next call
            return 0.0
        }
        
        for indx in 0..<length
        {
            let position = startIndex + indx
            
            // Bounds check for current position - recheck validCandles.count in case array was modified
            guard position >= 0 && position < validCandles.count else {
                AppLogger.shared.debug("computeATR: Position \(position) out of bounds for validCandlesCount \(validCandles.count) for \(symbol)")
                continue
            }
            
            let candle : Candle  = validCandles[position]
            
            // Safe access to previous close
            let prevClose : Double
            if position == 0 {
                prevClose = priceHistory.previousClose ?? 0.0
            } else {
                let prevPosition = position - 1
                guard prevPosition >= 0 && prevPosition < validCandles.count else {
                    AppLogger.shared.debug("computeATR: Previous position \(prevPosition) out of bounds for validCandlesCount \(validCandles.count) for \(symbol)")
                    continue
                }
                prevClose = validCandles[prevPosition].close ?? 0.0
            }
            
            let high : Double  = candle.high ?? 0.0
            let low  : Double  = candle.low ?? 0.0
            let tr : Double = max( abs( high - low ), abs( high - prevClose ), abs( low - prevClose ) )
            close = candle.close ?? 0.0
            localATR = ( (localATR * Double(indx)) + tr ) / Double(indx+1)
        }
        
        // Validate final values before returning
        guard close > 0 && localATR > 0 else {
            AppLogger.shared.debug("computeATR: Invalid final values - close: \(close), ATR: \(localATR) for \(symbol)")
            // Don't set the symbol if we have invalid final values - this allows retry on next call
            return 0.0
        }
        
        // Set the symbol and ATR only if we successfully calculated a valid value
        let atr = localATR * 1.08 / close * 100.0
        await derivedPositionDataStore.cacheATR(atr, for: symbol)
        
        AppLogger.shared.debug("computeATR: Successfully calculated ATR: \(atr)% for \(symbol)")
        
        // return the ATR as a percent.
        return atr
    }
    
    /**
     * clearATRCache - clear the ATR cache to force fresh calculation
     */
    public func clearATRCache() async {
        await derivedPositionDataStore.clearATR()
        AppLogger.shared.debug("computeATR: Cleared ATR cache")
    }
    
    /**
     * clearPriceHistoryCache - clear the price history cache to force fresh data fetch
     */
    public func clearPriceHistoryCache() async {
        await derivedPositionDataStore.clearPriceHistory()
        AppLogger.shared.debug("fetchPriceHistory: Cleared price history cache")
    }
    
    /**
     * clearAllCaches - clear all caches for debugging purposes
     */
    public func clearAllCaches() async {
        await derivedPositionDataStore.clearAll()
        AppLogger.shared.debug("SchwabClient: Cleared all caches")
    }
    
    /**
     * testATRCalculation - test ATR calculation with sample data
     */
    public func testATRCalculation() async {
        AppLogger.shared.debug("=== testATRCalculation ===")
        
        // Create sample candle data
        let sampleCandles = [
            Candle(close: 100.0, high: 105.0, low: 98.0),
            Candle(close: 102.0, high: 107.0, low: 99.0),
            Candle(close: 101.0, high: 103.0, low: 100.0),
            Candle(close: 104.0, high: 106.0, low: 101.0),
            Candle(close: 103.0, high: 105.0, low: 102.0)
        ]
        
        let sampleCandleList = CandleList(
            candles: sampleCandles,
            previousClose: 99.0
        )
        
        await derivedPositionDataStore.cachePriceHistory(sampleCandleList, for: "TEST")
        
        // Test ATR calculation
        let atrValue = await computeATR(symbol: "TEST")
        AppLogger.shared.debug("Test ATR value: \(atrValue)%")
        
        // Clear test data
        await clearAllCaches()
    }
    
    /**
     * fetchTransactionHistory - get the transactions for the last year for this holding.
     *
     * GET /accounts/{accountNumber}/transactions
     * Get all transactions information for a specific account.
     *      All transactions for a specific account. Maximum number of transactions in response is 3000. Maximum date range is 1 year.
     *
     * Parameters     Name    Description
     * accountNumber *     string     The encrypted ID of the account
     * startDate *     string     Specifies that no transactions entered before this time should be returned. Valid ISO-8601 formats are :
     *                    yyyy-MM-dd'T'HH:mm:ss.SSSZ . Example start date is '2024-03-28T21:10:42.000Z'. The 'endDate' must also be set.
     * endDate *     string     Specifies that no transactions entered after this time should be returned.Valid ISO-8601 formats are :
     *                    yyyy-MM-dd'T'HH:mm:ss.SSSZ. Example start date is '2024-05-10T21:10:42.000Z'. The 'startDate' must also be set.
     * symbol     string     It filters all the transaction activities based on the symbol specified. NOTE: If there is any special character in the symbol, please send th encoded value.
     * types *     string     Specifies that only transactions of this status should be returned.
     */
    private func fetchTransactionSliceForMonthDelta(_ monthDelta: Int) async -> [Transaction] {
        guard !m_secrets.acountNumberHash.isEmpty else {
            AppLogger.shared.error("Cannot fetch transaction month \(monthDelta): account-number hashes are unavailable")
            return []
        }

        let endDate = getDateNMonthsAgoStrForEndDate(monthDelta: monthDelta - 1)
        let startDate = getDateNMonthsAgoStr(monthDelta: monthDelta)
        AppLogger.shared.debug("  -- transaction slice month delta: \(monthDelta)")

        return await withTaskGroup(of: [Transaction]?.self) { group in
            for accountNumberHash in self.m_secrets.acountNumberHash {
                for transactionType in [ TransactionType.receiveAndDeliver, TransactionType.trade ] {
                    group.addTask { @Sendable in
                        var transactionHistoryUrl = "\(accountWeb)/\(accountNumberHash.hashValue ?? "N/A")/transactions"
                        transactionHistoryUrl += "?startDate=\(startDate)"
                        transactionHistoryUrl += "&endDate=\(endDate)"
                        transactionHistoryUrl += "&types=\(transactionType.rawValue)"

                        guard let url = URL(string: transactionHistoryUrl) else {
                            AppLogger.shared.debug("fetchTransactionHistory. Invalid URL")
                            return nil
                        }

                        var request = URLRequest(url: url)
                        request.httpMethod = "GET"
                        request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
                        request.setValue("application/json", forHTTPHeaderField: "accept")
                        request.timeoutInterval = self.requestTimeout

                        do {
                            let requestStartedAt = Date()
                            let (data, response) = try await URLSession.shared.data(for: request)
                            await self.recordNetworkRequest(
                                operation: "transactions",
                                startedAt: requestStartedAt,
                                data: data,
                                response: response,
                                metadata: [
                                    "month": String(monthDelta),
                                    "type": transactionType.rawValue
                                ]
                            )

                            guard let httpResponse = response as? HTTPURLResponse else {
                                AppLogger.shared.debug("Invalid response type")
                                return nil
                            }

                            if httpResponse.statusCode != 200 {
                                AppLogger.shared.debug("response code: \(httpResponse.statusCode)  data: \(String(data: data, encoding: .utf8) ?? "N/A")")
                                if let serviceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                    serviceError.printErrors(prefix: "  fetchTransactionHistory ")
                                }
                                return nil
                            }

                            let decoder = JSONDecoder()
                            let transactions = try decoder.decode([Transaction].self, from: data)
                            return transactions
                        } catch {
                            AppLogger.shared.error("fetchTransactionHistory Error: \(error.localizedDescription)")
                            AppLogger.shared.error("   detail:  \(error)")
                            return nil
                        }
                    }
                }
            }

            var newTransactions: [Transaction] = []
            for await transactions in group {
                if let transactions = transactions {
                    newTransactions.append(contentsOf: transactions)
                }
            }
            return newTransactions
        }
    }

    @discardableResult
    public func fetchTransactionHistory(allowExtendedFor symbol: String? = nil) async -> Int {
        let fetchLimit = await transactionFetchLimit(for: symbol)
        let monthDeltaForLogging = await transactionHistoryStore.loadedMonths()
        AppLogger.shared.debug("=== fetchTransactionHistory - monthDelta: \(monthDeltaForLogging)/\(fetchLimit)\(symbol.map { " for \($0)" } ?? "") ===")
        await MainActor.run {
            loadingDelegate?.setLoading(true)
        }
        defer {
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }

        if m_secrets.acountNumberHash.isEmpty {
            await fetchAccountNumbers()
        }
        guard !m_secrets.acountNumberHash.isEmpty else {
            AppLogger.shared.error("Transaction history not advanced: no account-number hashes are available")
            return 0
        }

        // Pick the smallest slice in 1...fetchLimit that has not been fetched yet.
        // This fills any holes left by concurrent advancement of the high-water mark
        // (initial load vs. per-symbol backfill) instead of skipping past them.
        guard let reservation = await transactionHistoryStore.reserveNextSlice(upTo: fetchLimit) else {
            AppLogger.shared.debug(" --- fetchTransactionHistory - fetch limit \(fetchLimit) reached")
            return -1
        }
        let fetchedTransactions = await fetchTransactionSliceForMonthDelta(reservation.month)
        let addedCount = await transactionHistoryStore.finishSlice(reservation, merging: fetchedTransactions)
        AppLogger.shared.debug("Fetched \(addedCount) transactions")
        if addedCount == 0 {
            AppLogger.shared.debug("  -- empty history month \(reservation.month) (\(await consecutiveEmptyHistoryMonths()) consecutive)")
        }
        await setLatestTradeDates()
        await MainActor.run { }
        return addedCount
    }

    public func getTransactionsFor(symbol: String? = nil) async -> [Transaction]
    {
        guard let symbol else {
            AppLogger.shared.debug("getTransactionsFor nil - no symbol provided")
            return await transactionHistoryStore.allTransactions()
        }
        m_lastFilteredTransactionSharesAvailableToTrade = 0.0
        var filtered = await transactionHistoryStore.transactions(for: symbol)
        var monthDeltaForLogging = await transactionHistoryStore.loadedMonths()

        var fetchAttempts = 0
        let maxFetchAttempts = 3

        while extendedTransactionHistoryMonths > monthDeltaForLogging
            && filtered.isEmpty
            && fetchAttempts < maxFetchAttempts {
            AppLogger.shared.debug("     -- getTransactionsFor \(symbol)  - still no records, fetching again (attempt \(fetchAttempts + 1)/\(maxFetchAttempts))")
            fetchAttempts += 1

            _ = await fetchTransactionHistory(allowExtendedFor: symbol)
            filtered = await transactionHistoryStore.transactions(for: symbol)
            monthDeltaForLogging = await transactionHistoryStore.loadedMonths()
            if !filtered.isEmpty {
                AppLogger.shared.debug("  -- getTransactionsFor \(symbol)  - Found \(filtered.count) matching transactions after fetch")
            }
        }

        if fetchAttempts >= maxFetchAttempts && filtered.isEmpty {
            AppLogger.shared.debug("Reached maximum fetch attempts without finding transactions for symbol: \(symbol)")
        }

        AppLogger.shared.debug(" --- getTransactionsFor \(symbol)  returning \(filtered.count) transactions -- ")
        return filtered
    } // getTransactionsFor
    

    


    private func setLatestTradeDates() async
    {
        AppLogger.shared.debug( "--- setLatestTradeDates ---" )
        var latestDates: [String: Date] = [:]

        // create a map of symbols to the most recent trade date
        for transaction in await transactionHistoryStore.allTransactions() {
            for transferItem in transaction.transferItems {
                if let symbol = transferItem.instrument?.symbol {
                    // convert tradeDate string to a Date
                    var dateDte : Date = Date()
                    do {
                        dateDte = try Date( transaction.tradeDate ?? "1970-01-01 00:00:00", strategy: .iso8601.year().month().day()
                            .time(includingFractionalSeconds: false)
                        )
                        // AppLogger.shared.debug( "=== dateStr: \(dateStr), dateDte: \(dateDte) ==" )
                    }
                    catch {
                        AppLogger.shared.error( "Error parsing date: \(error)" )
                        continue
                    }
                    // if the symbol is not in the dictionary, add it with the date.  otherwise compare the date and update only if newer
                    if latestDates[symbol] == nil || dateDte > latestDates[symbol]! {
                        latestDates[symbol] = dateDte
                        // AppLogger.shared.debug( "Added or updated \(symbol) at \(dateDte) - latest date \(latestDateForSymbol[symbol] ?? Date())" )
                    }
                }
            }
        }
        await derivedPositionDataStore.replaceLatestTradeDates(with: latestDates)
        AppLogger.shared.debug( " ! setLatestTradeDates - set dates for \(latestDates.count) symbols !" )
    }
    
    /**
     * getLatestTradeDate( for: String )  get the latest trade date for a given symbol.
     */
    public func getLatestTradeDate(for symbol: String) async -> String
    {
        await derivedPositionDataStore.latestTradeDate(for: symbol)?.dateOnly() ?? "0000"
    }

    /**
     * get number of shares available for trade.  call this after getTransactionsFor
     */
    public func getSharesAvailableForTrade( for symbol: String ) -> Double
    {
        return m_lastFilteredTransactionSharesAvailableToTrade ?? 0.0
    }

    /**
     * Compute shares available for trading using tax lots
     * This should be called after computeTaxLots to avoid circular dependency
     */
    public func computeSharesAvailableForTrading(symbol: String, taxLots: [SalesCalcPositionsRecord]) -> Double {
        AppLogger.shared.debug("=== computeSharesAvailableForTrading for \(symbol) ===")
        AppLogger.shared.debug("  Using provided tax lots for accurate share calculation")
        AppLogger.shared.debug("  Found \(taxLots.count) tax lots for \(symbol)")
        
        // Calculate shares held for over 30 days from tax lots
        var sharesOver30Days: Double = 0.0
        let currentDate = Date()
        
        AppLogger.shared.debug("  === Processing Tax Lots ===")
        for (index, taxLot) in taxLots.enumerated() {
            // Parse tax lot date - format is "2024-12-03 14:34:41"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.timeZone = TimeZone.current
            
            guard let date = dateFormatter.date(from: taxLot.openDate)
            else {
                AppLogger.shared.debug("    Tax lot \(index): Skipping invalid date: \(taxLot.openDate)")
                continue
            }
            
            // Calculate days since tax lot was created
            let daysSinceTaxLot = Calendar.current.dateComponents([.day], from: date, to: currentDate).day ?? 0
            
            if daysSinceTaxLot > 30 {
                sharesOver30Days += taxLot.quantity
                AppLogger.shared.debug("  --- \(symbol) ---  Tax lot \(index): \(taxLot.quantity) shares from \(taxLot.openDate) held for \(daysSinceTaxLot) days (ELIGIBLE)")
            } else {
                AppLogger.shared.debug("  --- \(symbol) ---  Tax lot \(index): \(taxLot.quantity) shares from \(taxLot.openDate) held for \(daysSinceTaxLot) days (NOT ELIGIBLE)")
            }
        }
        
        AppLogger.shared.debug("  Total shares held for over 30 days: \(sharesOver30Days)")
        let finalAvailableShares = max(0.0, sharesOver30Days)
        
        AppLogger.shared.debug("  === Final Calculation ===")
        AppLogger.shared.debug("    Shares over 30 days: \(sharesOver30Days)")
        AppLogger.shared.debug("    Available shares: \(finalAvailableShares)")
        AppLogger.shared.debug("    Total shares owned: \(taxLots.reduce(0.0) { $0 + $1.quantity })")
        
        // Store the result for later retrieval
        m_lastFilteredTransactionSharesAvailableToTrade = finalAvailableShares
        
        return finalAvailableShares
    }
    
    /**
     * fetchOrderHistory
     *
     * /orders
     */
    public func fetchOrderHistory( retry : Bool = false ) async
    {
        AppLogger.shared.info("fetchOrderHistory === fetchOrderHistory  ===")
        // Clear existing orders
        m_orderList.removeAll(keepingCapacity: true)
        // Get date range for the 6 months
        let today: Date = Date()
        let sixMonthsAgo: Date = Calendar.current.date(byAdding: .day, value: -31, to: today) ?? today
        let dateFormatter: DateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        let todayStr: String = dateFormatter.string(from: today)
        let dateSixMonthsAgoStr: String = dateFormatter.string(from: sixMonthsAgo)
        AppLogger.shared.info("fetchOrderHistory 📅 Date range: \(dateSixMonthsAgoStr) to \(todayStr)")

        // Fetch orders for each active status
        await withTaskGroup(of: [Order]?.self) { group in
            for status in OrderStatus.allCases {
                // ignore order status values that are not active orders
                if status == .rejected || status == .canceled || status == .replaced || status == .expired || status == .filled {
                    continue
                }
                AppLogger.shared.info("fetchOrderHistory 🔍 Fetching orders for status: \(status.rawValue)")
                group.addTask { @Sendable in
                    var orderHistoryUrl: String = "\(ordersWeb)"
                    orderHistoryUrl += "?fromEnteredTime=\(dateSixMonthsAgoStr)"
                    orderHistoryUrl += "&toEnteredTime=\(todayStr)"
                    orderHistoryUrl += "&status=\(status.rawValue)"

                    guard let url: URL = URL( string: orderHistoryUrl ) else {
                        AppLogger.shared.error("fetchOrderHistory ❌ fetchOrderHistory. Invalid URL")
                        return nil
                    }

                    var request: URLRequest = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "accept")
                    // set a 10 second timeout on this request
                    request.timeoutInterval = self.requestTimeout

                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let httpResponse: HTTPURLResponse = response as? HTTPURLResponse else {
                            AppLogger.shared.error("fetchOrderHistory ❌ Invalid response type")
                            return nil
                        }
                        if httpResponse.statusCode != 200 {
                            if httpResponse.statusCode == 401 && retry {
                                AppLogger.shared.warning("fetchOrderHistory === retrying fetchOrderHistory after refreshing access token ===")
                                _ = await self.refreshAccessToken()
                                // Note: We can't recursively call async function from within task group
                                // The retry will be handled by the caller
                                return nil
                            }

                            AppLogger.shared.error("fetchOrderHistory ❌ HTTP \(httpResponse.statusCode) for status \(status.rawValue)")
                            if let serviceError: ServiceError = try? JSONDecoder().decode(ServiceError.self, from: data) {
                                // print data as string
                                AppLogger.shared.error("fetchOrderHistory ---- data: \(String(data: data, encoding: .utf8) ?? "N/A")")
                                serviceError.printErrors(prefix: "fetchOrderHistory ")
                            }
                            return nil
                        }

                        // Try to decode, but if it fails, print the raw JSON
                        do {
                            let decoder: JSONDecoder = JSONDecoder()
                            let orders: [Order] = try decoder.decode([Order].self, from: data)
                            AppLogger.shared.info("fetchOrderHistory ✅ Received \(orders.count) orders for status \(status.rawValue)")
                            return orders
                        } catch {
                            AppLogger.shared.error("fetchOrderHistory ❌ Decoding error for status \(status.rawValue): \(error.localizedDescription)")
                            AppLogger.shared.error("fetchOrderHistory   detail:  \(error)")
                            AppLogger.shared.error("fetchOrderHistory ❌ Raw JSON data received:")
                            AppLogger.shared.error("fetchOrderHistory \(String(data: data, encoding: .utf8) ?? "Could not decode as UTF-8")")
                            return nil
                        }
                    } catch {
                        AppLogger.shared.error("fetchOrderHistory ❌ Network error for status \(status.rawValue): \(error.localizedDescription)")
                        return nil
                    }
                } // addTask
            } // for all orderStatus values

            // Collect results from all tasks
            var totalOrdersReceived: Int = 0
            for await orders: [Order]? in group {
                if let orders: [Order] = orders {
                    totalOrdersReceived += orders.count
                    AppLogger.shared.info("fetchOrderHistory 📦 Adding \(orders.count) orders from query (total so far: \(totalOrdersReceived))")
                    m_orderList.append(contentsOf: orders)
                }
            } // append orders
        } // await

        AppLogger.shared.info("fetchOrderHistory 📊 Fetched \(m_orderList.count) orders for all accounts")

        // Deduplicate orders by orderId
        var seenOrderIds: Set<Int64> = []
        var uniqueOrders: [Order] = []
        
        for order in m_orderList {
            if let orderId = order.orderId {
                if !seenOrderIds.contains(orderId) {
                    seenOrderIds.insert(orderId)
                    uniqueOrders.append(order)
                }
            }
        }
        
        m_orderList = uniqueOrders
        
        AppLogger.shared.info("fetchOrderHistory 📊 After deduplication: \(m_orderList.count) unique orders")
        updateSymbolsWithOrders()
    }
    
    private func updateSymbolsWithOrders() {
        AppLogger.shared.info("🔍 === updateSymbolsWithOrders ===")
        // Clear existing symbols with orders
        m_symbolsWithOrders.removeAll(keepingCapacity: true)
        
        AppLogger.shared.info("🔍 Processing \(m_orderList.count) orders to categorize by symbol...")
        
        // update the m_symbolsWithOrders dictionary with each symbol in the orderList with orders that are in awaiting states
        for (_, order) in m_orderList.enumerated() {            
            if let activeStatus: ActiveOrderStatus = ActiveOrderStatus(from: order.status ?? .unknown, order: order) {
                if( ( order.orderStrategyType == .SINGLE )
                    || ( order.orderStrategyType == .TRIGGER ) ) {
                    for (legIndex, leg) in (order.orderLegCollection ?? []).enumerated() {
                        if let symbol = leg.instrument?.symbol {
                            if m_symbolsWithOrders[symbol] == nil {
                                m_symbolsWithOrders[symbol] = []
                            }
                            if !m_symbolsWithOrders[symbol]!.contains(activeStatus) {
                                m_symbolsWithOrders[symbol]!.append(activeStatus)
                            }
                        } else {
                            AppLogger.shared.warning("    ⚠️ Leg \(legIndex + 1): No symbol found")
                        }
                    }
                }
                if ( order.orderStrategyType == .OCO ) {
                    for (_, childOrder) in (order.childOrderStrategies ?? []).enumerated() {
                        if let childActiveStatus = ActiveOrderStatus(from: childOrder.status ?? .unknown, order: childOrder) {
                            for (legIndex, leg) in (childOrder.orderLegCollection ?? []).enumerated() {
                                if let symbol = leg.instrument?.symbol {
                                    if m_symbolsWithOrders[symbol] == nil {
                                        m_symbolsWithOrders[symbol] = []
                                    }
                                    if !m_symbolsWithOrders[symbol]!.contains(childActiveStatus) {
                                        m_symbolsWithOrders[symbol]!.append(childActiveStatus)
                                    }
                                } else {
                                    AppLogger.shared.warning("        ⚠️ Child Leg \(legIndex + 1): No symbol found")
                                }
                            }
                        }
                    }
                }
            }
            else if ( order.status != OrderStatus.canceled &&
                      order.status != OrderStatus.filled &&
                      order.status != OrderStatus.expired &&
                      order.status != OrderStatus.replaced &&
                      order.status != OrderStatus.rejected ){
                AppLogger.shared.warning("  ❌ Order NOT in awaiting states: \(order.status ?? OrderStatus.unknown)")
            } else {
                AppLogger.shared.debug("  ❌ Order is completed/cancelled: \(order.status?.rawValue ?? "nil")")
            }
        }
        AppLogger.shared.info("🔍 === END updateSymbolsWithOrders ===")
    }

    // cancel select order 
    public func cancelOrders( orderIds: [Int64] ) async -> (success: Bool, errorMessage: String?) {
        AppLogger.shared.info("=== cancelOrders ===")
        AppLogger.shared.debug("🎯 Cancelling \(orderIds.count) orders: \(orderIds)")
        AppLogger.shared.debug("📋 Order IDs to cancel: \(orderIds.map { String($0) }.joined(separator: ", "))")
        
        await MainActor.run {
            loadingDelegate?.setLoading(true)
        }
        defer {
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }

        /**
         * Cancel order URL:  /accounts/{accountNumber}/orders/{orderId}
         *
         * accountNumber string    The encrypted ID of the account
         * orderId int64           The ID of the order to cancel
         * 
         * curl -X "DELETE" 
         *  "https://api.schwabapi.com/trader/v1/accounts/<encrypted_account>/orders/<orderId>" 
         *  -H "accept: *" 
         *  -H "Authorization: Bearer I0......@"
         *
         * 
         */
        
        var failedOrders: [Int64] = []
        var errorMessages: [String] = []
        
        // Process each order cancellation in parallel
        await withTaskGroup(of: (orderId: Int64, success: Bool, errorMessage: String?).self) { group in
            for orderId in orderIds {
                group.addTask {
                    // Find the order by ID to get its account number
                    guard let order = self.m_orderList.first(where: { $0.orderId == orderId }) else {
                        return (orderId: orderId, success: false, errorMessage: "Order not found in order list")
                    }
                    
                    guard let orderAccountNumber = order.accountNumber else {
                        return (orderId: orderId, success: false, errorMessage: "Order does not have account number")
                    }
                    
                    // Find the account hash for this order's account number
                    guard let accountNumberHash = self.m_secrets.acountNumberHash.first(where: { 
                        $0.accountNumber == String(orderAccountNumber) 
                    }) else {
                        return (orderId: orderId, success: false, errorMessage: "Account hash not found for account number \(orderAccountNumber)")
                    }
                    
                    guard let hashValue = accountNumberHash.hashValue else {
                        return (orderId: orderId, success: false, errorMessage: "Invalid account hash value")
                    }
                    
                    let cancelOrderUrl = "\(accountWeb)/\(hashValue)/orders/\(orderId)"
                    
                    guard let url = URL(string: cancelOrderUrl) else {
                        return (orderId: orderId, success: false, errorMessage: "Invalid URL for order cancellation")
                    }
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "DELETE"
                    request.setValue("Bearer \(self.m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("*/*", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = self.requestTimeout
                    
                    // Log the request details for verification
                    AppLogger.shared.debug("🔍 DELETE REQUEST VERIFICATION:")
                    AppLogger.shared.debug("  📍 URL: \(cancelOrderUrl)")
                    AppLogger.shared.debug("  🆔 Order ID: \(orderId)")
                    AppLogger.shared.debug("  🔑 Account Hash: \(hashValue)")
                    AppLogger.shared.debug("  🏷️  HTTP Method: \(request.httpMethod ?? "nil")")
                    AppLogger.shared.debug("  📋 Headers:")
                    AppLogger.shared.debug("    Authorization: Bearer \(String(self.m_secrets.accessToken.prefix(20)))...")
                    AppLogger.shared.debug("    Accept: \(request.value(forHTTPHeaderField: "Accept") ?? "nil")")
                    AppLogger.shared.debug("  ⏱️  Timeout: \(request.timeoutInterval) seconds")
                    AppLogger.shared.debug("  📊 Request would delete order \(orderId) from account \(orderAccountNumber) (hash: \(hashValue))")
                    AppLogger.shared.debug("  ✅ Request verification complete - ready to execute DELETE")
                    
                    
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse else {
                            return (orderId: orderId, success: false, errorMessage: "Invalid response type")
                        }
                        
                        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                            AppLogger.shared.warning("✅ Successfully cancelled order \(orderId)")
                            return (orderId: orderId, success: true, errorMessage: nil)
                        } else {
                            // Try to decode error response
                            let errorMessage: String
                            if let responseString = String(data: data, encoding: .utf8) {
                                errorMessage = "HTTP \(httpResponse.statusCode): \(responseString)"
                            } else {
                                errorMessage = "HTTP \(httpResponse.statusCode): Unknown error"
                            }
                            
                            AppLogger.shared.error("❌ Failed to cancel order \(orderId): \(errorMessage)")
                            return (orderId: orderId, success: false, errorMessage: errorMessage)
                        }
                    } catch {
                        let errorMessage = "Network error: \(error.localizedDescription)"
                        AppLogger.shared.error("❌ Error cancelling order \(orderId): \(errorMessage)")
                        return (orderId: orderId, success: false, errorMessage: errorMessage)
                    }
                }
            }
            
            // Collect results
            for await result in group {
                if !result.success {
                    failedOrders.append(result.orderId)
                    if let errorMessage = result.errorMessage {
                        errorMessages.append("Order \(result.orderId): \(errorMessage)")
                    }
                }
            }
        }
        
        // Remove successfully cancelled orders from the order list
        if failedOrders.isEmpty {
            // All orders were cancelled successfully, remove them from the order list
            m_orderList.removeAll { order in
                if let orderId = order.orderId {
                    return orderIds.contains(orderId)
                }
                return false
            }
            
            // Update symbols with orders
            updateSymbolsWithOrders()
            
            AppLogger.shared.warning("✅ SUCCESS: Cancelled all \(orderIds.count) orders successfully")
            AppLogger.shared.warning("📊 Final Results:")
            AppLogger.shared.warning("  🎯 Total orders requested: \(orderIds.count)")
            AppLogger.shared.warning("  ✅ Successfully cancelled: \(orderIds.count)")
            AppLogger.shared.error("  ❌ Failed to cancel: 0")
            return (success: true, errorMessage: nil)
        } else {
            // Some orders failed to cancel
            let errorMessage = "Failed to cancel \(failedOrders.count) orders:\n" + errorMessages.joined(separator: "\n")
            AppLogger.shared.warning("❌ FAILURE: Cancellation failed")
            AppLogger.shared.warning("📊 Final Results:")
            AppLogger.shared.warning("  🎯 Total orders requested: \(orderIds.count)")
            AppLogger.shared.warning("  ✅ Successfully cancelled: \(orderIds.count - failedOrders.count)")
            AppLogger.shared.error("  ❌ Failed to cancel: \(failedOrders.count)")
            AppLogger.shared.warning("  📝 Error details: \(errorMessage)")
            return (success: false, errorMessage: errorMessage)
        }
    }

    // place an order
    public func placeOrder( order: Order ) async -> (success: Bool, errorMessage: String?) {
        AppLogger.shared.debug("📤 [PLACE-ORDER] === placeOrder  ===")
        
        // Get the account hash for the order's account number
        guard let orderAccountNumber = order.accountNumber else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Order does not have account number")
            return (false, "Order does not have account number")
        }
        
        guard let accountNumberHash = m_secrets.acountNumberHash.first(where: { 
            $0.accountNumber == String(orderAccountNumber) 
        }) else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Account hash not found for account number \(orderAccountNumber)")
            return (false, "Account hash not found for account number \(orderAccountNumber)")
        }
        
        guard let hashValue = accountNumberHash.hashValue else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Invalid account hash value")
            return (false, "Invalid account hash value")
        }
        
        let placeOrderUrl = "\(accountWeb)/\(hashValue)/orders"
        
        guard let url = URL(string: placeOrderUrl) else {
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ Invalid URL for order placement")
            return (false, "Invalid URL for order placement")
        }
        
        // Create JSON encoder with proper date formatting
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(DateFormatter.schwabDateFormatter)
        
        do {
            let jsonData = try encoder.encode(order)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            AppLogger.shared.debug("📤 [PLACE-ORDER] 📤 POST REQUEST VERIFICATION:")
            AppLogger.shared.debug("📤 [PLACE-ORDER]   📋 JSON Body:")
            
            // Sanitize the JSON before logging to hide sensitive account information
            let sanitizedJson = JSONSanitizer.sanitizeAccountNumbers(in: jsonString)
            AppLogger.shared.debug("📤 [PLACE-ORDER] \(sanitizedJson)")
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(m_secrets.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("*/*", forHTTPHeaderField: "Accept")
            request.httpBody = jsonData
            request.timeoutInterval = requestTimeout
            
            // Execute the request
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    if let responseString = String(data: data, encoding: .utf8) {
                        AppLogger.shared.debug("📤 [PLACE-ORDER]   📄 Response Body: \(responseString)")
                    }
                    
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        AppLogger.shared.debug("📤 [PLACE-ORDER] ✅ Order placed successfully")
                        // Refresh orders list
                        await fetchOrderHistory()
                        return (true, nil)
                    } else {
                        AppLogger.shared.debug("📤 [PLACE-ORDER] 📥 RESPONSE:")
                        AppLogger.shared.debug("📤 [PLACE-ORDER]   📊 Status Code: \(httpResponse.statusCode)")
                        AppLogger.shared.debug("📤 [PLACE-ORDER]   📋 Headers: \(httpResponse.allHeaderFields)")
                        AppLogger.shared.debug(" [PLACE-ORDER]  \(httpResponse.description)")
                        AppLogger.shared.debug(" [PLACE-ORDER]  \(httpResponse.debugDescription)")

                        // Try to extract error message from response body
                        var errorMessage = "Order placement failed with status code: \(httpResponse.statusCode)"
                        
                        if let responseString = String(data: data, encoding: .utf8) {
                            // Try to parse JSON response for error message
                            if let jsonData = responseString.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let apiMessage = json["message"] as? String {
                                errorMessage = "API Error: \(apiMessage)"
                            } else {
                                // If not JSON, use the raw response
                                errorMessage = "API Error: \(responseString)"
                            }
                        }
                        
                        AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
                        return (false, errorMessage)
                    }
                } else {
                    let errorMessage = "Invalid response type"
                    AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
                    return (false, errorMessage)
                }
            } catch {
                let errorMessage = "Error placing order: \(error.localizedDescription)"
                AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
                return (false, errorMessage)
            }
            
        } catch {
            let errorMessage = "Error encoding order to JSON: \(error.localizedDescription)"
            AppLogger.shared.warning("📤 [PLACE-ORDER] ❌ \(errorMessage)")
            return (false, errorMessage)
        }
    }




    public func hasOrders( symbol: String? = nil ) -> Bool
    {
        guard let symbol = symbol else { return false }
        return m_symbolsWithOrders[symbol]?.isEmpty == false
    }
    
    /**
     * getOrderStatuses - return the active order statuses for a given symbol
     */
    public func getOrderStatuses( symbol: String? = nil ) -> [ActiveOrderStatus]
    {
        guard let symbol = symbol else { return [] }
        return m_symbolsWithOrders[symbol] ?? []
    }
    
    /**
     * getPrimaryOrderStatus - return the highest priority order status for a given symbol
     */
    public func getPrimaryOrderStatus(for symbol: String) -> ActiveOrderStatus? {
        guard let statuses = m_symbolsWithOrders[symbol], !statuses.isEmpty else {
            // AppLogger.shared.debug("🔍 No active orders found for symbol: \(symbol)")
            return nil
        }
        // Sort by priority and return the highest priority status
        let sortedStatuses = statuses.sorted { $0.priority < $1.priority }
        let primaryStatus = sortedStatuses.first
        return primaryStatus
    }
    
    /**
     * getOrderList - return all orders
     */
    public func getOrderList() -> [Order]
    {
        return m_orderList
    }
    
    /**
     * handleMergedRenamedSecurities - handle cases where the earliest transaction has cost = 0
     * 
     * When a security has been merged or renamed, the earliest transaction (which is the last one
     * processed since we work backwards) may have a cost of 0.00. In this case, we need to compute
     * the cost-per-share based on the current share count and the difference between the costs for
     * the later tax lots and the overall cost.
     */
    private func handleMergedRenamedSecurities(_ taxLots: [SalesCalcPositionsRecord], symbol: String) -> [SalesCalcPositionsRecord] {
        AppLogger.shared.debug("=== handleMergedRenamedSecurities - processing \(taxLots.count) tax lots ===")
        
        guard !taxLots.isEmpty else {
            AppLogger.shared.debug("  --- No tax lots to process")
            return taxLots
        }
        
        // Sort by date (oldest first) to find the earliest transaction
        let sortedLots = taxLots.sorted { $0.openDate < $1.openDate }
        let earliestLot = sortedLots.first!
        
        // Check if the earliest transaction has cost = 0 (indicating a merge/rename)
        if earliestLot.costPerShare == 0.0 && earliestLot.quantity > 0 {
            AppLogger.shared.debug("  --- Found potential merged/renamed security: \(earliestLot.openDate), shares: \(earliestLot.quantity), cost: \(earliestLot.costPerShare)")
            
            // Get current share count from position
            let currentShareCount = getShareCount(symbol: symbol)
            AppLogger.shared.debug("  --- \(symbol) --- Current share count: \(currentShareCount)")
            
            // Check if the earliest transaction matches the current share count
            if abs(earliestLot.quantity - currentShareCount) < 0.01 {
                AppLogger.shared.debug("  --- \(symbol) --- Earliest transaction matches current share count - computing cost-per-share")
                
                // Calculate sum of later tax lots costs
                let laterTaxLots = sortedLots.dropFirst()
                let sumOfLaterTaxLotsCosts = laterTaxLots.reduce(0.0) { $0 + $1.costBasis }
                AppLogger.shared.debug("  --- \(symbol) --- Sum of later tax lots costs: $\(sumOfLaterTaxLotsCosts)")
                
                // Get average price from position
                let averagePrice = getAveragePrice(symbol: symbol)
                AppLogger.shared.debug("  --- \(symbol) --- Average price from position: $\(averagePrice)")
                
                // Compute the cost-per-share using the formula from README
                let receivedCostPerShare = ((averagePrice * earliestLot.quantity) - sumOfLaterTaxLotsCosts) / currentShareCount
                AppLogger.shared.debug("  --- \(symbol) --- Computed cost-per-share: $\(receivedCostPerShare)")
                
                // Update the earliest lot with the computed cost
                var updatedLots = taxLots
                if let index = updatedLots.firstIndex(where: { $0.id == earliestLot.id }) {
                    updatedLots[index].costPerShare = receivedCostPerShare
                    updatedLots[index].costBasis = receivedCostPerShare * earliestLot.quantity
                    // Gain/loss will be recalculated at the end
                    updatedLots[index].gainLossDollar = 0.0
                    updatedLots[index].gainLossPct = 0.0
                    
                    AppLogger.shared.debug("  --- Updated earliest lot with computed cost: $\(receivedCostPerShare)")
                }
                
                return updatedLots
            } else {
                AppLogger.shared.debug("  --- Earliest transaction does not match current share count - skipping")
            }
        } else {
            AppLogger.shared.debug("  --- No merged/renamed security detected")
        }
        
        return taxLots
    }

    /**
     * adjustForStockSplits - adjust tax lots for stock splits
     * 
     * When a security experiences a stock split, the additional shares are added to the account
     * and show as a transaction (buy) with a zero price. This function adjusts the prior holdings
     * by the split ratio and removes the zero-cost split transaction.
     */
    private func adjustForStockSplits(_ taxLots: [SalesCalcPositionsRecord], symbol: String) -> [SalesCalcPositionsRecord] {
        AppLogger.shared.debug("=== adjustForStockSplits - processing \(taxLots.count) tax lots ===")
        
        // Sort by date (oldest first)
        let sortedLots = taxLots.sorted { $0.openDate < $1.openDate }
        var adjustedLots: [SalesCalcPositionsRecord] = []
        var i = 0
        
        while i < sortedLots.count {
            let currentLot = sortedLots[i]
            
            // Check if this is a zero-cost transaction (potential split)
            if currentLot.costPerShare == 0.0 && currentLot.quantity > 0 {
                AppLogger.shared.debug("  --- Found potential split transaction: \(currentLot.openDate), shares: \(currentLot.quantity), cost: \(currentLot.costPerShare)")
                
                // Calculate total shares before this split
                let sharesBeforeSplit = adjustedLots.reduce(0.0) { $0 + $1.quantity }
                let sharesFromSplit = currentLot.quantity
                let totalSharesAfterSplit = sharesBeforeSplit + sharesFromSplit
                
                if sharesBeforeSplit > 0 {
                    // Calculate split ratio
                    let splitRatio = totalSharesAfterSplit / sharesBeforeSplit
                    AppLogger.shared.debug("  --- Split calculation:")
                    AppLogger.shared.debug("    Shares before split: \(sharesBeforeSplit)")
                    AppLogger.shared.debug("    Shares from split: \(sharesFromSplit)")
                    AppLogger.shared.debug("    Total shares after split: \(totalSharesAfterSplit)")
                    AppLogger.shared.debug("    Split ratio: \(splitRatio)")

                    guard isPlausibleStockSplitRatio(splitRatio) else {
                        AppLogger.shared.debug("  --- \(symbol) --- Split ratio \(splitRatio) is not plausible; skipping (likely transfer journal)")
                        adjustedLots.append(currentLot)
                        i += 1
                        continue
                    }
                    
                    // Adjust all prior holdings by the split ratio
                    for j in 0..<adjustedLots.count {
                        adjustedLots[j].quantity *= splitRatio
                        adjustedLots[j].costPerShare /= splitRatio
                        adjustedLots[j].marketValue = adjustedLots[j].quantity * adjustedLots[j].price
                        adjustedLots[j].costBasis = adjustedLots[j].quantity * adjustedLots[j].costPerShare
                        // Gain/loss will be recalculated at the end
                        adjustedLots[j].gainLossDollar = 0.0
                        adjustedLots[j].gainLossPct = 0.0
                        
                        adjustedLots[j].splitMultiple *= splitRatio
                        
                        AppLogger.shared.debug("    Adjusted lot \(j): \(adjustedLots[j].openDate), shares: \(adjustedLots[j].quantity), cost: \(adjustedLots[j].costPerShare), basis: \(adjustedLots[j].costBasis), multiple: \(adjustedLots[j].splitMultiple)")
                    }
                    
                    AppLogger.shared.debug("  --- \(symbol) --- Removed split transaction and adjusted \(adjustedLots.count) prior lots")
                } else {
                    AppLogger.shared.debug("  --- \(symbol) --- No prior shares to adjust, skipping split transaction")
                }
                
                // Skip this zero-cost transaction (don't add it to adjustedLots)
                i += 1
                continue
            }
            
            // Add non-split transactions to adjusted lots
            adjustedLots.append(currentLot)
            i += 1
        }
        
        // Sort by highest cost basis (descending)
        adjustedLots.sort { $0.costBasis > $1.costBasis }
        
        AppLogger.shared.debug("=== adjustForStockSplits - returning \(adjustedLots.count) adjusted lots ===")
        return adjustedLots
    }

    /**
     * computeTaxLots - compute a list of tax lots as [SalesCalcPositionsRecord]
     *
     * We cannot get the tax lots from Schwab so we will need to compute it based on the transactions.
     */
    public func computeTaxLots(symbol: String, currentPrice: Double? = nil) async -> [SalesCalcPositionsRecord] {
//        let debug : Bool = true
        // display the busy indicator
//        if debug { AppLogger.shared.debug("🔍 computeTaxLots - Setting loading to TRUE") }
        Task { @MainActor in
            loadingDelegate?.setLoading(true)
        }
        defer {
//            if debug { AppLogger.shared.debug("🔍 computeTaxLots - Setting loading to FALSE") }
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }

        AppLogger.shared.debug("=== computeTaxLots \(symbol) ===")

        // Return cached results if available
        if symbol == m_lastFilteredTaxLotSymbol {
            AppLogger.shared.debug("=== computeTaxLots \(symbol) - returning \(m_lastFilteredPositionRecords.count) cached ===")
            return m_lastFilteredPositionRecords
        }
        m_lastFilteredTaxLotSymbol = symbol

        AppLogger.shared.debug( " --- computeTaxLots() - seeking zero ---" )

        var fetchAttempts = 0
        let maxFetchAttempts = 5  // Limit fetch attempts to prevent infinite loops
        var totalTransactionsFound = 0
        var totalSharesFound = 0.0
        
        // Process transactions until we find zero shares or reach max months of history
        while fetchAttempts < maxFetchAttempts {
            fetchAttempts += 1
            AppLogger.shared.debug("  --- computeTaxLots iteration \(fetchAttempts)/\(maxFetchAttempts) ---")

            // Clear previous results
            m_lastFilteredPositionRecords.removeAll(keepingCapacity: true)

            // Get current share count
            var currentShareCount : Double = getShareCount(symbol: symbol)
            let monthDeltaForLogging = await transactionHistoryStore.loadedMonths()
            AppLogger.shared.debug("  --- computeTaxLots -- \(symbol) -- computeTaxLots() currentShareCount: \(currentShareCount) monthDelta: \(monthDeltaForLogging) --")

            // get last price for this security - use real-time quote data if available, fallback to price history
            let quoteData = currentPrice == nil ? await fetchQuote(symbol: symbol) : nil
            let lastPrice: Double
            if let currentPrice = currentPrice {
                lastPrice = currentPrice
            } else if let quote = quoteData?.quote?.lastPrice {
                lastPrice = quote
            } else if let extended = quoteData?.extended?.lastPrice {
                lastPrice = extended
            } else if let regular = quoteData?.regular?.regularMarketLastPrice {
                lastPrice = regular
            } else {
                lastPrice = await fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0
            }
            showIncompleteDataWarning = true
            // Process all trade transactions - only process again if the number of transactions changes
            AppLogger.shared.debug( "  --- computeTaxLots  - calling getTransactionsFor(symbol: \(symbol))" )
            let transactionsForTaxLots = tradeRelevantTransactionsForLogic(
                symbol: symbol,
                sourceTransactions: await self.getTransactionsFor(symbol: symbol)
            )
            for transaction in transactionsForTaxLots
            {
                totalTransactionsFound += 1
                AppLogger.shared.debug("  --- Processing transaction \(totalTransactionsFound): \(transaction.tradeDate ?? "unknown"), type: \(transaction.type?.rawValue ?? "n/a"), activity: \(transaction.activityType ?? .UNKNOWN)")
                
                for transferItem in transaction.transferItems {
                    // find transferItems where the shares, value, and cost are not 0
                    guard let numberOfShares = transferItem.amount,
                          numberOfShares != 0.0,
                          transferItem.instrument?.symbol == symbol
                    else {
                        AppLogger.shared.debug("   -- \(symbol) --- Skipping transferItem: shares=\(transferItem.amount ?? 0), cost=\(transferItem.price ?? 0), symbol=\(transferItem.instrument?.symbol ?? "nil")")
                        continue
                    }
                    
                    totalSharesFound += numberOfShares
                    AppLogger.shared.debug("   -- \(symbol) --- Found transferItem: \(numberOfShares) shares at $\(transferItem.price ?? 0) on \(transaction.tradeDate ?? "unknown")")
                    
                    // Don't calculate gain/loss here - it will be calculated after adjustments
                    let gainLossDollar = 0.0  // Will be recalculated after adjustments
                    let gainLossPct = 0.0     // Will be recalculated after adjustments
                    
                    // Parse trade date
                    guard let tradeDate : String = try? Date(transaction.tradeDate ?? "1970-01-01T00:00:00+0000",
                                                  strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false)).dateString() else {
                        AppLogger.shared.error( "  -- \(symbol) -- Failed to parse date in trade.  transferItem: \(transferItem.dump())")
                        continue
                    }
                    
                    // Update share count (working backwards)
                    // For BUY transactions (positive shares): subtract the shares we bought
                    // For SELL transactions (negative shares): add back the shares we sold
                    if numberOfShares > 0 {
                        // BUY transaction - subtract shares
                        currentShareCount = ( (currentShareCount - numberOfShares) * 100000 ).rounded()/100000
                    } else {
                        // SELL transaction - add back shares (numberOfShares is negative, so we add abs value)
                        currentShareCount = ( (currentShareCount + abs(numberOfShares)) * 100000 ).rounded()/100000
                    }
                    
                    // Log the balance after each transaction
                    AppLogger.shared.debug("  -- \(symbol) --- Balance after transaction: \(numberOfShares) shares -> currentShareCount: \(currentShareCount)")
                    
                    // Add position record for this transaction
                    m_lastFilteredPositionRecords.append(
                        SalesCalcPositionsRecord(
                            openDate: tradeDate,
                            gainLossPct: gainLossPct,
                            gainLossDollar: gainLossDollar,
                            quantity: numberOfShares,
                            price: lastPrice,
                            costPerShare: transferItem.price!,
                            marketValue: numberOfShares * lastPrice,
                            costBasis: transferItem.price! * numberOfShares,
                            splitMultiple: 1.0  // Initial value, will be adjusted by splits if needed
                        )
                    )

                } // for transferItem

                // Minimal-data walk: stop as soon as the running share count reaches zero.
                if isNearZero( currentShareCount ) {
                    showIncompleteDataWarning = false
                    AppLogger.shared.debug( "  -- \(symbol) -- computeTaxLots:  -- Found zero — stopping backward walk --" )
                    break
                }

            } // for transaction

            // Break if we've found zero shares or reached max months of history
            if ( isNearZero(currentShareCount) ) {
                AppLogger.shared.debug( "  -- \(symbol) -- computeTaxLots:  -- SUCCESS: Zero point found --" )
                showIncompleteDataWarning = false
                break
            } else if ( self.transactionFetchLimit(for: symbol, sourceTransactions: await self.getTransactionsFor(symbol: symbol)) <= monthDeltaForLogging ) {
//                showIncompleteDataWarning = true
                AppLogger.shared.debug( " -- \(symbol) -- Reached max month delta --" )
                AppLogger.shared.debug( " -- \(symbol) -- WARNING: Incomplete data - reached max month delta. Setting showIncompleteDataWarning = true --" )
                break
            }
            else if fetchAttempts >= maxFetchAttempts {
//                showIncompleteDataWarning = true
                AppLogger.shared.debug( " -- Reached max fetch attempts --" )
                AppLogger.shared.debug( " -- WARNING: Incomplete data - reached max fetch attempts. Setting showIncompleteDataWarning = true --" )
                break
            }
            else
            {
                AppLogger.shared.debug( " -- \(symbol) -- Fetching more records (attempt \(fetchAttempts)) --" )
                _ = await self.fetchTransactionHistory(allowExtendedFor: symbol)
            }
            
        }
        
        if fetchAttempts >= maxFetchAttempts {
            AppLogger.shared.debug("Warning: computeTaxLots reached maximum fetch attempts for symbol: \(symbol)")
            // invalid or incomplete warning
        }

        m_lastFilteredPositionRecords = removeConsolidationJournalRecords(m_lastFilteredPositionRecords)
        
        // Sort records by date (oldest first) and cost (highest first for same date)
        // Same-day ties: higher cost first; then sells before buys (negative quantity first)
        m_lastFilteredPositionRecords.sort {
            ($0.openDate < $1.openDate)
            || ($0.openDate == $1.openDate && $0.costPerShare > $1.costPerShare)
            || ($0.openDate == $1.openDate && $0.costPerShare == $1.costPerShare && $0.quantity < $1.quantity)
        }
        
        // Match sells with buys using highest price up to that point
        var remainingRecords: [SalesCalcPositionsRecord] = []
        var buyQueue: [SalesCalcPositionsRecord] = []
        var journalConsumedCostByDate: [String: (quantity: Double, basis: Double)] = [:]
//        if debug {  AppLogger.shared.debug( "  -- computeTaxLots:  -- removing sold shares -- " ) }
        for record : SalesCalcPositionsRecord in m_lastFilteredPositionRecords {
            // collect buy records until you find a sell trade record.
            if record.quantity > 0 {
//                if debug {  AppLogger.shared.debug( "  -- computeTaxLots:     ++++   adding buy to queue: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare)" ) }
                buyQueue.append(inheritJournalBuyCostBasis(record, journalConsumedCostByDate: journalConsumedCostByDate))
            } else {
//                if debug {  AppLogger.shared.debug( "  -- computeTaxLots:     ----   processing sell.  buy queue size: \(buyQueue.count),  sell: \t\(record.openDate), \tquantity: \(record.quantity), \tcostPerShare: \(record.costPerShare),  marketValue: \(record.marketValue)" ) }
                // If this is a .trade record, sort the buy queue by high price.  On trades, the cost-per-share will not be zero
                buyQueue.sort { ( ( 0.0 == $0.costPerShare) || ($0.costPerShare > $1.costPerShare) )}

//                // AppLogger.shared.debug the buy queue for debugging
//                if debug
//                {
//                    // AppLogger.shared.debug each record in the buy queue
//                    for buyRecord in buyQueue
//                    {
//                        AppLogger.shared.debug( "  -- computeTaxLots:         !         buyRecord: \t\(buyRecord.openDate), \t\(buyRecord.quantity), \t\(buyRecord.costPerShare)")
//                    }
//                }


                // Process sell record
                var remainingSellQuantity = abs(record.quantity)

                // Match sell with buys
                while remainingSellQuantity > 0 && !buyQueue.isEmpty {
                    var buyRecord = buyQueue.removeFirst()
                    let buyQuantity = buyRecord.quantity

//                    if debug {  AppLogger.shared.debug( "  -- computeTaxLots:         remainingSellQuantity: \(remainingSellQuantity),  buyQuantity: \(buyQuantity),  queue size: \(buyQueue.count)" ) }
//                    if debug {  AppLogger.shared.debug( "  -- computeTaxLots:         !         buyRecord: \t\(buyRecord.openDate), \t\(buyRecord.quantity), \t\(buyRecord.costPerShare)") }
                    if buyQuantity <= remainingSellQuantity {
                        // Buy record fully matches sell
                        if isNearZero(record.costPerShare) {
                            let dateKey = journalDateKey(from: record.openDate)
                            var consumed = journalConsumedCostByDate[dateKey, default: (0, 0)]
                            consumed.quantity += buyQuantity
                            consumed.basis += buyQuantity * buyRecord.costPerShare
                            journalConsumedCostByDate[dateKey] = consumed
                        }
                        remainingSellQuantity -= buyQuantity
                        //matchedBuys.append(buyRecord)
                    } else {
                        // Buy record partially matches sell - keep remainder if it is a meaningful lot
                        if isRetainedLotQuantity(buyRecord.quantity)
                        {
                            let matchedQuantity = remainingSellQuantity
                            if isNearZero(record.costPerShare) {
                                let dateKey = journalDateKey(from: record.openDate)
                                var consumed = journalConsumedCostByDate[dateKey, default: (0, 0)]
                                consumed.quantity += matchedQuantity
                                consumed.basis += matchedQuantity * buyRecord.costPerShare
                                journalConsumedCostByDate[dateKey] = consumed
                            }
                            buyRecord.quantity -= matchedQuantity
                            buyRecord.marketValue = buyRecord.quantity * buyRecord.price
                            buyRecord.costBasis = buyRecord.quantity * buyRecord.costPerShare
                            buyQueue.insert(buyRecord, at: 0)
                            remainingSellQuantity = 0
                        }
                    }
                }
                
                // If we couldn't match all shares, keep the remaining sell if the buy queue is not empty
                if ( (remainingSellQuantity > 0) && (!buyQueue.isEmpty) ) {
                    var modifiedRecord = record
                    modifiedRecord.quantity = -remainingSellQuantity
                    modifiedRecord.marketValue = remainingSellQuantity * record.price
                    modifiedRecord.costBasis = remainingSellQuantity * record.costPerShare
                    remainingRecords.append(modifiedRecord)
                }
            }
        }

        // Add any remaining buy records
        remainingRecords.append(contentsOf: buyQueue)

        // Sort final records by date
        remainingRecords.sort { $0.openDate < $1.openDate }

        // Handle merged/renamed securities where the earliest transaction has cost = 0
        remainingRecords = handleMergedRenamedSecurities(remainingRecords, symbol: symbol)

        let lotShareTotal = roundedShareAmount(remainingRecords.reduce(0.0) { $0 + $1.quantity })
        let positionShareTotal = getShareCount(symbol: symbol)
        if abs(lotShareTotal - positionShareTotal) > 0.0001 {
            AppLogger.shared.warning("⚠️ \(symbol): tax lots sum to \(lotShareTotal) shares but position is \(positionShareTotal)")
            showIncompleteDataWarning = true
        }

        AppLogger.shared.debug("=== computeTaxLots Summary for \(symbol) ===")
        AppLogger.shared.debug("Total transactions processed: \(totalTransactionsFound)")
        AppLogger.shared.debug("Total shares found in transactions: \(totalSharesFound)")
        AppLogger.shared.debug("Current share count from position: \(getShareCount(symbol: symbol))")
        AppLogger.shared.debug("Final tax lots created: \(remainingRecords.count)")
        for (index, record) in remainingRecords.enumerated() {
            AppLogger.shared.debug("  Lot \(index): \(record.quantity) shares at $\(record.costPerShare) on \(record.openDate)")
        }
        AppLogger.shared.debug("=== End computeTaxLots Summary ===")

        m_lastFilteredPositionRecords = remainingRecords
        
        // Apply stock split adjustments
        m_lastFilteredPositionRecords = adjustForStockSplits(m_lastFilteredPositionRecords, symbol: symbol)
        
        // Calculate gain/loss for each tax lot based on current price and remaining shares
        let fetchedPrice = await fetchPriceHistory(symbol: symbol)?.candles.last?.close
        let finalPrice = currentPrice ?? fetchedPrice ?? 0.0
        
        for i in 0..<m_lastFilteredPositionRecords.count {
            let lot = m_lastFilteredPositionRecords[i]
            let remainingShares = lot.quantity
            let costPerShare = lot.costPerShare
            let costBasis = remainingShares * costPerShare
            let marketValue = remainingShares * finalPrice
            let gainLossDollar = marketValue - costBasis
            let gainLossPct = costBasis != 0 ? ((finalPrice - costPerShare) / costPerShare) * 100.0 : 0.0
            
            m_lastFilteredPositionRecords[i].gainLossDollar = gainLossDollar
            m_lastFilteredPositionRecords[i].gainLossPct = gainLossPct
            m_lastFilteredPositionRecords[i].marketValue = marketValue
            m_lastFilteredPositionRecords[i].costBasis = costBasis
            m_lastFilteredPositionRecords[i].price = finalPrice
        }
        
//        if debug { AppLogger.shared.debug("  -- computeTaxLots: returning \(m_lastFilteredPositionRecords.count) records for symbol \(symbol)") }
        return m_lastFilteredPositionRecords
    } // computeTaxLots
    
    // Add loading state handling to other network methods
    func fetchData<T: Decodable>(from url: URL) async throws -> T {
        await MainActor.run {
            loadingDelegate?.setLoading(true)
        }
        defer {
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    private func isNearZero(_ value: Double) -> Bool {
        return abs(value) < 0.0001
    }

    /**
     * fetchTransactionHistoryReduced - initial month slices for faster display (default 12 ≈ former 4×3-month chunks).
     * Loads up to three months in parallel per wave, then sorts, updates trade dates, and runs `onBatchOnMainActor` on the main actor (if provided) so the GUI can refresh.
     */
    public func fetchTransactionHistoryReduced(
        months: Int = 12,
        parallelMonths: Int = 3,
        onBatchOnMainActor: (@MainActor () async -> Void)? = nil
    ) async {
        AppLogger.shared.debug("=== fetchTransactionHistoryReduced - months: \(months) ===")
        await MainActor.run {
            loadingDelegate?.setLoading(true)
        }
        defer {
            Task { @MainActor in
                loadingDelegate?.setLoading(false)
            }
        }

        // Transaction endpoints require encrypted account identifiers. A restored
        // credential payload may contain valid tokens without cached identifiers,
        // so obtain them before resetting or advancing the history cursor.
        if m_secrets.acountNumberHash.isEmpty {
            AppLogger.shared.debug("Transaction history requires account-number hashes; fetching them first")
            await fetchAccountNumbers()
        }
        guard !m_secrets.acountNumberHash.isEmpty else {
            AppLogger.shared.error("Transaction history not started: no account-number hashes are available")
            return
        }

        await transactionHistoryStore.reset()
        let parallelMonths = max(1, parallelMonths)

        var batchStart = 0
        while batchStart < months {
            let batchEnd = min(batchStart + parallelMonths, months)
            await withTaskGroup(of: [Transaction].self) { group in
                for monthIndex in (batchStart + 1)...batchEnd {
                    group.addTask {
                        await self.fetchTransactionSliceForMonthDelta(monthIndex)
                    }
                }
                for await transactions in group {
                    await transactionHistoryStore.merge(transactions)
                }
            }
            await transactionHistoryStore.finishInitialLoad(months: batchEnd)
            await setLatestTradeDates()
            await onBatchOnMainActor?()

            batchStart = batchEnd
        }

        await transactionHistoryStore.finishInitialLoad(months: months)
        AppLogger.shared.debug("Fetched \((await transactionHistoryStore.allTransactions()).count) transactions in \(months) months")
    }


    // MARK: - Public Debug Methods
    
    @MainActor
    var isRefreshTokenRunning: Bool {
        m_refreshTokenTask != nil || m_tokenRefreshInFlight != nil
    }
    
    @MainActor var isLoading: Bool {
        if let loadingState = loadingDelegate as? LoadingState {
            return loadingState.isLoading
        }
        return false
    }

    // MARK: - OCO Order Creation Methods
    
    /**
     * Create an OCO order from selected buy and sell orders
       [OCO-SUBMIT] JSON preview : {
       "enteredTime" : "2025-07-26T13:45:59Z",
       "editable" : false,
       "cancelable" : true,
       "releaseTime" : "2025-07-27T13:30:00Z",
       "status" : "AWAITING_PARENT_ORDER",
       "orderStrategyType" : "OCO",
       "accountNumber" : 00000767,
       "childOrderStrategies" : [
         {
           "remainingQuantity" : 37,
           "priceLinkType" : "PERCENT",
           "releaseTime" : "2025-07-27T13:30:00Z",
           "stopType" : "BID",
           "cancelable" : true,
           "requestedDestination" : "AUTO",
           "priceOffset" : 0.02,
           "quantity" : 37,
           "filledQuantity" : 0,
           "priceLinkBasis" : "LAST",
           "enteredTime" : "2025-07-27T13:30:00Z",
           "destinationLinkName" : "AutoRoute",
           "orderLegCollection" : [
             {
               "instruction" : "BUY",
               "orderLegType" : "EQUITY",
               "positionEffect" : "OPENING",
               "instrument" : {
                 "assetType" : "EQUITY",
                 "symbol" : "PBI"
               },
               "legId" : 1,
               "quantity" : 37
             }
           ],
           "editable" : false,
           "accountNumber" : 00000767,
           "orderStrategyType" : "SINGLE",
           "orderId" : 0,
           "status" : "AWAITING_RELEASE_TIME",
           "tag" : "API_TOS:CHART"
         }
       ]
     }
     */
    public func createOrder(
        symbol: String,
        accountNumber: Int64,
        selectedOrders: [(String, Any)],
        releaseTime: String
    ) async -> Order? {
        AppLogger.shared.debug("=== createOrder ===")
        AppLogger.shared.debug("Symbol: \(symbol)")
        AppLogger.shared.debug("Selected Orders Count: \(selectedOrders.count)")
        AppLogger.shared.debug("Release Time: \(releaseTime)")
        
        // Get the actual current market price for the symbol
        let currentPrice: Double
        let quoteData = await fetchQuote(symbol: symbol)
        if let quote = quoteData?.quote?.lastPrice {
            currentPrice = quote
            AppLogger.shared.debug("📊 Using real-time quote price: $\(currentPrice)")
        } else if let extended = quoteData?.extended?.lastPrice {
            currentPrice = extended
            AppLogger.shared.debug("📊 Using extended hours quote price: $\(currentPrice)")
        } else if let regular = quoteData?.regular?.regularMarketLastPrice {
            currentPrice = regular
            AppLogger.shared.debug("📊 Using regular market quote price: $\(currentPrice)")
        } else {
            // Fallback to a reasonable default if no quote data available
            currentPrice = 50.0
            AppLogger.shared.debug("⚠️ No quote data available, using fallback current price: $\(currentPrice)")
        }
        
        // If there's only one order, return it directly without OCO wrapper
        if selectedOrders.count == 1 {
            AppLogger.shared.debug("📝 Single order detected - creating direct order without OCO wrapper")
            
            let (orderType, order) = selectedOrders[0]
            if let singleOrder = createSimplifiedChildOrder(
                symbol: symbol,
                accountNumber: accountNumber,
                orderType: orderType,
                order: order,
                legId: 1,
                currentPrice: currentPrice
            ) {
                AppLogger.shared.debug("✅ Created single order directly")
                return singleOrder
            } else {
                AppLogger.shared.error("❌ Failed to create single order")
                return nil
            }
        }
        
        // For multiple orders, create OCO structure
        AppLogger.shared.debug("📝 Multiple orders detected - creating OCO structure")
        
        // Create child order strategies based on the working sample_order7.py pattern
        var childOrderStrategies: [Order] = []
        
        for (index, (orderType, order)) in selectedOrders.enumerated() {
            // Use the same current market price for all orders to ensure consistency
            AppLogger.shared.debug("📊 Order \(index + 1) (\(orderType)): Using current market price: $\(currentPrice)")
            
            if let childOrder = createSimplifiedChildOrder(
                symbol: symbol,
                accountNumber: accountNumber,
                orderType: orderType,
                order: order,
                legId: index + 1,
                currentPrice: currentPrice
            ) {
                childOrderStrategies.append(childOrder)
                AppLogger.shared.debug("✅ Created simplified child order \(index + 1): \(orderType)")
            } else {
                AppLogger.shared.error("❌ Failed to create simplified child order \(index + 1): \(orderType)")
            }
        }
        
        guard !childOrderStrategies.isEmpty else {
            AppLogger.shared.warning("❌ No valid child orders created")
            return nil
        }
        
        // If any selected BUY order prefers DAY duration, force all child orders to use DAY for consistency
        let forceDayDuration: Bool = selectedOrders.contains { (orderType, order) in
            if orderType == "BUY", let buy = order as? BuyOrderRecord { return buy.preferDayDuration }
            return false
        }

        if forceDayDuration {
            for child in childOrderStrategies {
                child.duration = .DAY
            }
        }

        // Create the parent OCO order (simplified - no timing constraints)
        let ocoOrder = Order(
            orderStrategyType: .OCO,
            accountNumber: accountNumber,
            childOrderStrategies: childOrderStrategies,
            statusDescription: forceDayDuration ? "Simplified OCO order (DAY)" : "Simplified OCO order"
        )
        
        AppLogger.shared.debug("✅ Created simplified OCO order with \(childOrderStrategies.count) child orders")
        return ocoOrder
    }
    
    /**
     * Create a simplified child order that matches the working sample_order7.py pattern
     */
    private func createSimplifiedChildOrder(
        symbol: String,
        accountNumber: Int64,
        orderType: String,
        order: Any,
        legId: Int,
        currentPrice: Double
    ) -> Order? {
        
        // Create the instrument
        let instrument = AccountsInstrument(
            assetType: .EQUITY,
            symbol: symbol
        )
        
        if orderType == "SELL" {
            guard let sellOrder = order as? SalesCalcResultsRecord else {
                AppLogger.shared.warning("❌ Invalid sell order type")
                return nil
            }
            
            AppLogger.shared.debug("=== createSimplifiedChildOrder:  Creating simplified SELL order:")
            AppLogger.shared.debug("  Shares: \(sellOrder.sharesToSell)")
            AppLogger.shared.debug("  Target: \(sellOrder.target)")
            AppLogger.shared.debug("  Entry: \(sellOrder.entry)")
            AppLogger.shared.debug("  Cancel: \(sellOrder.cancel)")
            
            // Create the order leg collection for SELL
            // Round down fractional shares for sell orders since quantity cannot be fractional
            let roundedQuantity = floor(sellOrder.sharesToSell)
            
            // Log if rounding was necessary
            if roundedQuantity != sellOrder.sharesToSell {
                AppLogger.shared.info("📊 SELL Order: Rounded quantity from \(sellOrder.sharesToSell) to \(roundedQuantity) shares")
            }
            
            let orderLeg = OrderLegCollection(
                orderLegType: .EQUITY,
                legId: Int64(legId),
                instrument: instrument,
                instruction: .SELL,
                quantity: roundedQuantity
            )
            
            // Use the trailing stop percentage from the sell order record (already calculated correctly)
            let trailingStopPercent: Double = sellOrder.trailingStop
            AppLogger.shared.debug("=== createSimplifiedChildOrder:  trailingStopPercent: \(trailingStopPercent) from sell order record")

            // Round prices and percentages to the penny (2 decimal places)
            let roundedTargetPrice = round(sellOrder.target * 100) / 100
            let roundedTrailingStopPercent = round(trailingStopPercent * 100) / 100
            
            AppLogger.shared.debug("  📊 Rounded Values:")
            AppLogger.shared.debug("    Rounded Target Price: \(roundedTargetPrice)")
            AppLogger.shared.debug("    Rounded Trailing Stop %: \(roundedTrailingStopPercent)")
            
            // Create simplified SELL order matching sample_order7.py pattern
            let childOrder = Order(
                session: .NORMAL,
                duration: .GOOD_TILL_CANCEL,
                orderType: .TRAILING_STOP_LIMIT,
                complexOrderStrategyType: .NONE,
                quantity: roundedQuantity,
                destinationLinkName: "AutoRoute",
                stopPriceLinkBasis: .ASK,
                stopPriceLinkType: .PERCENT,
                stopPriceOffset: roundedTrailingStopPercent,
                stopType: .ASK,
                priceLinkBasis: .MANUAL,
                price: roundedTargetPrice, // Use rounded target price as limit price
                orderLegCollection: [orderLeg],
                orderStrategyType: .SINGLE,
                cancelable: true,
                editable: false,
                accountNumber: accountNumber
            )
            
            return childOrder
            
        } else if orderType == "BUY" {
            guard let buyOrder = order as? BuyOrderRecord else {
                AppLogger.shared.warning("❌ Invalid buy order type")
                return nil
            }
            
            AppLogger.shared.debug("Creating simplified BUY order:")
            AppLogger.shared.debug("  Shares: \(buyOrder.sharesToBuy)")
            AppLogger.shared.debug("  Target: \(buyOrder.targetBuyPrice)")
            AppLogger.shared.debug("  Entry: \(buyOrder.entryPrice)")
            
            // Create the order leg collection for BUY
            let orderLeg = OrderLegCollection(
                orderLegType: .EQUITY,
                legId: Int64(legId),
                instrument: instrument,
                instruction: .BUY,
                quantity: buyOrder.sharesToBuy
            )
            
            // For buy orders, trailing stop should be above current price to trigger the order
            // Use the trailing stop value from the buy order record (already calculated correctly)
            let trailingStopPercent: Double = buyOrder.trailingStop
            AppLogger.shared.debug("=== createSimplifiedChildOrder:  Trailing Stop Percent: \(trailingStopPercent) from buy order record")

            // Round prices and percentages to the penny (2 decimal places)
            let roundedTargetPrice = round(buyOrder.targetBuyPrice * 100) / 100
            let roundedTrailingStopPercent = round(trailingStopPercent * 100) / 100
            
            AppLogger.shared.debug("  📊 Rounded Values:")
            AppLogger.shared.debug("    Rounded Target Price: \(roundedTargetPrice)")
            AppLogger.shared.debug("    Rounded Trailing Stop %: \(roundedTrailingStopPercent)")
            
            // Create simplified BUY order matching sample_order7.py pattern
            let childOrder = Order(
                session: .NORMAL,
                duration: buyOrder.preferDayDuration ? .DAY : .GOOD_TILL_CANCEL,
                orderType: .TRAILING_STOP_LIMIT,
                complexOrderStrategyType: .NONE,
                quantity: buyOrder.sharesToBuy,
                destinationLinkName: "AutoRoute",
                stopPriceLinkBasis: .BID,
                stopPriceLinkType: .PERCENT,
                stopPriceOffset: roundedTrailingStopPercent,
                stopType: .BID,
                priceLinkBasis: .MANUAL,
                price: roundedTargetPrice, // Use rounded target price as limit price
                orderLegCollection: [orderLeg],
                orderStrategyType: .SINGLE,
                cancelable: true,
                editable: false,
                accountNumber: accountNumber
            )
            
            return childOrder
        }
        
        AppLogger.shared.warning("❌ Unknown order type: \(orderType)")
        return nil
    }

    // MARK: - Optimized Tax Lot Calculation
    public func computeTaxLotsOptimized(symbol: String, currentPrice: Double? = nil) async -> [SalesCalcPositionsRecord] {
        let performanceStart = Date()
        
        AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) ===")
        
        // Check cache first - this is the key performance improvement
        if let cachedTaxLots = await getCachedTaxLots(for: symbol) {
            AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) - returning \(cachedTaxLots.count) cached ===")
            AppLogger.shared.info("⏱️ Performance: computeTaxLotsOptimized_\(symbol) completed in \(String(format: "%.2f", Date().timeIntervalSince(performanceStart)))s")
            return cachedTaxLots
        }
        
        let currentShareCount = getShareCount(symbol: symbol)
        let loadedMonths = await loadedTransactionHistoryMonths()
        let sourceTransactions = await getTransactionsForOptimized(symbol: symbol)
        let transactions = tradeRelevantTransactionsForLogic(symbol: symbol, sourceTransactions: sourceTransactions)
        let historyComplete = shareHistoryIsComplete(for: symbol, in: sourceTransactions)
        let fetchLimit = historyComplete ? initialTransactionHistoryMonths : extendedTransactionHistoryMonths
        AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) - loaded \(loadedMonths)/\(fetchLimit) month(s), complete history: \(historyComplete) ===")
        
        // Clear previous results
        m_lastFilteredPositionRecords.removeAll(keepingCapacity: true)
        
        // Get last price for this security
        let quoteData = currentPrice == nil ? await fetchQuote(symbol: symbol) : nil
        let lastPrice: Double
        if let currentPrice = currentPrice {
            lastPrice = currentPrice
        } else if let quote = quoteData?.quote?.lastPrice {
            lastPrice = quote
        } else if let extended = quoteData?.extended?.lastPrice {
            lastPrice = extended
        } else if let regular = quoteData?.regular?.regularMarketLastPrice {
            lastPrice = regular
        } else {
            lastPrice = await fetchPriceHistory(symbol: symbol)?.candles.last?.close ?? 0.0
        }
        
        // Use optimized transaction fetching with caching
        AppLogger.shared.debug("=== computeTaxLotsOptimized \(symbol) - processing \(transactions.count) trade-relevant transactions ===")
        
        var totalTransactionsFound = 0
        var totalSharesFound = 0.0
        var workingShareCount = currentShareCount
        
        // Process trade-relevant transactions in a single pass
        for transaction in transactions {
            totalTransactionsFound += 1
            
            for transferItem in transaction.transferItems {
                // Find transferItems where the shares, value, and cost are not 0
                guard let numberOfShares = transferItem.amount,
                      numberOfShares != 0.0,
                      transferItem.instrument?.symbol == symbol
                else {
                    continue
                }
                
                totalSharesFound += numberOfShares
                
                // Don't calculate gain/loss here - it will be calculated after adjustments
                let gainLossDollar = 0.0
                let gainLossPct = 0.0
                
                // Parse trade date
                guard let tradeDate: String = try? Date(transaction.tradeDate ?? "1970-01-01T00:00:00+0000",
                                              strategy: .iso8601.year().month().day().time(includingFractionalSeconds: false)).dateString() else {
                    AppLogger.shared.error("-- Failed to parse date in trade. transferItem: \(transferItem.dump())")
                    continue
                }
                
                // Update share count (working backwards)
                if numberOfShares > 0 {
                    // BUY transaction - subtract shares
                    workingShareCount = ((workingShareCount - numberOfShares) * 100000).rounded() / 100000
                } else {
                    // SELL transaction - add back shares
                    workingShareCount = ((workingShareCount + abs(numberOfShares)) * 100000).rounded() / 100000
                }
                
                // Add position record for this transaction
                m_lastFilteredPositionRecords.append(
                    SalesCalcPositionsRecord(
                        openDate: tradeDate,
                        gainLossPct: gainLossPct,
                        gainLossDollar: gainLossDollar,
                        quantity: numberOfShares,
                        price: lastPrice,
                        costPerShare: transferItem.price!,
                        marketValue: numberOfShares * lastPrice,
                        costBasis: transferItem.price! * numberOfShares,
                        splitMultiple: 1.0
                    )
                )

                // Minimal-data walk: stop as soon as the running share count reaches zero.
                // We only need history back to the point that accounts for the current position.
                if isNearZero(workingShareCount) {
                    showIncompleteDataWarning = false
                    AppLogger.shared.debug("-- computeTaxLotsOptimized: \(symbol) -- Found zero — stopping backward walk")
                    break
                }
            }

            if isNearZero(workingShareCount) {
                break
            }
        }

        // If we never reached zero, history is incomplete (background backfill will load more)
        if !isNearZero(workingShareCount) {
            showIncompleteDataWarning = true
            AppLogger.shared.warning("Warning: computeTaxLotsOptimized could not find zero point for \(symbol) (remainder \(workingShareCount))")
        }

        m_lastFilteredPositionRecords = removeConsolidationJournalRecords(m_lastFilteredPositionRecords)
        
        // Sort records by date (oldest first) and cost (highest first for same date)
        // Same-day ties: higher cost first; then sells before buys (negative quantity first)
        m_lastFilteredPositionRecords.sort {
            ($0.openDate < $1.openDate)
            || ($0.openDate == $1.openDate && $0.costPerShare > $1.costPerShare)
            || ($0.openDate == $1.openDate && $0.costPerShare == $1.costPerShare && $0.quantity < $1.quantity)
        }
        
        // Match sells with buys using highest price up to that point
        var remainingRecords: [SalesCalcPositionsRecord] = []
        var buyQueue: [SalesCalcPositionsRecord] = []
        var journalConsumedCostByDate: [String: (quantity: Double, basis: Double)] = [:]
        
        for record: SalesCalcPositionsRecord in m_lastFilteredPositionRecords {
            // collect buy records until you find a sell trade record.
            if record.quantity > 0 {
                buyQueue.append(inheritJournalBuyCostBasis(record, journalConsumedCostByDate: journalConsumedCostByDate))
            } else {
                // On trades the cost-per-share is non-zero; match against highest-cost lots first.
                buyQueue.sort { ( ( 0.0 == $0.costPerShare) || ($0.costPerShare > $1.costPerShare) )}
                
                // Process sell record
                var remainingSellQuantity = abs(record.quantity)
                
                // Match sell with buys
                while remainingSellQuantity > 0 && !buyQueue.isEmpty {
                    var buyRecord = buyQueue.removeFirst()
                    let buyQuantity = buyRecord.quantity
                    
                    if buyQuantity <= remainingSellQuantity {
                        // Buy record fully matches sell
                        if isNearZero(record.costPerShare) {
                            let dateKey = journalDateKey(from: record.openDate)
                            var consumed = journalConsumedCostByDate[dateKey, default: (0, 0)]
                            consumed.quantity += buyQuantity
                            consumed.basis += buyQuantity * buyRecord.costPerShare
                            journalConsumedCostByDate[dateKey] = consumed
                        }
                        remainingSellQuantity -= buyQuantity
                    } else {
                        // Buy record partially matches sell - keep remainder if it is a meaningful lot
                        if isRetainedLotQuantity(buyRecord.quantity) {
                            let matchedQuantity = remainingSellQuantity
                            if isNearZero(record.costPerShare) {
                                let dateKey = journalDateKey(from: record.openDate)
                                var consumed = journalConsumedCostByDate[dateKey, default: (0, 0)]
                                consumed.quantity += matchedQuantity
                                consumed.basis += matchedQuantity * buyRecord.costPerShare
                                journalConsumedCostByDate[dateKey] = consumed
                            }
                            buyRecord.quantity -= matchedQuantity
                            buyRecord.marketValue = buyRecord.quantity * buyRecord.price
                            buyRecord.costBasis = buyRecord.quantity * buyRecord.costPerShare
                            buyQueue.insert(buyRecord, at: 0)
                            remainingSellQuantity = 0
                        }
                    }
                }
                
                // If we couldn't match all shares, keep the remaining sell if the buy queue is not empty
                if ( (remainingSellQuantity > 0) && (!buyQueue.isEmpty) ) {
                    var modifiedRecord = record
                    modifiedRecord.quantity = -remainingSellQuantity
                    modifiedRecord.marketValue = remainingSellQuantity * record.price
                    modifiedRecord.costBasis = remainingSellQuantity * record.costPerShare
                    remainingRecords.append(modifiedRecord)
                }
            }
        }
        
        // Add any remaining buy records
        remainingRecords.append(contentsOf: buyQueue)
        
        // Sort final records by date
        remainingRecords.sort { $0.openDate < $1.openDate }
        
        // Handle merged/renamed securities where the earliest transaction has cost = 0
        remainingRecords = handleMergedRenamedSecurities(remainingRecords, symbol: symbol)

        let lotShareTotal = roundedShareAmount(remainingRecords.reduce(0.0) { $0 + $1.quantity })
        let positionShareTotal = getShareCount(symbol: symbol)
        if abs(lotShareTotal - positionShareTotal) > 0.0001 {
            AppLogger.shared.warning("⚠️ \(symbol): tax lots sum to \(lotShareTotal) shares but position is \(positionShareTotal)")
            showIncompleteDataWarning = true
        }

        AppLogger.shared.debug("=== computeTaxLotsOptimized Summary for \(symbol) ===")
        AppLogger.shared.debug("Total transactions processed: \(totalTransactionsFound)")
        AppLogger.shared.debug("Total shares found in transactions: \(totalSharesFound)")
        AppLogger.shared.debug("Current share count from position: \(getShareCount(symbol: symbol))")
        AppLogger.shared.debug("Final tax lots created: \(remainingRecords.count)")
        for (index, record) in remainingRecords.enumerated() {
            AppLogger.shared.debug("  Lot \(index): \(record.quantity) shares at $\(record.costPerShare) on \(record.openDate)")
        }
        AppLogger.shared.debug("=== End computeTaxLotsOptimized Summary ===")
        
        m_lastFilteredPositionRecords = remainingRecords
        
        // Apply stock split adjustments
        m_lastFilteredPositionRecords = adjustForStockSplits(m_lastFilteredPositionRecords, symbol: symbol)
        
        // Calculate gain/loss for each tax lot based on current price and remaining shares
        let fetchedPrice = await fetchPriceHistory(symbol: symbol)?.candles.last?.close
        let finalPrice = currentPrice ?? fetchedPrice ?? 0.0
        
        for i in 0..<m_lastFilteredPositionRecords.count {
            let lot = m_lastFilteredPositionRecords[i]
            let remainingShares = lot.quantity
            let costPerShare = lot.costPerShare
            let costBasis = remainingShares * costPerShare
            let marketValue = remainingShares * finalPrice
            let gainLossDollar = marketValue - costBasis
            let gainLossPct = costBasis != 0 ? ((finalPrice - costPerShare) / costPerShare) * 100.0 : 0.0
            
            m_lastFilteredPositionRecords[i].gainLossDollar = gainLossDollar
            m_lastFilteredPositionRecords[i].gainLossPct = gainLossPct
            m_lastFilteredPositionRecords[i].marketValue = marketValue
            m_lastFilteredPositionRecords[i].costBasis = costBasis
            m_lastFilteredPositionRecords[i].price = finalPrice
        }
        
        // Cache only when lot totals match the live position
        if abs(lotShareTotal - positionShareTotal) <= minLotQuantityThreshold {
            await cacheTaxLots(m_lastFilteredPositionRecords, for: symbol)
        } else {
            AppLogger.shared.warning(
                "📦 Not caching tax lots for \(symbol) — lot total \(lotShareTotal) != position \(positionShareTotal)"
            )
        }
        
        // Log performance metrics
        AppLogger.shared.info("⏱️ Performance: computeTaxLotsOptimized_\(symbol) completed in \(String(format: "%.2f", Date().timeIntervalSince(performanceStart)))s")
        
        return m_lastFilteredPositionRecords
    }



} // SchwabClient
