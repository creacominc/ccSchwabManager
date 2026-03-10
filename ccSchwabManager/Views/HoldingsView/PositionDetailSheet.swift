//
//  PositionDetailSheet.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI

struct PositionDetailSheet: View {
    let selected: SelectedPosition
    @Binding var isNavigating: Bool
    @Binding var selectedTab: Int
    @Binding var atrValue: Double
    @Binding var sharesAvailableForTrading: Double
    @Binding var marketValue: Double
    @Binding var viewSize: CGSize
    @Binding var selectedPosition: SelectedPosition?
    
    let sortedHoldings: [Position]
    let accountPositions: [(Position, String, String)]
    
    var body: some View {
        let currentIndex = sortedHoldings.firstIndex(where: { $0.id == selected.id }) ?? 0
        PositionDetailView(
            position: selected.position,
            accountNumber: selected.accountNumber,
            currentIndex: currentIndex,
            totalPositions: sortedHoldings.count,
            symbol: selected.position.instrument?.symbol ?? "",
            atrValue: atrValue,
            sharesAvailableForTrading: $sharesAvailableForTrading,
            marketValue: $marketValue,
            onNavigate: createNavigationHandler(currentIndex: currentIndex),
            getAdjacentSymbols: createAdjacentSymbolsHandler(currentIndex: currentIndex),
            getSymbolAtIndex: createSymbolAtIndexHandler(),
            getCurrentListSymbols: createCurrentListSymbolsHandler(),
            selectedTab: $selectedTab
        )
        .task {
            // Note: Data fetching moved to PositionDetailView
        }
        .onChange(of: selected.position.instrument?.symbol) { _, _ in
            // Note: Data fetching moved to PositionDetailView
        }
        .frame(width: viewSize.width * 0.97, height: viewSize.height * 0.98)
    }
    
    private func createNavigationHandler(currentIndex: Int) -> (Int) -> Void {
        let isNavigatingBinding = $isNavigating
        let selectedPositionBinding = $selectedPosition
        return { [sortedHoldings, accountPositions] newIndex in
            guard newIndex >= 0 && newIndex < sortedHoldings.count else { return }
            guard !isNavigatingBinding.wrappedValue else { return }
            
            print("HoldingsView: Navigating to position \(newIndex)")
            isNavigatingBinding.wrappedValue = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let newPosition = sortedHoldings[newIndex]
                let accountNumber = accountPositions.first { $0.0 === newPosition }?.1 ?? ""
                selectedPositionBinding.wrappedValue = SelectedPosition(id: newPosition.id, position: newPosition, accountNumber: accountNumber)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNavigatingBinding.wrappedValue = false
                }
            }
        }
    }
    
    private func createAdjacentSymbolsHandler(currentIndex: Int) -> () -> (previous1: String?, previous2: String?, next1: String?, next2: String?) {
        return { [sortedHoldings] in
            let previous1: String? = currentIndex > 0 ? sortedHoldings[currentIndex - 1].instrument?.symbol : nil
            let previous2: String? = currentIndex > 1 ? sortedHoldings[currentIndex - 2].instrument?.symbol : nil
            let next1: String? = currentIndex < sortedHoldings.count - 1 ? sortedHoldings[currentIndex + 1].instrument?.symbol : nil
            let next2: String? = currentIndex < sortedHoldings.count - 2 ? sortedHoldings[currentIndex + 2].instrument?.symbol : nil
            return (previous1: previous1, previous2: previous2, next1: next1, next2: next2)
        }
    }
    
    private func createSymbolAtIndexHandler() -> (Int) -> String? {
        return { [sortedHoldings] index in
            guard index >= 0 && index < sortedHoldings.count else { return nil }
            return sortedHoldings[index].instrument?.symbol
        }
    }
    
    private func createCurrentListSymbolsHandler() -> () -> Set<String> {
        return { [sortedHoldings] in
            return Set(sortedHoldings.compactMap { $0.instrument?.symbol })
        }
    }
}
