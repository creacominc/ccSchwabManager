import SwiftUI

struct PriceHistoryTab: View
{
    let priceHistory: CandleList?
    let isLoading: Bool
    let formatDate: (Int64?) -> String
    let atrValue: Double
    let position: Position
    @Binding var sharesAvailableForTrading: Double
    @Binding var marketValue: Double
    let lastPrice: Double

    var body: some View
    {
        GeometryReader
        { geometry in
            VStack(alignment: .leading, spacing: 0)
            {
                // Section Header
                HStack
                {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    Text("Price History")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Spacer()
                    
                    // Critical information on the same line
                    CriticalInfoRow(
                        sharesAvailableForTrading: sharesAvailableForTrading,
                        marketValue: marketValue,
                        position: position,
                        lastPrice: lastPrice,
                        atrValue: atrValue
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))

                PriceHistorySection(
                    priceHistory: priceHistory,
                    isLoading: isLoading,
                    formatDate: formatDate
                )
                .frame(height: geometry.size.height - 50) // Subtract approximate header height
            }
        }
    }
}

#Preview("PriceHistoryTab - With Data", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 500
    @Previewable @State var marketValue: Double = 300.0
    @Previewable @State var lastPrice: Double = 50.50
    let atrValue: Double = 2.45 // Initial value from parent, will be recomputed
    let calendar = Calendar.current
    let now = Date()
    
    // Create sample data spanning a full year with monthly data points
    let sampleCandles = [
        // January (Q1)
        Candle(
            close: 145.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -11, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-01-15",
            high: 148.0,
            low: 142.0,
            open: 143.0,
            volume: 1200000
        ),
        // February (Q1)
        Candle(
            close: 152.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -10, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-02-15",
            high: 155.0,
            low: 149.0,
            open: 145.0,
            volume: 1350000
        ),
        // March (Q1)
        Candle(
            close: 158.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -9, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-03-15",
            high: 161.0,
            low: 155.0,
            open: 152.0,
            volume: 1500000
        ),
        // April (Q2)
        Candle(
            close: 162.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -8, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-04-15",
            high: 165.0,
            low: 159.0,
            open: 158.0,
            volume: 1400000
        ),
        // May (Q2)
        Candle(
            close: 168.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -7, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-05-15",
            high: 171.0,
            low: 163.0,
            open: 162.0,
            volume: 1600000
        ),
        // June (Q2)
        Candle(
            close: 175.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -6, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-06-15",
            high: 178.0,
            low: 172.0,
            open: 168.0,
            volume: 1700000
        ),
        // July (Q3)
        Candle(
            close: 182.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -5, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-07-15",
            high: 185.0,
            low: 179.0,
            open: 175.0,
            volume: 1800000
        ),
        // August (Q3)
        Candle(
            close: 188.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -4, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-08-15",
            high: 191.0,
            low: 185.0,
            open: 182.0,
            volume: 1900000
        ),
        // September (Q3)
        Candle(
            close: 195.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -3, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-09-15",
            high: 198.0,
            low: 192.0,
            open: 188.0,
            volume: 2000000
        ),
        // October (Q4)
        Candle(
            close: 190.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -2, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-10-15",
            high: 193.0,
            low: 187.0,
            open: 195.0,
            volume: 1800000
        ),
        // November (Q4)
        Candle(
            close: 185.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -1, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            datetimeISO8601: "2024-11-15",
            high: 188.0,
            low: 182.0,
            open: 190.0,
            volume: 1700000
        ),
        // December (Q4) - Current month
        Candle(
            close: 180.0,
            datetime: Int64(now.timeIntervalSince1970) * 1000,
            datetimeISO8601: "2024-12-15",
            high: 183.0,
            low: 178.0,
            open: 185.0,
            volume: 1600000
        )
    ]
    
    let samplePriceHistory = CandleList(
        candles: sampleCandles,
        empty: false,
        previousClose: 185.0,
        previousCloseDate: Int64(calendar.date(byAdding: .day, value: -1, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
        previousCloseDateISO8601: "2024-12-14",
        symbol: "AAPL"
    )
    
    GeometryReader { geometry in
        VStack {
            createMockTabBar()
            PriceHistoryTab(
                priceHistory: samplePriceHistory,
                isLoading: false,
                formatDate: { timestamp in
                    if let timestamp = timestamp {
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
                        return date.formatted(date: .abbreviated, time: .omitted)
                    }
                    return "N/A"
                },
                atrValue: atrValue,
                position: Position(shortQuantity: 0, longQuantity: 0,
                                   marketValue: marketValue, longOpenProfitLoss: 0.0),
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                lastPrice: lastPrice
            )
        }
    }
    .padding()
}

#Preview("PriceHistoryTab - Loading", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 500
    @Previewable @State var marketValue: Double = 300.0
    @Previewable @State var lastPrice: Double = 50.50
    let atrValue: Double = 2.45 // Initial value from parent, will be recomputed

    GeometryReader
    { geometry in
        VStack
        {
            createMockTabBar()
            PriceHistoryTab(
                priceHistory: nil,
                isLoading: true,
                formatDate: { timestamp in
                    if let timestamp = timestamp {
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
                        return date.formatted(date: .abbreviated, time: .omitted)
                    }
                    return "N/A"
                },
                atrValue: atrValue,
                position: Position(shortQuantity: 0, longQuantity: 0,
                                   marketValue: marketValue, longOpenProfitLoss: 0.0),
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                lastPrice: lastPrice
            )
        }
    }
    .padding()
}

#Preview("PriceHistoryTab - No Data", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 500
    @Previewable @State var marketValue: Double = 300.0
    @Previewable @State var lastPrice: Double = 50.50
    let atrValue: Double = 2.45 // Initial value from parent, will be recomputed

    GeometryReader
    { geometry in
        VStack
        {
            createMockTabBar()
            PriceHistoryTab(
                priceHistory: nil,
                isLoading: false,
                formatDate: { timestamp in
                    if let timestamp = timestamp {
                        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
                        return date.formatted(date: .abbreviated, time: .omitted)
                    }
                    return "N/A"
                },
                atrValue: atrValue,
                position: Position(shortQuantity: 0, longQuantity: 0,
                                   marketValue: marketValue, longOpenProfitLoss: 0.0),
                sharesAvailableForTrading: $sharesAvailableForTrading,
                marketValue: $marketValue,
                lastPrice: lastPrice
            )
        }
    }
    .padding()
} 


@MainActor
private func createMockTabBar() -> some View {
    HStack(spacing: 0) {
        TabButton(
            title: "Details",
            icon: "info.circle",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Price History",
            icon: "chart.line.uptrend.xyaxis",
            isSelected: true,
            action: {}
        )
        TabButton(
            title: "Transactions",
            icon: "list.bullet",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Sales Calc",
            icon: "number.circle.fill",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Orders",
            icon: "doc.text",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "OCO",
            icon: "arrow.up.circle",
            isSelected: false,
            action: {}
        )
        TabButton(
            title: "Sequence",
            icon: "arrow.up.circle",
            isSelected: false,
            action: {}
        )
    }
    .background(Color.gray.opacity(0.1))
    .padding(.horizontal)
    .padding(.bottom, 2)
}

