import SwiftUI

struct OCOOrdersTab: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    let quoteData: QuoteData?
    let accountNumber: String
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // OCO Orders Section
                VStack(alignment: .leading, spacing: 0) {
                    // Section Header
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)
                        Text("Recommended Orders (Single or OCO)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    
                    // Section Content
                    RecommendedOCOOrdersSection(
                        symbol: symbol,
                        atrValue: atrValue,
                        taxLotData: taxLotData,
                        sharesAvailableForTrading: sharesAvailableForTrading,
                        quoteData: quoteData,
                        accountNumber: accountNumber
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                // Add bottom padding to ensure content is fully visible
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.black.opacity(0.1))
    }
}
