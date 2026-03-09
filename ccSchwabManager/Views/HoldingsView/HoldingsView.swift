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
    

    // Debounced prefetch task to prevent rapid API calls when filtering
    @State private var debouncedPrefetchTask: Task<Void, Never>? = nil
    
    // Async sorting state
    @State private var sortedHoldings: [Position] = []
    @State private var isSorting = false
    @State private var sortTask: Task<Void, Never>? = nil

    struct SelectedPosition: Identifiable {
        let id: Position.ID
        let position: Position
        let accountNumber: String
    }

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
        
        // Set loading state
        isSorting = true
        
        // Get current values and capture them for the task
        let holdingsToSort = filteredHoldings
        let sortConfig = currentSort
        let accountPositionsCopy = accountPositions
        let tradeDateCacheCopy = tradeDateCache
        let orderStatusCacheCopy = orderStatusCache
        
        sortTask = Task.detached(priority: .userInitiated) { [holdingsToSort, sortConfig, accountPositionsCopy, tradeDateCacheCopy, orderStatusCacheCopy] in
            // Yield immediately to allow UI updates
            await Task.yield()
            
            guard !Task.isCancelled else { return }
            
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
                        return ascending ? firstDate < secondDate : firstDate > secondDate
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
                guard !Task.isCancelled else { return }
                self.sortedHoldings = sorted
                self.isSorting = false
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Platform-specific search implementation
#if os(iOS)
                // Top controls for showing/hiding search and keyboard on iPhone
                HStack {
                    Button(action: {
                        withAnimation {
                            isSearchVisible.toggle()
                        }
                        if isSearchVisible {
                            // Focus when opening search
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isSearchFieldFocused = true
                            }
                        } else {
                            // Dismiss keyboard when hiding search
                            isSearchFieldFocused = false
                        }
                    }) {
                        Label(isSearchVisible ? "Hide Search" : "Show Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if isSearchFieldFocused {
                        Button(action: { isSearchFieldFocused = false }) {
                            Label("Hide Keyboard", systemImage: "keyboard")
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    // Network indicator showing WiFi or Cellular signal strength
                    NetworkIndicatorView()
                        .padding(.trailing, 8)
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if isSearchVisible {
                    HStack {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search by symbol or description", text: $searchText)
                                .focused($isSearchFieldFocused)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .keyboardType(.asciiCapable)
                                .submitLabel(.done)
                                .onSubmit {
                                    // Optional: Handle search submission
                                }
                                .onKeyPress(.delete) {
                                    searchText = ""
                                    return .handled
                                }
                                .onKeyPress(KeyEquivalent("\u{08}")) { // Backspace character
                                    searchText = ""
                                    return .handled
                                }
                                .onKeyPress { keyPress in
                                    // Handle alphanumeric input for search
                                    let character = keyPress.characters.first
                                    if let char = character, char.isLetter || char.isNumber || char.isWhitespace || char.isPunctuation {
                                        searchText += String(char)
                                        return .handled
                                    }
                                    return .ignored
                                }
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        
                        Button(action: {
                            withAnimation { isSearchVisible = false }
                            isSearchFieldFocused = false
                        }) {
                            Image(systemName: "chevron.up.circle")
                                .foregroundColor(.secondary)
                                .padding(.leading, 6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                #endif
                
                // Filter section with disclosure button
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            withAnimation {
                                isFilterExpanded.toggle()
                            }
                        }) {
                            HStack {
                                Image(systemName: isFilterExpanded ? "chevron.down" : "chevron.right")
                                    .foregroundColor(.accentColor)
                                Text("Filters")
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Button(action: {
                            showPerformanceSummary = true
                        }) {
                            HStack {
                                Image(systemName: "chart.bar.doc.horizontal")
                                    .foregroundColor(.accentColor)
                                Text("Stats")
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        Button(action: {
                            // Trigger refresh of securities data
                            Task {
                                // Prevent concurrent refresh operations
                                guard !isRefreshing else { return }
                                
                                isRefreshing = true
                                isLoadingAccounts = true
                                
                                // Cancel any existing fetch task
                                currentFetchTask?.cancel()
                                
                                // Clear caches to force fresh data
                                tradeDateCache.removeAll()
                                orderStatusCache.removeAll()
                                
                                // Create new fetch task
                                currentFetchTask = Task {
                                    await fetchHoldingsAsync()
                                }
                                
                                // Wait for completion
                                await currentFetchTask?.value
                                
                                // Reset states
                                await MainActor.run {
                                    isRefreshing = false
                                    isLoadingAccounts = false
                                }
                            }
                        }) {
                            HStack {
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundColor(.accentColor)
                                }
                                Text(isRefreshing ? "Refreshing..." : "Refresh")
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isRefreshing || isLoadingAccounts)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    
                    if isFilterExpanded {
                        FilterControls(
                            selectedAssetTypes: $selectedAssetTypes,
                            selectedAccountNumbers: $selectedAccountNumbers,
                            selectedOrderStatuses: $selectedOrderStatuses,
                            includeNAStatus: $includeNAStatus,
                            uniqueAssetTypes: viewModel.uniqueAssetTypes,
                            uniqueAccountNumbers: viewModel.uniqueAccountNumbers,
                            uniqueOrderStatuses: uniqueOrderStatuses
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                if isLoadingAccounts {
                    ProgressView()
                        .progressViewStyle( CircularProgressViewStyle( tint: .accentColor ) )
                        .scaleEffect(2.0, anchor: .center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    Spacer()
                    HoldingsTable(
                        sortedHoldings: sortedHoldings,
                        selectedPositionId: Binding(
                            get: { selectedPosition?.id },
                            set: { newId in
                                if let newId: Position.ID = newId,
                                   let position: Position = sortedHoldings.first(where: { $0.id == newId }),
                                   let accountNumber: String = accountPositions.first(where: { $0.0.id == newId })?.1 {
                                    // Show loading indicator immediately when position is selected
                                    loadingState.setLoading(true)
                                    selectedPosition = SelectedPosition(id: newId, position: position, accountNumber: accountNumber)
                                    // Clear loading after a short delay to allow sheet to show its own indicator
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        loadingState.setLoading(false)
                                    }
                                }
                            }
                        ),
                        accountPositions: accountPositions,
                        currentSort: $currentSort,
                        viewSize: viewSize,
                        tradeDateCache: tradeDateCache,
                        orderStatusCache: orderStatusCache,
                    )
                    .padding( 5 )
                }
            } // VStack
            .padding( 5 )
            // Platform-specific searchable modifier (for macOS)
            #if os(macOS)
            .searchable(text: $searchText, prompt: "Search by symbol or description")
            #endif
            .onAppear {
                // Do not auto-focus search on iOS to avoid keyboard covering content
            }
            // IOS or VisionOS
#if os(iOS)
            // Add a keyboard toolbar with a Done button to dismiss
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isSearchFieldFocused = false }
                }
            }
#endif // os(iOS)
            //.navigationTitle("Holdings")
            .task {
                defer { isLoadingAccounts = false }
                isLoadingAccounts = true
                // Connect loading state to SchwabClient
                //print("🔗 HoldingsView - Setting SchwabClient.loadingDelegate")
                SchwabClient.shared.loadingDelegate = loadingState
                await fetchHoldingsAsync()
                selectedAssetTypes = Set( viewModel.uniqueAssetTypes.filter { $0 == .EQUITY } )
            }
            .onDisappear {
                //print("🔗 HoldingsView - Clearing SchwabClient.loadingDelegate")
                SchwabClient.shared.loadingDelegate = nil
                // Cancel any ongoing fetch task
                currentFetchTask?.cancel()
                currentFetchTask = nil
            }
            .onAppear {
                viewSize = geometry.size
                // Initialize sorted holdings
                if sortedHoldings.isEmpty {
                    sortedHoldings = filteredHoldings
                }
            }
            .onChange(of: geometry.size) { oldValue, newValue in
                viewSize = newValue
            }
            // Trigger sorting when sort config changes
            .onChange(of: currentSort) { oldValue, newValue in
                performSort()
                // print("🔮 Sort changed, scheduling debounced prefetch")
                // debouncedPrefetchFirstSecurity()
            }
            .onChange(of: searchText) { oldValue, newValue in
                performSort()
                // print("🔮 Search text changed, scheduling debounced prefetch")
                // debouncedPrefetchFirstSecurity()
            }
            .onChange(of: selectedAssetTypes) { oldValue, newValue in
                performSort()
                // print("🔮 Asset type filter changed, scheduling debounced prefetch")
                // debouncedPrefetchFirstSecurity()
            }
            .onChange(of: selectedAccountNumbers) { oldValue, newValue in
                performSort()
                // print("🔮 Account filter changed, scheduling debounced prefetch")
                // debouncedPrefetchFirstSecurity()
            }
            .onChange(of: selectedOrderStatuses) { oldValue, newValue in
                performSort()
                // print("🔮 Order status filter changed, scheduling debounced prefetch")
                // debouncedPrefetchFirstSecurity()
            }
            .onChange(of: includeNAStatus) { oldValue, newValue in
                performSort()
                // print("🔮 Include NA status filter changed, scheduling debounced prefetch")
                // debouncedPrefetchFirstSecurity()
            }
            .sheet(isPresented: $showPerformanceSummary) {
                PerformanceSummaryView()
            }
            // Show loading indicator overlay when sorting
            .overlay {
                if isSorting {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                .scaleEffect(1.2)
                            Text("Sorting...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(8)
                        .shadow(radius: 4)
                        .padding()
                        Spacer()
                    }
                }
            }
        }
        .sheet(item: $selectedPosition) { selected in
            let currentIndex = sortedHoldings.firstIndex(where: { $0.id == selected.id }) ?? 0
            PositionDetailView(
                position: selected.position,
                accountNumber: selected.accountNumber,
                currentIndex: currentIndex,
                totalPositions: sortedHoldings.count,
                symbol: selected.position.instrument?.symbol ?? "",
                atrValue: atrValue,
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                onNavigate: { newIndex in
                    guard newIndex >= 0 && newIndex < sortedHoldings.count else { return }
                    guard !isNavigating else { return } // Prevent rapid navigation
                    
                    print("HoldingsView: Navigating to position \(newIndex)")
                    isNavigating = true
                    
                    // Add a small delay to prevent rapid navigation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        let newPosition = sortedHoldings[newIndex]
                        let accountNumber = accountPositions.first { $0.0 === newPosition }?.1 ?? ""
                        selectedPosition = SelectedPosition(id: newPosition.id, position: newPosition, accountNumber: accountNumber)
                        
                        // Reset navigation flag after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isNavigating = false
                        }
                    }
                },
                getAdjacentSymbols: {
                    // Return the symbols of the 2 previous and 2 next positions for extended prefetching
                    let previous1: String? = currentIndex > 0 ? sortedHoldings[currentIndex - 1].instrument?.symbol : nil
                    let previous2: String? = currentIndex > 1 ? sortedHoldings[currentIndex - 2].instrument?.symbol : nil
                    let next1: String? = currentIndex < sortedHoldings.count - 1 ? sortedHoldings[currentIndex + 1].instrument?.symbol : nil
                    let next2: String? = currentIndex < sortedHoldings.count - 2 ? sortedHoldings[currentIndex + 2].instrument?.symbol : nil
                    return (previous1: previous1, previous2: previous2, next1: next1, next2: next2)
                },
                selectedTab: $selectedTab,
            )
            .task {
                // Note: Data fetching moved to PositionDetailView to ensure loading indicator is visible
                // The detail view will handle ATR and tax lot computation when it appears
            }
            .onChange(of: selected.position.instrument?.symbol) { oldValue, newValue in
                // Note: Data fetching moved to PositionDetailView to ensure loading indicator is visible
                // The detail view will handle ATR and tax lot computation on symbol changes
            }
            .frame( width: viewSize.width * 0.97,
                    height: viewSize.height * 0.98 )
        }
        .withLoadingState(loadingState)
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
        
        // Check if first security needs prefetching
        let snapshot = SecurityDataCacheManager.shared.snapshot(for: symbol)
        let criticalGroups: [SecurityDataGroup] = [.details, .priceHistory, .transactions, .taxLots]
        let needsPrefetch = snapshot == nil || !criticalGroups.allSatisfy { snapshot!.isLoaded($0) }
        
        if needsPrefetch {
            print("🔮 Prefetching first security in list: \(symbol)")
            // Already in detached task, just call prefetch
            await prefetchSecurityData(symbol: symbol)
        } else {
            print("✅ First security \(symbol) already cached, skipping prefetch")
        }
    }
    
    /// Debounced version of prefetchFirstSecurityIfNeeded to prevent rapid API calls when filtering
    /// Waits 400ms after the last filter change before triggering prefetch
    private func debouncedPrefetchFirstSecurity() {
        // Cancel any existing debounced task
        debouncedPrefetchTask?.cancel()
        
        // Create new debounced task with low priority to avoid blocking UI
        debouncedPrefetchTask = Task.detached(priority: .low) {
            // Wait 400ms for debounce
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
            
            // Check if task was cancelled (filter changed again)
            guard !Task.isCancelled else {
                print("🔮 Debounced prefetch cancelled - filter changed again")
                return
            }
            
            // Additional delay to ensure UI is responsive after sorting
            // Longer delay for sorting operations to ensure UI is fully responsive
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms additional delay
            
            // Yield to allow any pending UI updates
            await Task.yield()
            
            // Now perform the prefetch (runs in background)
            await self.prefetchFirstSecurityIfNeeded()
        }
    }
    
    /// Prefetches complete security data (quotes, price history, transactions, tax lots) for a symbol
    private func prefetchSecurityData(symbol: String) async {
        print("🔮 [First Security] Prefetching data for: \(symbol)")
        
        // Mark as loading in cache
        let loadingGroups: [SecurityDataGroup] = [.details, .priceHistory, .transactions, .taxLots]
        await MainActor.run {
            _ = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: loadingGroups)
        }
        
        // Yield multiple times to ensure UI stays responsive
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms delay
        
        // Fetch quote data in background
        if Task.isCancelled { return }
        let fetchedQuote = await Task.detached(priority: .low) {
            return SchwabClient.shared.fetchQuote(symbol: symbol)
        }.value
        if Task.isCancelled { return }
        
        // Yield after blocking call to allow UI updates
        await Task.yield()
        
        if let fetchedQuote {
            await MainActor.run {
                _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .details) { snapshot in
                    snapshot.quoteData = fetchedQuote
                }
            }
        }
        
        // Fetch price history in background
        if Task.isCancelled { return }
        let fetchedPriceHistory = await Task.detached(priority: .low) {
            return SchwabClient.shared.fetchPriceHistory(symbol: symbol)
        }.value
        if Task.isCancelled { return }
        
        // Yield after blocking call to allow UI updates
        await Task.yield()
        
        if let fetchedPriceHistory {
            let fetchedATRValue = await Task.detached(priority: .low) {
                return SchwabClient.shared.computeATR(symbol: symbol)
            }.value
            if Task.isCancelled { return }
            
            await MainActor.run {
                _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .priceHistory) { snapshot in
                    snapshot.priceHistory = fetchedPriceHistory
                    snapshot.atrValue = fetchedATRValue
                }
            }
        }
        
        // Fetch transactions in background
        if Task.isCancelled { return }
        print("🔮 [First Security] Fetching transactions for: \(symbol)")
        let fetchedTransactions = await Task.detached(priority: .low) {
            return SchwabClient.shared.getTransactionsFor(symbol: symbol)
        }.value
        if Task.isCancelled { return }
        
        // Yield after blocking call to allow UI updates
        await Task.yield()
        
        await MainActor.run {
            _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .transactions) { snapshot in
                snapshot.transactions = fetchedTransactions
            }
        }
        print("🔮 [First Security] Transactions complete for \(symbol): \(fetchedTransactions.count) transactions")
        
        // Fetch tax lots in background
        if Task.isCancelled { return }
        let currentPrice = fetchedQuote?.quote?.lastPrice ?? fetchedQuote?.extended?.lastPrice ?? fetchedPriceHistory?.candles.last?.close
        let fetchedTaxLots = await Task.detached(priority: .low) {
            return SchwabClient.shared.computeTaxLots(symbol: symbol, currentPrice: currentPrice)
        }.value
        if Task.isCancelled { return }
        let fetchedSharesAvailable = await Task.detached(priority: .low) {
            return SchwabClient.shared.computeSharesAvailableForTrading(symbol: symbol, taxLots: fetchedTaxLots)
        }.value
        
        await MainActor.run {
            _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .taxLots) { snapshot in
                snapshot.taxLotData = fetchedTaxLots
                snapshot.sharesAvailableForTrading = fetchedSharesAvailable
            }
        }
        
        print("✅ [First Security] Prefetch complete for \(symbol)")
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
            }
        }
        
        // PRIORITY 3: Fetch transaction history in background (for trade dates and tax lots)
        Task {
            print("🚀 PRIORITY 3: Fetching transaction history in background")
            
            // Fetch first 4 quarters immediately for trade dates (faster than full 12 quarters)
            await SchwabClient.shared.fetchTransactionHistoryReduced(quarters: 4)
            
            // Check for cancellation before updating UI
            guard !Task.isCancelled else { return }
            
            // Update trade dates in UI and populate cache
            await MainActor.run {
                // Populate trade date cache
                for position in holdings {
                    if let symbol = position.instrument?.symbol {
                        tradeDateCache[symbol] = SchwabClient.shared.getLatestTradeDate(for: symbol)
                    }
                }
                
                // Update accountPositions with trade dates
                accountPositions = SchwabClient.shared.getAccounts().flatMap { accountContent in
                    let accountNumber = accountContent.securitiesAccount?.accountNumber ?? ""
                    let lastThreeDigits = String(accountNumber.suffix(3))
                    return accountContent.securitiesAccount?.positions.map {
                        ($0, lastThreeDigits, tradeDateCache[$0.instrument?.symbol ?? ""] ?? "")
                    } ?? []
                }
                print("✅ Trade dates updated and cache populated")
            }
            
            // Fetch remaining quarters in background for complete history (up to maxQuarterDelta)
            let remainingQuarters = max(SchwabClient.shared.maxQuarterDelta - 4, 0)
            if remainingQuarters > 0 {
                print("🚀 Fetching remaining \(remainingQuarters) quarters in background")
                
                // Process in batches of 3 to avoid overwhelming the API
                let batchSize = 3
                for batchStart in stride(from: 0, to: remainingQuarters, by: batchSize) {
                    // Check for cancellation before each batch
                    guard !Task.isCancelled else {
                        print("=== fetchHoldingsAsync - Cancelled during background processing ===")
                        return
                    }
                    
                    let batchEnd = min(batchStart + batchSize, remainingQuarters)
                    let batchSize = batchEnd - batchStart
                    
                    print("📦 Processing background batch \(batchStart/batchSize + 1): quarters \(batchStart+5)-\(batchEnd+4)")
                    
                    // Fetch batch in parallel
                    await withTaskGroup(of: Void.self) { group in
                        for _ in 0..<batchSize {
                            group.addTask {
                                await SchwabClient.shared.fetchTransactionHistory()
                            }
                        }
                        // Wait for all tasks in this batch to complete
                        await group.waitForAll()
                    }
                    
                    // Small delay between batches to be respectful to the API
                    if batchEnd < remainingQuarters {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    }
                }
                
                print("✅ All transaction history loaded")
            }
        }
    }

}
