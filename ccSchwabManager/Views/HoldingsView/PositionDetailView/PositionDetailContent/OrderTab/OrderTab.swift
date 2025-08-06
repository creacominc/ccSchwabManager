import SwiftUI

struct OrderTab: View {
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let quoteData: QuoteData?
    let geometry: GeometryProxy
    let accountNumber: String
    
    @State private var currentOrdersHeight: CGFloat = 0
    @State private var recommendedOrdersHeight: CGFloat = 0
    
    // Minimum height for Current Orders section (header + cancel button)
    private let minCurrentOrdersHeight: CGFloat = 80
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 8) {
                // Section 1: Current Orders
                CurrentOrdersSection(symbol: symbol)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: CurrentOrdersHeightKey.self, value: geo.size.height)
                        }
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: minCurrentOrdersHeight,
                        maxHeight: max(minCurrentOrdersHeight, currentOrdersHeight)
                    )
                
                Divider()
                
                // Section 2: Recommended OCO Orders (Combined Buy and Sell)
                RecommendedOCOOrdersSection(
                    symbol: symbol,
                    atrValue: atrValue,
                    taxLotData: taxLotData,
                    sharesAvailableForTrading: sharesAvailableForTrading,
                    quoteData: quoteData,
                    accountNumber: accountNumber
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: RecommendedOrdersHeightKey.self, value: geo.size.height)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, geometry.size.width * 0.02)
            .onPreferenceChange(CurrentOrdersHeightKey.self) { height in
                currentOrdersHeight = height
            }
            .onPreferenceChange(RecommendedOrdersHeightKey.self) { height in
                recommendedOrdersHeight = height
            }
        }
        .tabItem {
            Image(systemName: "list.bullet")
            Text("Orders")
        }
    }
}

// Preference keys for measuring section heights
struct CurrentOrdersHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct RecommendedOrdersHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
} 
