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

    var filteredHoldings: [Position] {
        holdings.filter { position in
            searchText.isEmpty ||
            ((position.instrument?.symbol?.localizedCaseInsensitiveContains(searchText)) != nil) ||
            ((position.instrument?.description?.localizedCaseInsensitiveContains(searchText)) != nil)
        }
    }

    var body: some View {
        NavigationView {
            Table(filteredHoldings, sortOrder: $sortOrder) {
                TableColumn("Symbol") { position in
                    Text(position.instrument?.symbol ?? "")
                }
                TableColumn("Description") { position in
                    Text(position.instrument?.description ?? "")
                }
                TableColumn("Quantity") { position in
                    Text(String(format: "%.2f", position.longQuantity ?? 0.0))
                }
                TableColumn("Avg Price") { position in
                    Text(String(format: "%.2f", position.averagePrice ?? 0.0))
                }
                TableColumn("Market Value") { position in
                    Text(String(format: "%.2f", position.marketValue ?? 0.0))
                }
                TableColumn("P/L") { position in
                    Text(String(format: "%.2f", position.longOpenProfitLoss ?? 0.0))
                }
                TableColumn("Asset Type") { position in
                    Text(position.instrument?.assetType?.rawValue ?? "")
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Holdings")
        }
        .task {
            // Fetch holdings when view appears
            await fetchHoldings()
        }
    }
    
    private func fetchHoldings() async {
        print("=== fetchHoldings ===")
        let schwabClient = SchwabClient(secrets: &secretsManager.secrets)
        await schwabClient.fetchAccounts()
        
        // Extract positions from accounts
        holdings = schwabClient.getAccounts().flatMap { $0.securitiesAccount?.positions ?? [] }
        print("count of holding: \(holdings.count)")
    }
} 