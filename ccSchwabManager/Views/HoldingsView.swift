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
    @State private var filterText = ""
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
            let matchesText = filterText.isEmpty ||
                (position.instrument?.symbol?.localizedCaseInsensitiveContains(filterText) ?? false) ||
                (position.instrument?.description?.localizedCaseInsensitiveContains(filterText) ?? false)
            
            let matchesAssetType = (position.instrument?.assetType?.rawValue).map { selectedAssetTypes.contains($0) } ?? false
            
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
                        filterText: $filterText,
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
                .searchable(text: $searchText)
                .navigationTitle("Holdings")
                .modifier(SortColumnChangeHandler(selectedSortColumn: $selectedSortColumn, sortDirection: $sortDirection))
                .modifier(SearchTextChangeHandler(searchText: $searchText, filterText: $filterText))
                .task {
                    await fetchHoldings()
                    selectedAssetTypes = Set(viewModel.uniqueAssetTypes.filter { $0 == "EQUITY" })
                }
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { newSize in
                    viewSize = newSize
                }
            }
        }
        .sheet(item: $selectedPosition) { selected in
            PositionDetailView(position: selected.position, accountNumber: selected.accountNumber)
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
        let schwabClient = SchwabClient(secrets: &secretsManager.secrets)
        await schwabClient.fetchAccounts()
        
        // Extract positions from accounts with their account numbers
        accountPositions = schwabClient.getAccounts().flatMap { accountContent in
            let accountNumber = accountContent.securitiesAccount?.accountNumber ?? ""
            let lastThreeDigits = String(accountNumber.suffix(3))
            return accountContent.securitiesAccount?.positions.map { ($0, lastThreeDigits) } ?? []
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
        if #available(macOS 14.0, *) {
            content.onChange(of: selectedSortColumn) { oldValue, newValue in
                sortDirection = "Ascending"
            }
        } else {
            content.onChange(of: selectedSortColumn) { _ in
                sortDirection = "Ascending"
            }
        }
    }
}

struct SearchTextChangeHandler: ViewModifier {
    @Binding var searchText: String
    @Binding var filterText: String
    
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.onChange(of: searchText) { oldValue, newValue in
                filterText = newValue
            }
        } else {
            content.onChange(of: searchText) { newValue in
                filterText = newValue
            }
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
        }
    }
} 
