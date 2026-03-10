//
//  HoldingsFilterSection.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

struct HoldingsFilterSection: View {
    @Binding var isFilterExpanded: Bool
    @Binding var selectedAssetTypes: Set<AssetType>
    @Binding var selectedAccountNumbers: Set<String>
    @Binding var selectedOrderStatuses: Set<ActiveOrderStatus>
    @Binding var includeNAStatus: Bool
    @Binding var showPerformanceSummary: Bool
    @Binding var isRefreshing: Bool
    @Binding var isLoadingAccounts: Bool
    
    let uniqueAssetTypes: [AssetType]
    let uniqueAccountNumbers: [String]
    let uniqueOrderStatuses: [ActiveOrderStatus]
    
    let onRefresh: () -> Void
    
    var body: some View {
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
                
                Button(action: onRefresh) {
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
                    uniqueAssetTypes: uniqueAssetTypes,
                    uniqueAccountNumbers: uniqueAccountNumbers,
                    uniqueOrderStatuses: uniqueOrderStatuses
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
