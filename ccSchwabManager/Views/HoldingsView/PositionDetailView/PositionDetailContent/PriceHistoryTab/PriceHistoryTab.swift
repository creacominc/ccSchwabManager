import SwiftUI

struct PriceHistoryTab: View {
    let priceHistory: CandleList?
    let isLoading: Bool
    let formatDate: (Int64?) -> String
    let geometry: GeometryProxy
    
    var body: some View {
        ScrollView {
            PriceHistorySection(
                priceHistory: priceHistory,
                isLoading: isLoading,
                formatDate: formatDate
            )
            .frame(width: geometry.size.width * 0.90, height: geometry.size.height * 0.90)
        }
        .tabItem {
            Label("Price History", systemImage: "chart.line.uptrend.xyaxis")
        }
    }
} 