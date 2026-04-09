//
//  HoldingsView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

// Define SortConfig and SortableColumn at the top level
struct SortConfig: Equatable {
    var column: SortableColumn
    var ascending: Bool
}

enum SortableColumn: String, CaseIterable, Identifiable {
    case symbol = "Symbol"
    case quantity = "Quantity"
    case avgPrice = "Avg Price"
    case marketValue = "Market Value"
    case pl = "P/L"
    case plPercent = "P/L%"
    case assetType = "Asset Type"
    case account = "Account"
    case lastTradeDate = "Last Trade Date"
    case orderStatus = "Order Status"
    case dte = "DTE"

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .symbol, .assetType, .account, .orderStatus, .dte:
            return true
        case .quantity, .avgPrice, .marketValue, .pl, .plPercent, .lastTradeDate:
            return false
        }
    }
}

/**
 * HoldingsView
 * 
 * This view displays the user's investment portfolio holdings in a sortable and searchable table.
 * It shows detailed information about each position including symbol, description, quantity,
 * average price, market value, profit/loss, and asset type.
 * 
 * Layout:
 * - NavigationView containing:
 *   - Table with sortable columns:
 *     - Symbol
 *     - Description
 *     - Quantity
 *     - Average Price
 *     - Market Value
 *     - P/L
 *     - Asset Type
 *   - Search bar for filtering holdings (platform-specific implementation)
 * 
 * Functionality:
 * - Automatically fetches holdings when view appears
 * - Supports sorting by any column
 * - Allows searching by symbol or description
 * - Displays formatted numbers with 2 decimal places
 * - Handles optional values with empty string fallbacks
 * - Responds to keyboard input for search functionality
 * - Delete key clears search on both platforms
 */

struct HoldingsView: View
{
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var holdings: [Position] = []
    @State private var searchText = ""
    @State private var currentSort: SortConfig? = SortConfig(column: .lastTradeDate, ascending: SortableColumn.lastTradeDate.defaultAscending)
    @State private var selectedAssetTypes: Set<AssetType> = []
    @State private var accountPositions: [(Position, String, String)] = []
    @State private var selectedAccountNumbers: Set<String> = []
    @State private var selectedOrderStatuses: Set<ActiveOrderStatus> = []
    @State private var includeNAStatus: Bool = false
    @State private var selectedPosition: SelectedPosition? = nil
    @State private var viewSize: CGSize = .zero
    @StateObject private var viewModel = HoldingsViewModel()
    @State private var isLoadingAccounts = false
    @State private var isFilterExpanded = false
    @State private var showPerformanceSummary = false
    @State private var atrValue: Double = 0.0
    @State private var sharesAvailableForTrading: Double = 0.0
    @State private var marketValue: Double = 0.0
    @State private var selectedTab: Int = 0
    @StateObject private var loadingState = LoadingState()
    @State private var isNavigating = false
    
    // Search field focus state for iOS
    @FocusState private var isSearchFieldFocused: Bool
    // Visibility of the search bar on iOS (collapsible to save space)
    @State private var isSearchVisible: Bool = false
    
    // Cache for trade dates and order status to prevent loops
    @State private var tradeDateCache: [String: String] = [:]
    @State private var orderStatusCache: [String: ActiveOrderStatus?] = [:]

    // Add state to track ongoing refresh operations
    @State private var isRefreshing = false
    @State private var currentFetchTask: Task<Void, Never>? = nil
    

    // Async sorting state
    @State private var sortedHoldings: [Position] = []
    @State private var isSorting = false
    @State private var sortGeneration = 0
    @State private var sortTask: Task<Void, Never>? = nil


