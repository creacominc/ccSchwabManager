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

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .symbol, .assetType, .account:
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
    @State private var currentSort: SortConfig? = SortConfig(column: .symbol, ascending: SortableColumn.symbol.defaultAscending)
    @State private var selectedAssetTypes: Set<String> = []
    @State private var accountPositions: [(Position, String, String)] = []
    @State private var selectedAccountNumbers: Set<String> = []
    @State private var selectedPosition: SelectedPosition? = nil
    @State private var viewSize: CGSize = .zero
    @StateObject private var viewModel = HoldingsViewModel()
    @State private var isLoadingAccounts = false

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

        return filteredHoldings.sorted { first, second in
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
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack {
                    FilterControls(
                        selectedAssetTypes: $selectedAssetTypes,
                        selectedAccountNumbers: $selectedAccountNumbers,
                        uniqueAssetTypes: viewModel.uniqueAssetTypes,
                        uniqueAccountNumbers: viewModel.uniqueAccountNumbers
                    )

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
                            //                        latestDateForSymbol: latestDateForSymbol,
                            currentSort: $currentSort
                        )
                    }
                }
                .searchable(text: $searchText, prompt: "Search by symbol or description")
                .navigationTitle("Holdings")
                .task {
                    defer { isLoadingAccounts = false }
                    isLoadingAccounts = true
                    await fetchHoldings()
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
                    onNavigate: { newIndex in
                        guard newIndex >= 0 && newIndex < sortedHoldings.count else { return }
                        let newPosition = sortedHoldings[newIndex]
                        let accountNumber = accountPositions.first { $0.0 === newPosition }?.1 ?? ""
                        selectedPosition = SelectedPosition(id: newPosition.id, position: newPosition, accountNumber: accountNumber)
                    }
                )
                .navigationTitle(selected.position.instrument?.symbol ?? "")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            selectedPosition = nil
                        }
                    }
                }
            }
            .frame(width: viewSize.width * 0.8,
                   height: viewSize.height * 0.9)
        }
    }
    
    private func fetchHoldings() async {
        print("=== fetchHoldings ===")
        await SchwabClient.shared.fetchAccounts( retry: true )
        // get the lessor of the last 3000  or 1 year of transactions
        await SchwabClient.shared.fetchTransactionHistory()
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
//    let latestDateForSymbol : [String:Date]
    @Binding var currentSort: SortConfig?
    
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

    private let columnWidths: [CGFloat] = [100, 80, 80, 100, 80, 80, 100, 80, 120]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                columnHeader(title: "Symbol", column: .symbol).frame(width: columnWidths[0])
                columnHeader(title: "Quantity", column: .quantity, alignment: .trailing).frame(width: columnWidths[1])
                columnHeader(title: "Avg Price", column: .avgPrice, alignment: .trailing).frame(width: columnWidths[2])
                columnHeader(title: "Market Value", column: .marketValue, alignment: .trailing).frame(width: columnWidths[3])
                columnHeader(title: "P/L", column: .pl, alignment: .trailing).frame(width: columnWidths[4])
                columnHeader(title: "P/L%", column: .plPercent, alignment: .trailing).frame(width: columnWidths[5])
                columnHeader(title: "Asset Type", column: .assetType).frame(width: columnWidths[6])
                columnHeader(title: "Account", column: .account).frame(width: columnWidths[7])
                columnHeader(title: "Last Trade", column: .lastTradeDate).frame(width: columnWidths[8])
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
            .background(Color.gray.opacity(0.1))
            
            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sortedHoldings) { position in
                        HStack(spacing: 8) {
                            Text(position.instrument?.symbol ?? "").frame(width: columnWidths[0], alignment: .leading)
                            Text(String(format: "%.2f", position.longQuantity ?? 0.0)).frame(width: columnWidths[1], alignment: .trailing)
                            Text(String(format: "%.2f", position.averagePrice ?? 0.0)).frame(width: columnWidths[2], alignment: .trailing).monospacedDigit()
                            Text(String(format: "%.2f", position.marketValue ?? 0.0)).frame(width: columnWidths[3], alignment: .trailing).monospacedDigit()
                            Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0)).frame(width: columnWidths[4], alignment: .trailing).monospacedDigit()
                            Text(String(format: "%.1f%%", calcPLPercent(position: position))).frame(width: columnWidths[5], alignment: .trailing).monospacedDigit()
                            Text(position.instrument?.assetType?.rawValue ?? "").frame(width: columnWidths[6], alignment: .leading)
                            Text(accountNumberFor(position)).frame(width: columnWidths[7], alignment: .leading)
                            Text( SchwabClient.shared.getLatestTradeDate( for:  position.instrument?.symbol ?? "" ) ).frame(width: columnWidths[8], alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedPositionId = position.id
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private func calcPLPercent(position: Position) -> Double {
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        return costBasis != 0 ? (pl / costBasis) * 100 : 0
    }

    private func accountNumberFor(_ position: Position) -> String {
        accountPositions.first { $0.0.id == position.id }?.1 ?? ""
    }
} 
