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
    case orders = "Orders"

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .symbol, .assetType, .account, .orders:
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
//    @State private var sellOrder: SalesCalcResultsRecord
//    @State private var copiedValue: String
    @State private var atrValue: Double = 0.0

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
//            let orders = SchwabClient.shared.hasOrders( symbol: position.instrument?.symbol )
            return matchesText && matchesAssetType && matchesAccount // && orders
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
                let firstDate : String   = SchwabClient.shared.getLatestTradeDate( for: first.instrument?.symbol ?? "" )
                let secondDate : String  = SchwabClient.shared.getLatestTradeDate( for: second.instrument?.symbol ?? "" )
                return ascending ?
                    (firstDate) < (secondDate) :
                    (firstDate) > (secondDate)
            case .orders:
                let firstHasOrders: Bool = SchwabClient.shared.hasOrders(symbol: first.instrument?.symbol ?? "")
                let secondHasOrders: Bool = SchwabClient.shared.hasOrders(symbol: second.instrument?.symbol ?? "")
                return ascending ?
                    (!firstHasOrders && secondHasOrders) :
                    (firstHasOrders && !secondHasOrders)
            }
        })
    }

    var body: some View {
        NavigationStack {
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
                            viewSize: viewSize
                        )
                        .padding()
                    }
                } // VStack
                .searchable(text: $searchText, prompt: "Search by symbol or description")
                //.navigationTitle("Holdings")
                .task {
                    defer { isLoadingAccounts = false }
                    isLoadingAccounts = true
                    fetchHoldings()
                    selectedAssetTypes = Set(viewModel.uniqueAssetTypes.filter { $0 == "EQUITY" })
                }
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { oldValue, newValue in
                    viewSize = newValue
                }
            }
        }
        .sheet(item: $selectedPosition) { selected in
            let currentIndex = sortedHoldings.firstIndex(where: { $0.id == selected.id }) ?? 0
            NavigationStack {
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
                    }
                )
                #if !os(iOS)
                //.navigationTitle(selected.position.instrument?.symbol ?? "")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            selectedPosition = nil
                        }
                    }
                }
                #endif
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
            }
            .frame(width: viewSize.width * 0.97,
                   height: viewSize.height * 0.92)
        }
    }
    
    private func fetchHoldings()  {
        print("=== fetchHoldings ===")
        SchwabClient.shared.fetchAccounts( retry: true )
        // get the first year of transactions sychronously so that sorting is done correctly
        SchwabClient.shared.fetchTransactionHistorySync()
        // fetch three more quarters of transactions by calling fetchTransactionHistory three times asynchronously
        Task {
            // print( " !!!!!!!!!!!!!!!! using maxQuarterDelta of \(SchwabClient.shared.maxQuarterDelta - 1)" )
            for _ in 0..<( min(SchwabClient.shared.maxQuarterDelta, 11) ) {
                // sleep for 250 ms
                try await Task.sleep(nanoseconds: 250_000_000)
                await SchwabClient.shared.fetchTransactionHistory()
            }
        }
        // get the order history for all accounts and all symbols (there is no per-symbol option)
        SchwabClient.shared.fetchOrderHistory()
        // Extract positions from accounts with their account numbers
        accountPositions = SchwabClient.shared.getAccounts().flatMap { accountContent in
            let accountNumber = accountContent.securitiesAccount?.accountNumber ?? ""
            let lastThreeDigits = String(accountNumber.suffix(3))
            return accountContent.securitiesAccount?.positions.map {
                ($0, lastThreeDigits
                 , SchwabClient.shared.getLatestTradeDate( for: $0.instrument?.symbol ?? "" )
                ) } ?? []
        }
        holdings = accountPositions.map { $0.0 }
        viewModel.updateUniqueValues(holdings: holdings, accountPositions: accountPositions)
        print("count of holding: \(holdings.count)")
    }
}

struct HoldingsTable: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String, String)]
    @Binding var currentSort: SortConfig?
    let viewSize: CGSize

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
                columnWidths: columnWidths
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
            columnHeader(title: "Orders", column: .orders ).frame(width: columnWidths[9] * viewSize.width)
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

    private func calcPLPercent(position: Position) -> Double {
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        return costBasis != 0 ? (pl / costBasis) * 100 : 0
    }

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
                        onTap: { selectedPositionId = position.id }
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

    private func calcPLPercent(position: Position) -> Double {
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        return costBasis != 0 ? (pl / costBasis) * 100 : 0
    }

    private func plColor(_ percent: Double) -> Color {
        if percent < 0 {
            return .red
        } else if percent < 7 {
            return .orange // Amber-like color
        } else {
            return .primary
        }
    }

    var body: some View {
        let plPercent = calcPLPercent(position: position)
        HStack(spacing: 8) {
            Text(position.instrument?.symbol ?? "").frame(width: columnWidths[0] * viewSize.width, alignment: .leading)
            Text(String(format: "%.2f", position.longQuantity ?? 0.0)).frame(width: columnWidths[1] * viewSize.width, alignment: .trailing)
            Text(String(format: "%.2f", position.averagePrice ?? 0.0)).frame(width: columnWidths[2] * viewSize.width, alignment: .trailing).monospacedDigit()
            Text(String(format: "%.2f", position.marketValue ?? 0.0)).frame(width: columnWidths[3] * viewSize.width, alignment: .trailing).monospacedDigit()
            Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0))
                .frame(width: columnWidths[4] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor(plPercent))
            Text(String(format: "%.1f%%", plPercent))
                .frame(width: columnWidths[5] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundColor(plColor(plPercent))
            Text(position.instrument?.assetType?.rawValue ?? "").frame(width: columnWidths[6] * viewSize.width, alignment: .leading)
            Text(accountNumber).frame(width: columnWidths[7] * viewSize.width, alignment: .leading)
            Text(SchwabClient.shared.getLatestTradeDate(for: position.instrument?.symbol ?? "")).frame(width: columnWidths[8] * viewSize.width, alignment: .leading)
            Text(SchwabClient.shared.hasOrders(symbol: position.instrument?.symbol ?? "") ? "Yes" : "No" ).frame(width: columnWidths[9] * viewSize.width, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
} 
