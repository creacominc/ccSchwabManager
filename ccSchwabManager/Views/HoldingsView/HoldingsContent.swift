//
//  HoldingsContent.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

struct HoldingsContent: View {
    let isLoadingAccounts: Bool
    let sortedHoldings: [Position]
    let onPositionSelected: (Position.ID, Position, String) -> Void
    let accountPositions: [(Position, String, String)]
    let currentSort: Binding<SortConfig?>
    let viewSize: CGSize
    let tradeDateCache: [String: String]
    let orderStatusCache: [String: ActiveOrderStatus?]
    
    var body: some View {
        if isLoadingAccounts {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(2.0, anchor: .center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            Spacer()
            HoldingsTable(
                sortedHoldings: sortedHoldings,
                selectedPositionId: Binding(
                    get: { nil },
                    set: { newId in
                        if let newId = newId,
                           let position = sortedHoldings.first(where: { $0.id == newId }),
                           let accountNumber = accountPositions.first(where: { $0.0.id == newId })?.1 {
                            onPositionSelected(newId, position, accountNumber)
                        }
                    }
                ),
                accountPositions: accountPositions,
                currentSort: currentSort,
                viewSize: viewSize,
                tradeDateCache: tradeDateCache,
                orderStatusCache: orderStatusCache,
            )
            .padding(5)
        }
    }
}
