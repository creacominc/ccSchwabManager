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
    let quoteData: QuoteData?
    @State private var currentSort: SalesCalcSortConfig? = SalesCalcSortConfig(column: .costPerShare, ascending: SalesCalcSortableColumn.costPerShare.defaultAscending )
    @State private var viewSize: CGSize = .zero
    @State private var showIncompleteDataWarning = false
    
    private func getCurrentPrice() -> Double {
        // Use quote data for current price, fallback to price history if quote is not available
        if let quote = quoteData?.quote?.lastPrice {
            return quote
        } else if let extended = quoteData?.extended?.lastPrice {
            return extended
        } else if let regular = quoteData?.regular?.regularMarketLastPrice {
            return regular
        } else {
            // Fallback to a default value if no quote data is available
            return 0.0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                SalesCalcTable(
                    positionsData: taxLotData,
                    currentSort: $currentSort,
                    viewSize: geometry.size,
                    symbol: symbol,
                    currentPrice: getCurrentPrice()
                )
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { oldValue, newValue in
                    viewSize = newValue
                }
                .padding(.horizontal)
            }
        }
        .onChange(of: SchwabClient.shared.showIncompleteDataWarning) { oldValue, newValue in
            showIncompleteDataWarning = newValue
        }
        .alert("Incomplete Data Warning", isPresented: $showIncompleteDataWarning) {
            Button("OK") { }
        } message: {
            Text("Some data may be incomplete or missing. Please refresh to get the latest information.")
        }
    }

} // SalesCalcView