    var filteredHoldings: [Position] {
        holdings.filter { position in
            // Trim trailing (and leading) spaces from the search query for matching
            let trimmedQuery = searchText.trimmingCharacters(in: .whitespaces)
            let matchesText = trimmedQuery.isEmpty ||
                (position.instrument?.symbol?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                (position.instrument?.description?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            
            let matchesAssetType = selectedAssetTypes.isEmpty || 
                (position.instrument?.assetType).map { selectedAssetTypes.contains($0) } ?? false
            
            let accountInfo = accountPositions.first { $0.0 === position }
            let matchesAccount = selectedAccountNumbers.isEmpty || 
                (accountInfo?.1).map { selectedAccountNumbers.contains($0) } ?? false
            
            let orderStatus = orderStatusCache[position.instrument?.symbol ?? ""] ?? nil
            let matchesOrderStatus: Bool
            if selectedOrderStatuses.isEmpty && !includeNAStatus {
                // No status filters selected - show all
                matchesOrderStatus = true
            } else {
                // Check if position matches any selected filters
                let matchesSpecificStatus = orderStatus != nil && selectedOrderStatuses.contains(orderStatus!)
                let matchesNAStatus = orderStatus == nil && includeNAStatus
                matchesOrderStatus = matchesSpecificStatus || matchesNAStatus
            }
            
            return matchesText && matchesAssetType && matchesAccount && matchesOrderStatus
        }
    }
    
    var uniqueOrderStatuses: [ActiveOrderStatus] {
        let statuses = orderStatusCache.values.compactMap { $0 }
        return Array(Set(statuses)).sorted { $0.priority < $1.priority }
    }
    
    /// Performs async sorting to prevent UI blocking
    private func performSort() {
        // Cancel any existing sort task
        sortTask?.cancel()
        sortGeneration += 1
        let generation = sortGeneration

        // Set loading state
        isSorting = true
        SecurityDataCacheManager.shared.setHoldingsListSortInProgress(true)

        // Get current values and capture them for the task
        let holdingsToSort = filteredHoldings
        let sortConfig = currentSort
        let accountPositionsCopy = accountPositions
        let tradeDateCacheCopy = tradeDateCache
        let orderStatusCacheCopy = orderStatusCache
        
        sortTask = Task.detached(priority: .userInitiated) { [holdingsToSort, sortConfig, accountPositionsCopy, tradeDateCacheCopy, orderStatusCacheCopy] in
            // Yield immediately to allow UI updates
            await Task.yield()
            
            guard !Task.isCancelled else {
                await MainActor.run {
                    if generation == self.sortGeneration {
                        self.isSorting = false
                        SecurityDataCacheManager.shared.setHoldingsListSortInProgress(false)
                    }
                }
                return
            }
            
            // Perform the sort
            let sorted: [Position]
            if let sortConfig = sortConfig {
                sorted = holdingsToSort.sorted(by: { first, second in
                    let ascending = sortConfig.ascending
                    let firstQuantity: Double = ((first.longQuantity ?? 0) + (first.shortQuantity ?? 0))
                    let secondQuantity: Double = ((second.longQuantity ?? 0) + (second.shortQuantity ?? 0))
                    switch sortConfig.column {
                    case .symbol:
                        return ascending ?
                            (first.instrument?.symbol ?? "") < (second.instrument?.symbol ?? "") :
                            (first.instrument?.symbol ?? "") > (second.instrument?.symbol ?? "")
                    case .quantity:
                        return ascending ?
                            firstQuantity < secondQuantity :
                            firstQuantity > secondQuantity
                    case .avgPrice:
                        return ascending ?
                            (first.averagePrice ?? 0) < (second.averagePrice ?? 0) :
                            (first.averagePrice ?? 0) > (second.averagePrice ?? 0)
                    case .marketValue:
                        return ascending ?
                            (first.marketValue ?? 0) < (second.marketValue ?? 0) :
                            (first.marketValue ?? 0) > (second.marketValue ?? 0)
                    case .pl:
                        return ascending ?
                            (first.longOpenProfitLoss ?? 0) < (second.longOpenProfitLoss ?? 0) :
                            (first.longOpenProfitLoss ?? 0) > (second.longOpenProfitLoss ?? 0)
                    case .plPercent:
                        let firstPL = first.longOpenProfitLoss ?? 0
                        let secondPL = second.longOpenProfitLoss ?? 0
                        let firstMV = first.marketValue ?? 0
                        let secondMV = second.marketValue ?? 0
                        let firstCostBasis = firstMV - firstPL
                        let secondCostBasis = secondMV - secondPL
                        let firstPLPercent = firstCostBasis != 0 ? firstPL / firstCostBasis : 0
                        let secondPLPercent = secondCostBasis != 0 ? secondPL / secondCostBasis : 0
                        return ascending ? firstPLPercent < secondPLPercent : firstPLPercent > secondPLPercent
                    case .assetType:
                        return ascending ?
                            (first.instrument?.assetType?.rawValue ?? "") < (second.instrument?.assetType?.rawValue ?? "") :
                            (first.instrument?.assetType?.rawValue ?? "") > (second.instrument?.assetType?.rawValue ?? "")
                    case .account:
                        let firstAccount = accountPositionsCopy.first { $0.0 === first }?.1 ?? ""
                        let secondAccount = accountPositionsCopy.first { $0.0 === second }?.1 ?? ""
                        return ascending ? firstAccount < secondAccount : firstAccount > secondAccount
                    case .lastTradeDate:
                        let firstSymbol = first.instrument?.symbol ?? ""
                        let secondSymbol = second.instrument?.symbol ?? ""
                        let firstDate = tradeDateCacheCopy[firstSymbol] ?? "0000"
                        let secondDate = tradeDateCacheCopy[secondSymbol] ?? "0000"
                        if firstDate != secondDate {
                            return ascending ? firstDate < secondDate : firstDate > secondDate
                        }
                        // Stable order when dates missing or equal (e.g. before cache fills).
                        return firstSymbol < secondSymbol
                    case .orderStatus:
                        let firstSymbol = first.instrument?.symbol ?? ""
                        let secondSymbol = second.instrument?.symbol ?? ""
                        let firstOrderStatus = orderStatusCacheCopy[firstSymbol] ?? nil
                        let secondOrderStatus = orderStatusCacheCopy[secondSymbol] ?? nil
                        
                        // Custom sorting logic for order status
                        if let firstStatus = firstOrderStatus, let secondStatus = secondOrderStatus {
                            if firstStatus == .awaitingBuyStopCondition && secondStatus == .awaitingSellStopCondition {
                                return ascending ? true : false
                            } else if firstStatus == .awaitingSellStopCondition && secondStatus == .awaitingBuyStopCondition {
                                return ascending ? false : true
                            }
                        }
                        
                        let firstPriority : Int = firstOrderStatus?.priority ?? 0
                        let secondPriority : Int = secondOrderStatus?.priority ?? 0
                        return ascending ? firstPriority < secondPriority : firstPriority > secondPriority
                    case .dte:
                        let firstDTE : Int? = (first.instrument?.assetType == .OPTION) ? 
                            extractExpirationDate(from: first.instrument?.symbol ?? "", description: first.instrument?.description ?? "") :
                            SchwabClient.shared.getMinimumDTEForSymbol(first.instrument?.symbol ?? "")
                        let secondDTE : Int? = (second.instrument?.assetType == .OPTION) ? 
                            extractExpirationDate(from: second.instrument?.symbol ?? "", description: second.instrument?.description ?? "") :
                            SchwabClient.shared.getMinimumDTEForSymbol(second.instrument?.symbol ?? "")
                        let firstContracts : Double = SchwabClient.shared.getContractCountForSymbol(first.instrument?.symbol ?? "")
                        let secondContracts : Double = SchwabClient.shared.getContractCountForSymbol(second.instrument?.symbol ?? "")
                        
                        if firstDTE == nil && secondDTE == nil {
                            return ascending ? firstContracts < secondContracts : firstContracts > secondContracts
                        } else if firstDTE == nil {
                            return false
                        } else if secondDTE == nil {
                            return true
                        } else if firstDTE! == secondDTE! {
                            return ascending ? firstContracts < secondContracts : firstContracts > secondContracts
                        } else {
                            return ascending ? (firstDTE! < secondDTE!) : (firstDTE! > secondDTE!)
                        }
                    }
                })
            } else {
                sorted = holdingsToSort
            }
            
            // Update UI on main thread
            await MainActor.run {
                guard !Task.isCancelled else {
                    if generation == self.sortGeneration {
                        self.isSorting = false
                        SecurityDataCacheManager.shared.setHoldingsListSortInProgress(false)
                    }
                    return
                }
                guard generation == self.sortGeneration else { return }
                self.sortedHoldings = sorted
                self.isSorting = false
                SecurityDataCacheManager.shared.setHoldingsListSortInProgress(false)
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            mainContentView(geometry: geometry)
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newValue in
                    viewSize = newValue
                }
        }
        .sheet(item: $selectedPosition) { selected in
            PositionDetailSheet(
                selected: selected,
                isNavigating: $isNavigating,
                selectedTab: $selectedTab,
                atrValue: $atrValue,
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                viewSize: $viewSize,
                selectedPosition: $selectedPosition,
                sortedHoldings: sortedHoldings,
                accountPositions: accountPositions
            )
        }
        .sheet(isPresented: $showPerformanceSummary) {
            PerformanceSummaryView()
        }
        .withLoadingState(loadingState)
    }
    
    @ViewBuilder
    private func mainContentView(geometry: GeometryProxy) -> some View {
        VStack {
            // Platform-specific search implementation
            HoldingsSearchBar(
                searchText: $searchText,
                isSearchVisible: $isSearchVisible,
                isSearchFieldFocused: $isSearchFieldFocused
            )
            
            // Filter section
            HoldingsFilterSection(
                isFilterExpanded: $isFilterExpanded,
                selectedAssetTypes: $selectedAssetTypes,
                selectedAccountNumbers: $selectedAccountNumbers,
                selectedOrderStatuses: $selectedOrderStatuses,
                includeNAStatus: $includeNAStatus,
                showPerformanceSummary: $showPerformanceSummary,
                isRefreshing: $isRefreshing,
                isLoadingAccounts: $isLoadingAccounts,
                uniqueAssetTypes: viewModel.uniqueAssetTypes,
                uniqueAccountNumbers: viewModel.uniqueAccountNumbers,
                uniqueOrderStatuses: uniqueOrderStatuses,
                onRefresh: handleRefresh
            )

            // Main content area
            HoldingsContent(
                isLoadingAccounts: isLoadingAccounts,
                sortedHoldings: sortedHoldings,
                onPositionSelected: handlePositionSelected,
                accountPositions: accountPositions,
                currentSort: $currentSort,
                viewSize: viewSize,
                tradeDateCache: tradeDateCache,
                orderStatusCache: orderStatusCache
            )
        }
        .padding(5)
        .applyMainViewModifiers(
            searchText: $searchText,
            isSearchFieldFocused: $isSearchFieldFocused,
            isLoadingAccounts: $isLoadingAccounts,
            sortedHoldings: $sortedHoldings,
            currentSort: $currentSort,
            selectedAssetTypes: $selectedAssetTypes,
            selectedAccountNumbers: $selectedAccountNumbers,
            selectedOrderStatuses: $selectedOrderStatuses,
            includeNAStatus: $includeNAStatus,
            isSorting: $isSorting,
            filteredHoldings: filteredHoldings,
            loadingState: loadingState,
            currentFetchTask: $currentFetchTask,
            onSortChange: performSort,
            onCacheInvalidation: invalidateCacheForChangedList,
            onFetchHoldings: fetchHoldingsAsync,
            onSetDefaultAssetTypes: {
                selectedAssetTypes = Set(viewModel.uniqueAssetTypes.filter { $0 == .EQUITY })
            }
        )
    }
    
    private func handleRefresh() {
        Task {
            guard !isRefreshing else { return }
            
            isRefreshing = true
            isLoadingAccounts = true
            
            currentFetchTask?.cancel()
            
            tradeDateCache.removeAll()
            orderStatusCache.removeAll()
            SecurityDataCacheManager.shared.clear()
            AppLogger.shared.debug("🔄 Cleared security data cache on refresh")
            
            currentFetchTask = Task {
                await fetchHoldingsAsync()
            }
            
            await currentFetchTask?.value
            
            await MainActor.run {
                isRefreshing = false
                isLoadingAccounts = false
            }
        }
    }
    
    private func handlePositionSelected(newId: Position.ID, position: Position, accountNumber: String) {
        loadingState.setLoading(true)
        selectedPosition = SelectedPosition(id: newId, position: position, accountNumber: accountNumber)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            loadingState.setLoading(false)
        }
    }
    
    /// Prefetches data for the first security in the sorted holdings list if it's not already cached
    private func prefetchFirstSecurityIfNeeded() async {
        // Ensure we're not on main actor to avoid blocking
        await MainActor.run {
            guard !sortedHoldings.isEmpty else {
                print("🔮 No holdings to prefetch")
                return
            }
        }
        
        let firstSecurity = await MainActor.run { sortedHoldings[0] }
        guard let symbol = firstSecurity.instrument?.symbol else {
            print("🔮 First security has no symbol")
            return
        }
        
        let criticalGroups: [SecurityDataGroup] = [.details, .priceHistory, .transactions, .taxLots]
        let needed = await MainActor.run {
            SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(symbol: symbol, among: criticalGroups)
        }
        guard !needed.isEmpty else {
            print("✅ First security \(symbol) already cached or in flight, skipping prefetch")
            return
        }

        print("🔮 Prefetching first security in list: \(symbol) groups: \(needed.map { "\($0)" }.joined(separator: ", "))")
        await prefetchSecurityData(symbol: symbol)
    }
    
    /// Prefetches complete security data (quotes, price history, transactions, tax lots) for a symbol
    private func prefetchSecurityData(symbol: String) async {
        let criticalGroups: [SecurityDataGroup] = [.details, .priceHistory, .transactions, .taxLots]
        let toFetch = await MainActor.run {
            SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(symbol: symbol, among: criticalGroups)
        }
        guard !toFetch.isEmpty else {
            print("🔮 [First Security] Skip \(symbol) — already complete or in progress")
            return
        }

        print("🔮 [First Security] Prefetching data for: \(symbol) groups: \(toFetch.map { "\($0)" }.joined(separator: ", "))")

        await MainActor.run {
            _ = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: toFetch)
        }

        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay

        var fetchedQuote: QuoteData?
        if toFetch.contains(.details) {
            if Task.isCancelled { return }
            let q = await Task.detached(priority: .low) {
                SchwabClient.shared.fetchQuote(symbol: symbol)
            }.value
            if Task.isCancelled { return }
            await Task.yield()
            if let q {
                fetchedQuote = q
                await MainActor.run {
                    _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .details) { snapshot in
                        snapshot.quoteData = q
                    }
                }
            }
        }
        if fetchedQuote == nil {
            fetchedQuote = await MainActor.run {
                SecurityDataCacheManager.shared.snapshot(for: symbol)?.quoteData
            }
        }

