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
 *   - Search bar for filtering holdings
 * 
 * Functionality:
 * - Automatically fetches holdings when view appears
 * - Supports sorting by any column
 * - Allows searching by symbol or description
 * - Displays formatted numbers with 2 decimal places
 * - Handles optional values with empty string fallbacks
 */

struct HoldingsView: View {
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var holdings: [Position] = []
    @State private var searchText = ""
    @State private var currentSort: SortConfig? = SortConfig(column: .lastTradeDate, ascending: SortableColumn.lastTradeDate.defaultAscending)
    @State private var selectedAssetTypes: Set<String> = []
    @State private var accountPositions: [(Position, String, String)] = []
    @State private var selectedAccountNumbers: Set<String> = []
    @State private var selectedPosition: SelectedPosition? = nil
    @State private var viewSize: CGSize = .zero
    @StateObject private var viewModel = HoldingsViewModel()
    @State private var isLoadingAccounts = false
    @State private var isFilterExpanded = false
    @State private var atrValue: Double = 0.0
    @State private var selectedTab: Int = 0
    @StateObject private var loadingState = LoadingState()
    
    // Cache for trade dates and order status to prevent loops
    @State private var tradeDateCache: [String: String] = [:]
    @State private var orderStatusCache: [String: ActiveOrderStatus?] = [:]
    @State private var dteCache: [String: Int?] = [:]

    struct SelectedPosition: Identifiable {
        let id: Position.ID
        let position: Position
        let accountNumber: String
    }

    var filteredHoldings: [Position] {
        holdings.filter { position in
            let matchesText = searchText.isEmpty ||
                (position.instrument?.symbol?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (position.instrument?.description?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesAssetType = selectedAssetTypes.isEmpty || 
                (position.instrument?.assetType?.rawValue).map { selectedAssetTypes.contains($0) } ?? false
            
            let accountInfo = accountPositions.first { $0.0 === position }
            let matchesAccount = selectedAccountNumbers.isEmpty || 
                (accountInfo?.1).map { selectedAccountNumbers.contains($0) } ?? false
            return matchesText && matchesAssetType && matchesAccount
        }
    }

    var sortedHoldings: [Position] {
        guard let sortConfig = currentSort else { return filteredHoldings }
        return filteredHoldings.sorted(by: { first, second in
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
                let firstAccount = accountPositions.first { $0.0 === first }?.1 ?? ""
                let secondAccount = accountPositions.first { $0.0 === second }?.1 ?? ""
                return ascending ? firstAccount < secondAccount : firstAccount > secondAccount
            case .lastTradeDate:
                let firstSymbol = first.instrument?.symbol ?? ""
                let secondSymbol = second.instrument?.symbol ?? ""
                let firstDate = tradeDateCache[firstSymbol] ?? "0000"
                let secondDate = tradeDateCache[secondSymbol] ?? "0000"
                return ascending ? firstDate < secondDate : firstDate > secondDate
            case .orderStatus:
                let firstSymbol = first.instrument?.symbol ?? ""
                let secondSymbol = second.instrument?.symbol ?? ""
                let firstOrderStatus = orderStatusCache[firstSymbol] ?? nil
                let secondOrderStatus = orderStatusCache[secondSymbol] ?? nil
                
                // Sort by priority (lower number = higher priority)
                let firstPriority = firstOrderStatus?.priority ?? Int.max
                let secondPriority = secondOrderStatus?.priority ?? Int.max
                
                return ascending ? firstPriority < secondPriority : firstPriority > secondPriority
            case .dte:
                let firstDTE = calculateDTE(for: first)
                let secondDTE = calculateDTE(for: second)
                
                // Handle nil values - positions without contracts go to the end
                if firstDTE == nil && secondDTE == nil {
                    return false // Keep original order
                } else if firstDTE == nil {
                    return false // First goes after second
                } else if secondDTE == nil {
                    return true // Second goes after first
                } else {
                    return ascending ? firstDTE! < secondDTE! : firstDTE! > secondDTE!
                }
            }
        })
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                // Filter section with disclosure button
                VStack(spacing: 0) {
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
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                    }
                    .buttonStyle(.plain)
                    
                    if isFilterExpanded {
                        FilterControls(
                            selectedAssetTypes: $selectedAssetTypes,
                            selectedAccountNumbers: $selectedAccountNumbers,
                            uniqueAssetTypes: viewModel.uniqueAssetTypes,
                            uniqueAccountNumbers: viewModel.uniqueAccountNumbers
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
                    HoldingsTable(
                        sortedHoldings: sortedHoldings,
                        selectedPositionId: Binding(
                            get: { selectedPosition?.id },
                            set: { newId in
                                if let newId = newId,
                                   let position = sortedHoldings.first(where: { $0.id == newId }),
                                   let accountNumber = accountPositions.first(where: { $0.0.id == newId })?.1 {
                                    selectedPosition = SelectedPosition(id: newId, position: position, accountNumber: accountNumber)
                                }
                            }
                        ),
                        accountPositions: accountPositions,
                        currentSort: $currentSort,
                        viewSize: viewSize,
                        tradeDateCache: tradeDateCache,
                        orderStatusCache: orderStatusCache,
                        dteCache: dteCache
                    )
                }
            } // VStack
            .searchable(text: $searchText, prompt: "Search by symbol or description")
            //.navigationTitle("Holdings")
            .task {
                defer { isLoadingAccounts = false }
                isLoadingAccounts = true
                // Connect loading state to SchwabClient
                //print("🔗 HoldingsView - Setting SchwabClient.loadingDelegate")
                SchwabClient.shared.loadingDelegate = loadingState
                fetchHoldings()
                selectedAssetTypes = Set(viewModel.uniqueAssetTypes.filter { $0 == "EQUITY" })
            }
            .onDisappear {
                //print("🔗 HoldingsView - Clearing SchwabClient.loadingDelegate")
                SchwabClient.shared.loadingDelegate = nil
            }
            .onAppear {
                viewSize = geometry.size
            }
            .onChange(of: geometry.size) { _, newValue in
                viewSize = newValue
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
                onNavigate: { newIndex in
                    guard newIndex >= 0 && newIndex < sortedHoldings.count else { return }
                    let newPosition = sortedHoldings[newIndex]
                    let accountNumber = accountPositions.first { $0.0 === newPosition }?.1 ?? ""
                    selectedPosition = SelectedPosition(id: newPosition.id, position: newPosition, accountNumber: accountNumber)
                },
                selectedTab: $selectedTab
            )
            .task {
                if let tmpsymbol = selected.position.instrument?.symbol {
                    atrValue = await SchwabClient.shared.computeATR(symbol: tmpsymbol)
                }
            }
            .onChange(of: selected.position.instrument?.symbol) { _, newValue in
                if let tmpsymbol = newValue {
                    Task {
                        atrValue = await SchwabClient.shared.computeATR(symbol: tmpsymbol)
                    }
                }
            }
            .frame(width: viewSize.width * 0.97,
                   height: viewSize.height * 0.92)
        }
        .withLoadingState(loadingState)
    }
    
