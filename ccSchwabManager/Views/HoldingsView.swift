//
//  HoldingsView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

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
    @State private var sortOrder: [KeyPathComparator<Position>] = []
    @State private var searchText = ""
    @State private var selectedSortColumn = "Symbol"
    @State private var sortDirection = "Ascending"
    @State private var selectedAssetTypes: Set<String> = []
    @State private var accountPositions: [(Position, String)] = []
    @State private var selectedAccountNumbers: Set<String> = []
    @State private var selectedPosition: SelectedPosition? = nil
    @State private var viewSize: CGSize = .zero
    @StateObject private var viewModel = HoldingsViewModel()

    struct SelectedPosition: Identifiable {
        let id: Position.ID
        let position: Position
        let accountNumber: String
    }

    enum SortColumn: String, CaseIterable {
        case symbol = "Symbol"
        case quantity = "Quantity"
        case avgPrice = "Avg Price"
        case marketValue = "Market Value"
        case pl = "P/L"
        case plPercent = "P/L%"
        case assetType = "Asset Type"
        case account = "Account"
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
        let sorted = filteredHoldings.sorted { first, second in
            let ascending = sortDirection == "Ascending"
            switch selectedSortColumn {
            case "Symbol":
                return ascending ? 
                    (first.instrument?.symbol ?? "") < (second.instrument?.symbol ?? "") :
                    (first.instrument?.symbol ?? "") > (second.instrument?.symbol ?? "")
            case "Quantity":
                return ascending ?
                    (first.longQuantity ?? 0) < (second.longQuantity ?? 0) :
                    (first.longQuantity ?? 0) > (second.longQuantity ?? 0)
            case "Avg Price":
                return ascending ?
                    (first.averagePrice ?? 0) < (second.averagePrice ?? 0) :
                    (first.averagePrice ?? 0) > (second.averagePrice ?? 0)
            case "Market Value":
                return ascending ?
                    (first.marketValue ?? 0) < (second.marketValue ?? 0) :
                    (first.marketValue ?? 0) > (second.marketValue ?? 0)
            case "P/L":
                return ascending ?
                    (first.longOpenProfitLoss ?? 0) < (second.longOpenProfitLoss ?? 0) :
                    (first.longOpenProfitLoss ?? 0) > (second.longOpenProfitLoss ?? 0)
            case "P/L%":
                let firstPL = first.longOpenProfitLoss ?? 0
                let secondPL = second.longOpenProfitLoss ?? 0
                let firstMV = first.marketValue ?? 0
                let secondMV = second.marketValue ?? 0
                let firstPLPercent = firstMV != 0 ? firstPL / (firstMV - firstPL) : 0
                let secondPLPercent = secondMV != 0 ? secondPL / (secondMV - secondPL) : 0
                return ascending ? firstPLPercent < secondPLPercent : firstPLPercent > secondPLPercent
            case "Asset Type":
                return ascending ?
                    (first.instrument?.assetType?.rawValue ?? "") < (second.instrument?.assetType?.rawValue ?? "") :
                    (first.instrument?.assetType?.rawValue ?? "") > (second.instrument?.assetType?.rawValue ?? "")
            case "Account":
                let firstAccount = accountPositions.first { $0.0 === first }?.1 ?? ""
                let secondAccount = accountPositions.first { $0.0 === second }?.1 ?? ""
                return ascending ? firstAccount < secondAccount : firstAccount > secondAccount
            default:
                return false
            }
        }
        return sorted
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack {
                    Picker("Sort by", selection: $selectedSortColumn) {
                        ForEach(SortColumn.allCases, id: \.self) { column in
                            Text(column.rawValue).tag(column.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Picker("Direction", selection: $sortDirection) {
                        Text("Ascending").tag("Ascending")
                        Text("Descending").tag("Descending")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    FilterControls(
                        selectedAssetTypes: $selectedAssetTypes,
                        selectedAccountNumbers: $selectedAccountNumbers,
                        uniqueAssetTypes: viewModel.uniqueAssetTypes,
                        uniqueAccountNumbers: viewModel.uniqueAccountNumbers
                    )

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
                        accountPositions: accountPositions
                    )
                }
                .searchable(text: $searchText, prompt: "Search by symbol or description")
                .navigationTitle("Holdings")
                .modifier(SortColumnChangeHandler(selectedSortColumn: $selectedSortColumn, sortDirection: $sortDirection))
                .task {
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
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        selectedPosition = nil
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
        let recentTransactions : [Transaction] = await SchwabClient.shared.fetchTransactionHistory()
        print( " fetched \(recentTransactions.count) transactions)" )
        // create a map of symbols to the most recent trade date
        var latestDateForSymbol : [String:String] = [:]
        for transaction in recentTransactions {
            for transferItem in transaction.transferItems {
                if let symbol = transferItem.instrument?.symbol {
                    // convert tradeDate string to a Date and back to a string with just YYYY-MM-DD
                    var dateStr : String = ""
                    do {
                        let dateDte : Date = try Date( transaction.tradeDate ?? "1970-01-01", strategy: .iso8601.year().month().day() )
                        dateStr = dateDte.formatted(.iso8601.year().month().day())
                        // print( "=== dateStr: \(dateStr), dateDte: \(dateDte) ==" )
                    }
                    catch {
                        print( "Error parsing date: \(error)" )
                        continue
                    }
                    // if the symbol is not in the dictionary, add it with the date.  otherwise compare the date and update only if newer
                    if latestDateForSymbol[symbol] == nil || dateStr > latestDateForSymbol[symbol]! {
                        latestDateForSymbol[symbol] = dateStr
                        // print( "Added or updated \(symbol) at \(dateStr) - latest date \(latestDateForSymbol[symbol] ?? "missing")" )
                    }
                }
            }
        }
        // Extract positions from accounts with their account numbers
        accountPositions = SchwabClient.shared.getAccounts().flatMap { accountContent in
            let accountNumber = accountContent.securitiesAccount?.accountNumber ?? ""
            let lastThreeDigits = String(accountNumber.suffix(3))
            return accountContent.securitiesAccount?.positions.map {
                ($0, lastThreeDigits
                // , latestDateForSymbol[lastThreeDigits] ?? "n/a"
                ) } ?? []
        }
        holdings = accountPositions.map { $0.0 }
        viewModel.updateUniqueValues(holdings: holdings, accountPositions: accountPositions)
        print("count of holding: \(holdings.count)")
    }
}

struct SortColumnChangeHandler: ViewModifier {
    @Binding var selectedSortColumn: String
    @Binding var sortDirection: String
    
    func body(content: Content) -> some View {
        content.onChange(of: selectedSortColumn) { oldValue, newValue in
            sortDirection = "Ascending"
        }
    }
}

struct HoldingsTable: View {
    let sortedHoldings: [Position]
    @Binding var selectedPositionId: Position.ID?
    let accountPositions: [(Position, String)]
    
    var body: some View {
        Table(sortedHoldings, selection: $selectedPositionId) {
            TableColumn("Symbol") { position in
                Text(position.instrument?.symbol ?? "")
            }
            TableColumn("Quantity") { position in
                Text(String(format: "%.2f", position.longQuantity ?? 0.0))
            }
            TableColumn("Avg Price") { position in
                Text(String(format: "%.2f", position.averagePrice ?? 0.0))
                    .monospacedDigit()
            }
            TableColumn("Market Value") { position in
                Text(String(format: "%.2f", position.marketValue ?? 0.0))
                    .monospacedDigit()
            }
            TableColumn("P/L") { position in
                Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0))
                    .monospacedDigit()
            }
            TableColumn("P/L%") { position in
                let pl = position.longOpenProfitLoss ?? 0
                let mv = position.marketValue ?? 0
                let plPercent = mv != 0 ? pl / (mv - pl) * 100 : 0
                Text(String(format: "%.1f%%", plPercent))
                    .monospacedDigit()
            }
            TableColumn("Asset Type") { position in
                Text(position.instrument?.assetType?.rawValue ?? "")
            }
            TableColumn("Account") { position in
                let accountNumber = accountPositions.first { $0.0 === position }?.1 ?? ""
                Text(accountNumber)
            }
//            TableColumn("lastTradeDate") { position in
//                Text( accountPositions.first{ $0.0 === position }?.2 ?? "" )
//            }
        }
    }
} 