        var fetchedPriceHistory: CandleList?
        if toFetch.contains(.priceHistory) {
            if Task.isCancelled { return }
            let h = await Task.detached(priority: .low) {
                SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            }.value
            if Task.isCancelled { return }
            await Task.yield()
            if let h {
                let fetchedATRValue = await Task.detached(priority: .low) {
                    SchwabClient.shared.computeATR(symbol: symbol)
                }.value
                if Task.isCancelled { return }
                fetchedPriceHistory = h
                await MainActor.run {
                    _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .priceHistory) { snapshot in
                        snapshot.priceHistory = h
                        snapshot.atrValue = fetchedATRValue
                    }
                }
            }
        }
        if fetchedPriceHistory == nil {
            fetchedPriceHistory = await MainActor.run {
                SecurityDataCacheManager.shared.snapshot(for: symbol)?.priceHistory
            }
        }

        if toFetch.contains(.transactions) {
            if Task.isCancelled { return }
            print("🔮 [First Security] Fetching transactions for: \(symbol)")
            let fetchedTransactions = await Task.detached(priority: .low) {
                SchwabClient.shared.getTransactionsFor(symbol: symbol)
            }.value
            if Task.isCancelled { return }
            await Task.yield()
            await MainActor.run {
                _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .transactions) { snapshot in
                    snapshot.transactions = fetchedTransactions
                }
            }
            print("🔮 [First Security] Transactions complete for \(symbol): \(fetchedTransactions.count) transactions")
        }

        if toFetch.contains(.taxLots) {
            if Task.isCancelled { return }
            let currentPrice = fetchedQuote?.quote?.lastPrice
                ?? fetchedQuote?.extended?.lastPrice
                ?? fetchedPriceHistory?.candles.last?.close
            let fetchedTaxLots = await Task.detached(priority: .low) {
                SchwabClient.shared.computeTaxLots(symbol: symbol, currentPrice: currentPrice)
            }.value
            if Task.isCancelled { return }
            let fetchedSharesAvailable = await Task.detached(priority: .low) {
                SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: fetchedTaxLots)
            }.value
            await MainActor.run {
                _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .taxLots) { snapshot in
                    snapshot.taxLotData = fetchedTaxLots
                    snapshot.sharesAvailableForTrading = fetchedSharesAvailable
                }
            }
        }

        print("✅ [First Security] Prefetch complete for \(symbol)")
    }
    
    /// Invalidates cache entries for symbols not in the current sorted/filtered list
    /// Called when filters or sort order change
    /// Uses filteredHoldings instead of sortedHoldings because performSort updates sortedHoldings asynchronously,
    /// and this function runs synchronously. filteredHoldings reflects the current filters immediately.
    private func invalidateCacheForChangedList() {
        let currentListSymbols = Set(filteredHoldings.compactMap { $0.instrument?.symbol })
        SecurityDataCacheManager.shared.invalidateSymbolsNotInList(currentListSymbols)
        AppLogger.shared.debug("🔄 Cache invalidated for symbols not in current list (list size: \(currentListSymbols.count))")
    }

    /// Re-read latest trade dates from SchwabClient, sync `accountPositions` display strings, and re-apply the current sort.
    @MainActor
    private func refreshTradeDatesAfterTransactionFetch() {
        for position in holdings {
            if let symbol = position.instrument?.symbol {
                tradeDateCache[symbol] = SchwabClient.shared.getLatestTradeDate(for: symbol)
            }
        }
        accountPositions = SchwabClient.shared.getAccounts().flatMap { accountContent in
            let accountNumber = accountContent.securitiesAccount?.accountNumber ?? ""
            let lastThreeDigits = String(accountNumber.suffix(3))
            return accountContent.securitiesAccount?.positions.map {
                ($0, lastThreeDigits, tradeDateCache[$0.instrument?.symbol ?? ""] ?? "")
            } ?? []
        }
        performSort()
    }
    
    private func fetchHoldings()  {
        Task {
            await fetchHoldingsAsync()
        }
    }
    
    private func fetchHoldingsAsync() async {
        print("=== fetchHoldingsAsync - Starting optimized data loading ===")
        
        // Check for cancellation at the start
        try? await Task.sleep(nanoseconds: 1) // Allow cancellation to be checked
        guard !Task.isCancelled else {
            print("=== fetchHoldingsAsync - Cancelled before starting ===")
            return
        }
        
        // PRIORITY 1: Fetch accounts immediately (needed for holdings display)
        Task {
            print("🚀 PRIORITY 1: Fetching accounts for holdings display")
            await SchwabClient.shared.fetchAccounts(retry: true)
            
            // Check for cancellation before updating UI
            guard !Task.isCancelled else { return }
            
            // Update UI immediately with holdings data on main actor
            await MainActor.run {
                // Extract positions from accounts with their account numbers
                accountPositions = SchwabClient.shared.getAccounts().flatMap { accountContent in
                    let accountNumber = accountContent.securitiesAccount?.accountNumber ?? ""
                    let lastThreeDigits = String(accountNumber.suffix(3))
                    return accountContent.securitiesAccount?.positions.map {
                        ($0, lastThreeDigits, "") // Empty trade date for now
                    } ?? []
                }
                holdings = accountPositions.map { $0.0 }
                viewModel.updateUniqueValues(holdings: holdings, accountPositions: accountPositions)
                
                print("✅ Holdings displayed: \(holdings.count) positions")
            }
            
            // Trigger initial sort after holdings are loaded (on main actor)
            await MainActor.run {
                performSort()
            }
            
            // Prefetch first security in the list if not already cached (runs in background)
            //await prefetchFirstSecurityIfNeeded()
        }
        
        // PRIORITY 2: Fetch order history in parallel (needed for "Orders" column)
        Task {
            print("🚀 PRIORITY 2: Fetching order history in parallel")
            print("🔍 Before fetchOrderHistory: orderStatusCache has \(orderStatusCache.count) entries")
            await SchwabClient.shared.fetchOrderHistory()
            print("🔍 After fetchOrderHistory: SchwabClient has \(SchwabClient.shared.getOrderList().count) orders")
            
            
            
            // Check for cancellation before updating UI
            guard !Task.isCancelled else { return }
            
            // Update order information in UI and populate cache
            await MainActor.run {
                // Populate order status cache
                print("🔍 === Populating order status cache ===")
                print("🔍 Processing \(holdings.count) positions to populate order status cache")
                for (index, position) in holdings.enumerated() {
                    if let symbol = position.instrument?.symbol {
                        let orderStatus = SchwabClient.shared.getPrimaryOrderStatus(for: symbol)
                        orderStatusCache[symbol] = orderStatus
                        print("📋 [\(index + 1)/\(holdings.count)] Cached order status for \(symbol): \(orderStatus?.shortDisplayName ?? "nil")")
                    }
                }
                print("✅ Order history loaded and cache populated with \(orderStatusCache.count) entries")
                // Re-sort: initial sort ran before order status existed (all nil / same key).
                performSort()
            }
        }
        
        // PRIORITY 3: Fetch transaction history in background (for trade dates and tax lots)
        Task {
            print("🚀 PRIORITY 3: Fetching transaction history in background")
            
            // Fetch first 12 months in waves of 3 parallel months; refresh UI on main after each wave
            await SchwabClient.shared.fetchTransactionHistoryReduced(months: 12, onBatchOnMainActor: {
                refreshTradeDatesAfterTransactionFetch()
            })
            
            // Check for cancellation before continuing background work
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                print("✅ Initial transaction months loaded and trade dates refreshed")
            }
            
            // Remaining months up to maxMonthDelta (initial reduced load already covered first 12)
            let remainingMonths = max(SchwabClient.shared.maxMonthDelta - 12, 0)
            if remainingMonths > 0 {
                print("🚀 Fetching remaining \(remainingMonths) months in background")
                
                let parallelMonths = 3
                for batchStart in stride(from: 0, to: remainingMonths, by: parallelMonths) {
                    guard !Task.isCancelled else {
                        print("=== fetchHoldingsAsync - Cancelled during background processing ===")
                        return
                    }
                    
                    let batchEnd = min(batchStart + parallelMonths, remainingMonths)
                    let count = batchEnd - batchStart
                    print("📦 Processing background batch: \(count) parallel month fetch(es)")
                    
                    await withTaskGroup(of: Void.self) { group in
                        for _ in 0..<count {
                            group.addTask {
                                await SchwabClient.shared.fetchTransactionHistory()
                            }
                        }
                        await group.waitForAll()
                    }
                    
                    await MainActor.run {
                        refreshTradeDatesAfterTransactionFetch()
                    }
                    
                    if batchEnd < remainingMonths {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                }
                
                print("✅ All transaction history loaded")
            }
        }
    }

}