    private func fetchHoldings()  {
        print("=== fetchHoldings - Starting optimized data loading ===")
        
        // PRIORITY 1: Fetch accounts immediately (needed for holdings display)
        Task {
            print("🚀 PRIORITY 1: Fetching accounts for holdings display")
            await SchwabClient.shared.fetchAccounts(retry: true)
            
            // Update UI immediately with holdings data
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
                
                // Populate DTE cache
                for position in holdings {
                    if let symbol = position.instrument?.symbol {
                        dteCache[symbol] = calculateDTE(for: position)
                    }
                }
                
                print("✅ Holdings displayed: \(holdings.count) positions")
            }
        }
        
        // PRIORITY 2: Fetch order history in parallel (needed for "Orders" column)
        Task {
            print("🚀 PRIORITY 2: Fetching order history in parallel")
            await SchwabClient.shared.fetchOrderHistory()
            
            // Update order information in UI and populate cache
            await MainActor.run {
                // Populate order status cache
                for position in holdings {
                    if let symbol = position.instrument?.symbol {
                        orderStatusCache[symbol] = SchwabClient.shared.getPrimaryOrderStatus(symbol: symbol)
                    }
                }
                print("✅ Order history loaded and cache populated")
            }
        }
        
        // PRIORITY 3: Fetch transaction history in background (for trade dates and tax lots)
        Task {
            print("🚀 PRIORITY 3: Fetching transaction history in background")
            
            // Fetch first 4 quarters immediately for trade dates (faster than full 12 quarters)
            await SchwabClient.shared.fetchTransactionHistoryReduced(quarters: 4)
            
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
            
            // Fetch remaining quarters in background for complete history
            let remainingQuarters = min(SchwabClient.shared.maxQuarterDelta - 4, 8 )
            if remainingQuarters > 0 {
                print("🚀 Fetching remaining \(remainingQuarters) quarters in background")
                
                // Process in batches of 3 to avoid overwhelming the API
                let batchSize = 3
                for batchStart in stride(from: 0, to: remainingQuarters, by: batchSize) {
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
    
    // Helper function to calculate DTE for a position
    private func calculateDTE(for position: Position) -> Int? {
        // For option positions, calculate DTE directly from the position
        // For equity positions, look up contracts using the position's symbol
        if position.instrument?.assetType == .OPTION {
            // Calculate DTE directly from the option position
            let expirationDate = extractExpirationDate(from: position.instrument?.symbol, description: position.instrument?.description)
            
            guard let expirationDate = expirationDate else { 
                print("⚠️ calculateDTE: Could not extract expiration date for option position: \(position.instrument?.symbol ?? "nil")")
                return nil 
            }
            
            let calendar = Calendar.current
            let today = Date()
            let components = calendar.dateComponents([.day], from: today, to: expirationDate)
            let dte = components.day ?? 0
            
            print("📅 calculateDTE: Option position \(position.instrument?.symbol ?? "nil") has DTE: \(dte)")
            return dte
        } else {
            // For equity positions, look up contracts using the position's symbol
            let lookupSymbol = position.instrument?.symbol ?? ""
            
            print("🔍 calculateDTE: Equity position symbol: \(position.instrument?.symbol ?? "nil"), Lookup symbol: \(lookupSymbol)")
            
            guard !lookupSymbol.isEmpty,
                  let contracts = SchwabClient.shared.getContractsForSymbol(lookupSymbol),
                  !contracts.isEmpty else {
                print("❌ calculateDTE: No contracts found for equity symbol: \(lookupSymbol)")
                return nil
            }
            
            print("✅ calculateDTE: Found \(contracts.count) contracts for equity symbol: \(lookupSymbol)")
            
            var minDTE: Int?
            let calendar = Calendar.current
            let today = Date()
            
            for contract in contracts {
                // Try to extract expiration date from symbol first, then description
                let expirationDate = extractExpirationDate(from: contract.instrument?.symbol, description: contract.instrument?.description)
                
                guard let expirationDate = expirationDate else { 
                    print("⚠️ calculateDTE: Could not extract expiration date for contract: \(contract.instrument?.symbol ?? "nil")")
                    continue 
                }
                
                print("📅 calculateDTE: Processing contract \(contract.instrument?.symbol ?? "nil") with expiration: \(expirationDate)")
                
                let components = calendar.dateComponents([.day], from: today, to: expirationDate)
                let dte = components.day ?? 0
                
                print("📊 calculateDTE: Contract \(contract.instrument?.symbol ?? "nil") has DTE: \(dte)")
                
                if minDTE == nil || dte < minDTE! {
                    minDTE = dte
                    print("🏆 calculateDTE: New minimum DTE: \(dte) for equity symbol: \(lookupSymbol)")
                }
            }
            
            print("🎯 calculateDTE: Final DTE for equity \(lookupSymbol): \(minDTE ?? -1)")
            return minDTE
        }
    }
    
    // Helper function to extract expiration date from option symbol or description
    private func extractExpirationDate(from symbol: String?, description: String?) -> Date? {
        // First try to extract from symbol (format: "INTC  250516C00025000")
        if let symbol = symbol, symbol.count >= 6 {
            // Look for 6 digits after the underlying symbol
            let pattern = "\\d{6}"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: symbol, range: NSRange(symbol.startIndex..., in: symbol)) {
                let dateString = String(symbol[Range(match.range, in: symbol)!])
                
                // Parse the date string (format: YYMMDD)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyMMdd"
                formatter.timeZone = TimeZone.current
                
                if let date = formatter.date(from: dateString) {
                    print("📅 extractExpirationDate: Extracted date \(date) from symbol \(symbol)")
                    return date
                }
            }
        }
        
        // If symbol parsing failed, try description (format: "INTEL CORP 05/16/2025 $25 Call")
        if let description = description {
            // Look for date pattern MM/DD/YYYY
            let pattern = "(\\d{1,2})/(\\d{1,2})/(\\d{4})"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
                
                let monthRange = Range(match.range(at: 1), in: description)!
                let dayRange = Range(match.range(at: 2), in: description)!
                let yearRange = Range(match.range(at: 3), in: description)!
                
                let month = String(description[monthRange])
                let day = String(description[dayRange])
                let year = String(description[yearRange])
                
                let dateString = "\(month)/\(day)/\(year)"
                let formatter = DateFormatter()
                formatter.dateFormat = "M/d/yyyy"
                formatter.timeZone = TimeZone.current
                
                if let date = formatter.date(from: dateString) {
                    print("📅 extractExpirationDate: Extracted date \(date) from description \(description)")
                    return date
                }
            }
        }
        
        print("❌ extractExpirationDate: Could not extract date from symbol: \(symbol ?? "nil") or description: \(description ?? "nil")")
        return nil
    }
} 
