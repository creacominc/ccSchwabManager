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

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .symbol, .assetType, .account, .orderStatus:
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
            switch sortConfig.column {
            case .symbol:
                return ascending ?
                    (first.instrument?.symbol ?? "") < (second.instrument?.symbol ?? "") :
                    (first.instrument?.symbol ?? "") > (second.instrument?.symbol ?? "")
            case .quantity:
                return ascending ?
                    (first.longQuantity ?? 0) < (second.longQuantity ?? 0) :
                    (first.longQuantity ?? 0) > (second.longQuantity ?? 0)
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
                                if let id = newId,
                                   let position = sortedHoldings.first(where: { $0.id == id }) {
                                    let accountNumber = accountPositions.first { $0.0 === position }?.1 ?? ""
                                    selectedPosition = SelectedPosition(id: id, position: position, accountNumber: accountNumber)
                                } else {
                                    selectedPosition = nil
                                }
                            }
                        ),
                        accountPositions: accountPositions,
                        currentSort: $currentSort,
                        viewSize: viewSize,
                        tradeDateCache: tradeDateCache,
                        orderStatusCache: orderStatusCache
                    )
                    .padding()
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
            .onChange(of: geometry.size) { oldValue, newValue in
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
            .onChange(of: selected.position.instrument?.symbol) { oldValue, newValue in
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
}

struct HoldingsTable: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String, String)]
    @Binding var currentSort: SortConfig?
    let viewSize: CGSize
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]

    private let columnWidths: [CGFloat] = [0.12, 0.07, 0.07, 0.09, 0.07, 0.07, 0.09, 0.07, 0.08, 0.08]

    var body: some View {
        VStack(spacing: 0) {
            TableHeader(currentSort: $currentSort, viewSize: viewSize, columnWidths: columnWidths)
            Divider()
            TableContent(
                sortedHoldings: sortedHoldings,
                selectedPositionId: $selectedPositionId,
                accountPositions: accountPositions,
                viewSize: viewSize,
                columnWidths: columnWidths,
                tradeDateCache: tradeDateCache,
                orderStatusCache: orderStatusCache
            )
        }
    }
}

private struct TableHeader: View {
    @Binding var currentSort: SortConfig?
    let viewSize: CGSize
    let columnWidths: [CGFloat]

    @ViewBuilder
    private func columnHeader(title: String, column: SortableColumn, alignment: Alignment = .leading) -> some View {
        Button(action: {
            if currentSort?.column == column {
                currentSort?.ascending.toggle()
            } else {
                currentSort = SortConfig(column: column, ascending: column.defaultAscending)
            }
        }) {
            HStack {
                if alignment == .trailing {
                    Spacer()
                }
                Text(title)
                if alignment == .leading {
                    Spacer()
                }
                if currentSort?.column == column {
                    Image(systemName: currentSort?.ascending ?? true ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        HStack(spacing: 8) {
            columnHeader(title: "Symbol", column: .symbol).frame(width: columnWidths[0] * viewSize.width)
            columnHeader(title: "Quantity", column: .quantity, alignment: .trailing).frame(width: columnWidths[1] * viewSize.width)
            columnHeader(title: "Avg Price", column: .avgPrice, alignment: .trailing).frame(width: columnWidths[2] * viewSize.width)
            columnHeader(title: "Market Value", column: .marketValue, alignment: .trailing).frame(width: columnWidths[3] * viewSize.width)
            columnHeader(title: "P/L", column: .pl, alignment: .trailing).frame(width: columnWidths[4] * viewSize.width)
            columnHeader(title: "P/L%", column: .plPercent, alignment: .trailing).frame(width: columnWidths[5] * viewSize.width)
            columnHeader(title: "Asset Type", column: .assetType).frame(width: columnWidths[6] * viewSize.width)
            columnHeader(title: "Account", column: .account).frame(width: columnWidths[7] * viewSize.width)
            columnHeader(title: "Last Trade", column: .lastTradeDate).frame(width: columnWidths[8] * viewSize.width)
            columnHeader(title: "Order Status", column: .orderStatus ).frame(width: columnWidths[9] * viewSize.width)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
    }
}

private struct TableContent: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String, String)]
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]

    private func accountNumberFor(_ position: Position) -> String {
        accountPositions.first { $0.0.id == position.id }?.1 ?? ""
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedHoldings) { position in
                    TableRow(
                        position: position,
                        accountNumber: accountNumberFor(position),
                        viewSize: viewSize,
                        columnWidths: columnWidths,
                        onTap: { selectedPositionId = position.id },
                        tradeDate: tradeDateCache[position.instrument?.symbol ?? ""] ?? "0000",
                        orderStatus: orderStatusCache[position.instrument?.symbol ?? ""] ?? nil
                    )
                    Divider()
                }
            }
        }
    }
}

private struct TableRow: View {
    let position: Position
    let accountNumber: String
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    let onTap: () -> Void
    let tradeDate: String
    let orderStatus: ActiveOrderStatus?

    private var plPercent: Double {
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        return costBasis != 0 ? (pl / costBasis) * 100 : 0
    }

    private var plColor: Color {
        if plPercent < 0 {
            return .red
        } else if plPercent < 6 {
            return .orange // Amber-like color
        } else {
            return .primary
        }
    }
    
    private var orderStatusText: String {
        return orderStatus?.shortDisplayName ?? "None"
    }
    
    private var orderStatusColor: Color {
        guard let status = orderStatus else { return .secondary }
        
        switch status {
        case .working:
            return .green
        case .awaitingStopCondition, .awaitingCondition:
            return .orange
        case .awaitingManualReview:
            return .red
        default:
            return .blue
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(position.instrument?.symbol ?? "").frame(width: columnWidths[0] * viewSize.width, alignment: .leading)
            Text(String(format: "%.2f", position.longQuantity ?? 0.0)).frame(width: columnWidths[1] * viewSize.width, alignment: .trailing)
            Text(String(format: "%.2f", position.averagePrice ?? 0.0)).frame(width: columnWidths[2] * viewSize.width, alignment: .trailing).monospacedDigit()
            Text(String(format: "%.2f", position.marketValue ?? 0.0)).frame(width: columnWidths[3] * viewSize.width, alignment: .trailing).monospacedDigit()
            Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0))
                .frame(width: columnWidths[4] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor)
            Text(String(format: "%.1f%%", plPercent))
                .frame(width: columnWidths[5] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor)
            Text(position.instrument?.assetType?.rawValue ?? "").frame(width: columnWidths[6] * viewSize.width, alignment: .leading)
            Text(accountNumber).frame(width: columnWidths[7] * viewSize.width, alignment: .leading)
            Text(tradeDate).frame(width: columnWidths[8] * viewSize.width, alignment: .leading)
            Text(orderStatusText)
                .frame(width: columnWidths[9] * viewSize.width, alignment: .trailing)
                .foregroundColor(orderStatusColor)
                .font(.system(.body, design: .monospaced))
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
} 
