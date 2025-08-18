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

#Preview("PriceHistoryTab - With Data", traits: .landscapeLeft) {
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
    
    return GeometryReader { geometry in
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
            geometry: geometry
        )
    }
    .frame(width: 600, height: 400)
    .padding()
}

#Preview("PriceHistoryTab - Loading", traits: .landscapeLeft) {
    GeometryReader { geometry in
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
            geometry: geometry
        )
    }
    .frame(width: 600, height: 400)
    .padding()
}

#Preview("PriceHistoryTab - No Data", traits: .landscapeLeft) {
    GeometryReader { geometry in
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
            geometry: geometry
        )
    }
    .frame(width: 600, height: 400)
    .padding()
} 
