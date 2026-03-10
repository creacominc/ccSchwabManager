//
//  HoldingsViewModifiers.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

extension View {
    func applyMainViewModifiers(
        searchText: Binding<String>,
        isSearchFieldFocused: FocusState<Bool>.Binding,
        isLoadingAccounts: Binding<Bool>,
        sortedHoldings: Binding<[Position]>,
        currentSort: Binding<SortConfig?>,
        selectedAssetTypes: Binding<Set<AssetType>>,
        selectedAccountNumbers: Binding<Set<String>>,
        selectedOrderStatuses: Binding<Set<ActiveOrderStatus>>,
        includeNAStatus: Binding<Bool>,
        isSorting: Binding<Bool>,
        filteredHoldings: [Position],
        loadingState: LoadingState,
        currentFetchTask: Binding<Task<Void, Never>?>,
        onSortChange: @escaping () -> Void,
        onCacheInvalidation: @escaping () -> Void,
        onFetchHoldings: @escaping () async -> Void,
        onSetDefaultAssetTypes: @escaping () -> Void
    ) -> some View {
        self
            .applySearchable(searchText: searchText)
            .applyToolbar(isSearchFieldFocused: isSearchFieldFocused)
            .applyTaskModifier(
                isLoadingAccounts: isLoadingAccounts,
                loadingState: loadingState,
                onFetchHoldings: onFetchHoldings,
                onSetDefaultAssetTypes: onSetDefaultAssetTypes
            )
            .applyLifecycleModifiers(
                sortedHoldings: sortedHoldings,
                filteredHoldings: filteredHoldings,
                loadingState: loadingState,
                currentFetchTask: currentFetchTask
            )
            .applyChangeModifiers(
                currentSort: currentSort,
                searchText: searchText,
                selectedAssetTypes: selectedAssetTypes,
                selectedAccountNumbers: selectedAccountNumbers,
                selectedOrderStatuses: selectedOrderStatuses,
                includeNAStatus: includeNAStatus,
                onSortChange: onSortChange,
                onCacheInvalidation: onCacheInvalidation
            )
            .applyOverlayModifier(isSorting: isSorting.wrappedValue)
    }
    
    func applySearchable(searchText: Binding<String>) -> some View {
        #if os(macOS)
        self.searchable(text: searchText, prompt: "Search by symbol or description")
        #else
        self
        #endif
    }
    
    func applyToolbar(isSearchFieldFocused: FocusState<Bool>.Binding) -> some View {
        #if os(iOS)
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isSearchFieldFocused.wrappedValue = false
                }
            }
        }
        #else
        self
        #endif
    }
    
    func applyTaskModifier(
        isLoadingAccounts: Binding<Bool>,
        loadingState: LoadingState,
        onFetchHoldings: @escaping () async -> Void,
        onSetDefaultAssetTypes: @escaping () -> Void
    ) -> some View {
        self.task {
            defer { isLoadingAccounts.wrappedValue = false }
            isLoadingAccounts.wrappedValue = true
            SchwabClient.shared.loadingDelegate = loadingState
            await onFetchHoldings()
            onSetDefaultAssetTypes()
        }
    }
    
    func applyLifecycleModifiers(
        sortedHoldings: Binding<[Position]>,
        filteredHoldings: [Position],
        loadingState: LoadingState,
        currentFetchTask: Binding<Task<Void, Never>?>
    ) -> some View {
        self
            .onAppear {
                if sortedHoldings.wrappedValue.isEmpty {
                    sortedHoldings.wrappedValue = filteredHoldings
                }
            }
            .onDisappear {
                SchwabClient.shared.loadingDelegate = nil
                currentFetchTask.wrappedValue?.cancel()
                currentFetchTask.wrappedValue = nil
            }
    }
    
    func applyChangeModifiers(
        currentSort: Binding<SortConfig?>,
        searchText: Binding<String>,
        selectedAssetTypes: Binding<Set<AssetType>>,
        selectedAccountNumbers: Binding<Set<String>>,
        selectedOrderStatuses: Binding<Set<ActiveOrderStatus>>,
        includeNAStatus: Binding<Bool>,
        onSortChange: @escaping () -> Void,
        onCacheInvalidation: @escaping () -> Void
    ) -> some View {
        self
            .onChange(of: currentSort.wrappedValue) { _, _ in
                onSortChange()
                onCacheInvalidation()
            }
            .onChange(of: searchText.wrappedValue) { _, _ in
                onSortChange()
                onCacheInvalidation()
            }
            .onChange(of: selectedAssetTypes.wrappedValue) { _, _ in
                onSortChange()
                onCacheInvalidation()
            }
            .onChange(of: selectedAccountNumbers.wrappedValue) { _, _ in
                onSortChange()
                onCacheInvalidation()
            }
            .onChange(of: selectedOrderStatuses.wrappedValue) { _, _ in
                onSortChange()
                onCacheInvalidation()
            }
            .onChange(of: includeNAStatus.wrappedValue) { _, _ in
                onSortChange()
                onCacheInvalidation()
            }
    }
    
    func applyOverlayModifier(isSorting: Bool) -> some View {
        self.overlay {
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
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                    .padding()
                    Spacer()
                }
            }
        }
    }
}
