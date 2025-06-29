import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SalesCalcView: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    @State private var currentSort: SalesCalcSortConfig? = SalesCalcSortConfig(column: .costPerShare, ascending: SalesCalcSortableColumn.costPerShare.defaultAscending )
    @State private var viewSize: CGSize = .zero
    @State private var showIncompleteDataWarning = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                SalesCalcTable(
                    positionsData: taxLotData,
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
        }
    }

} // SalesCalcView

