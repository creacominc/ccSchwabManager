import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif



class SalesCalcViewModel: ObservableObject {
    @Published var positionsData: [SalesCalcPositionsRecord] = []
    private let schwabClient = SchwabClient.shared
    
    func refreshData(symbol: String) {
        print("SalesCalcViewModel - Refreshing data for symbol: \(symbol)")
        positionsData = schwabClient.computeTaxLots(symbol: symbol)
        print("SalesCalcViewModel refreshData - Received \(positionsData.count) tax lot records")
    }
}

struct SalesCalcView: View {
    let symbol: String
    let atrValue: Double
    @StateObject private var viewModel = SalesCalcViewModel()
    @StateObject private var loadingState = LoadingState()
    @State private var currentSort: SalesCalcSortConfig? = SalesCalcSortConfig(column: .costPerShare, ascending: SalesCalcSortableColumn.costPerShare.defaultAscending )
    @State private var viewSize: CGSize = .zero
    @State private var showIncompleteDataWarning = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                SalesCalcTable(
                    positionsData: viewModel.positionsData,
                    currentSort: $currentSort,
                    viewSize: geometry.size
                )
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newValue in
                    viewSize = newValue
                }
                .padding(.horizontal)
            }
            .onAppear {
                // Use DispatchQueue to ensure we're using the latest symbol value
                DispatchQueue.main.async {
                    // Connect loading state to SchwabClient
                    //print("🔗 SalesCalcView - Setting SchwabClient.loadingDelegate")
                    SchwabClient.shared.loadingDelegate = loadingState
                    viewModel.refreshData(symbol: symbol)
                }
            }
            .onChange(of: symbol) { _, newValue in
                print("Symbol changed to: \(newValue)")
                // Use DispatchQueue to ensure we're using the latest symbol value
                DispatchQueue.main.async {
                    // Connect loading state to SchwabClient
                    //print("🔗 SalesCalcView - Setting SchwabClient.loadingDelegate")
                    SchwabClient.shared.loadingDelegate = loadingState
                    viewModel.refreshData(symbol: newValue)
                }
            }
            .onChange(of: SchwabClient.shared.showIncompleteDataWarning) { _, newValue in
                showIncompleteDataWarning = newValue
            }
            .alert("Incomplete Data Warning", isPresented: $showIncompleteDataWarning) {
                Button("OK", role: .cancel) {
                    SchwabClient.shared.showIncompleteDataWarning = false
                }
            } message: {
                Text("The information for \(symbol) may be incomplete and inaccurate due to missing historical data.")
            }
            .onDisappear {
                //print("🔗 SalesCalcView - Clearing SchwabClient.loadingDelegate")
                SchwabClient.shared.loadingDelegate = nil
            }
        }
        .withLoadingState(loadingState)
    }

} // SalesCalcView

