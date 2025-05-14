import SwiftUI
import Charts

struct PriceHistoryChart: View {
    let candles: [Candle]
    @State private var selectedDate: Date?
    @State private var selectedPrice: Double?
    @State private var tooltipPosition: CGPoint = .zero
    
    private var tooltipBackgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(.windowBackgroundColor)
        #endif
    }
    
    var body: some View {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            chartContent
        } else {
            fallbackView
        }
        #else
        if #available(macOS 13.0, *) {
            chartContent
        } else {
            fallbackView
        }
        #endif
    }
    
    @ViewBuilder
    private var chartContent: some View {
        if #available(macOS 13.0, iOS 16.0, *) {
            ZStack {
                Chart {
                    ForEach(candles.sorted { ($0.datetime ?? 0) < ($1.datetime ?? 0) }, id: \.datetime) { candle in
                        LineMark(
                            x: .value("Date", Date(timeIntervalSince1970: TimeInterval(candle.datetime ?? 0) / 1000)),
                            y: .value("Price", candle.close ?? 0)
                        )
                        .foregroundStyle(.blue)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel(format: .currency(code: "USD").precision(.fractionLength(2)))
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x: CGFloat
                                        #if os(iOS)
                                        if #available(iOS 17.0, *) {
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            x = value.location.x - geometry[plotFrame].origin.x
                                            guard x >= 0, x < geometry[plotFrame].width else { return }
                                        } else {
                                            x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                            guard x >= 0, x < geometry[proxy.plotAreaFrame].width else { return }
                                        }
                                        #else
                                        if #available(macOS 14.0, *) {
                                            guard let plotFrame = proxy.plotFrame else { return }
                                            x = value.location.x - geometry[plotFrame].origin.x
                                            guard x >= 0, x < geometry[plotFrame].width else { return }
                                        } else {
                                            x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                            guard x >= 0, x < geometry[proxy.plotAreaFrame].width else { return }
                                        }
                                        #endif
                                        
                                        let date = proxy.value(atX: x) as Date?
                                        if let date = date,
                                           let candle = candles.first(where: { 
                                               let candleDate = Date(timeIntervalSince1970: TimeInterval($0.datetime ?? 0) / 1000)
                                               return Calendar.current.isDate(candleDate, inSameDayAs: date)
                                           }) {
                                            selectedDate = date
                                            selectedPrice = candle.close
                                            tooltipPosition = CGPoint(x: value.location.x, y: value.location.y)
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedDate = nil
                                        selectedPrice = nil
                                    }
                            )
                    }
                }
                
                if let date = selectedDate, let price = selectedPrice {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(date, format: .dateTime.month().day().year())
                            .font(.caption)
                        Text(String(format: "$%.2f", price))
                            .font(.caption)
                            .bold()
                    }
                    .padding(8)
                    .background(tooltipBackgroundColor)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .position(x: tooltipPosition.x, y: tooltipPosition.y - 40)
                }
            }
            .frame(height: 300)
            .padding()
        } else {
            fallbackView
        }
    }
    
    private var fallbackView: some View {
        VStack {
            Text("Price History Chart")
                .font(.headline)
            Text("Charts require iOS 16.0 or macOS 13.0 or newer")
                .foregroundColor(.secondary)
        }
        .frame(height: 300)
        .padding()
    }
}

struct PositionDetailView: View {
    let position: Position
    let accountNumber: String
    @State private var priceHistory: CandleList?
    @State private var isLoading = false
    @EnvironmentObject var secretsManager: SecretsManager

    private func formatDate(_ timestamp: Int64?) -> String {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            PositionDetailsHeader(position: position, accountNumber: accountNumber)
            Divider()
            PriceHistorySection(
                priceHistory: priceHistory,
                isLoading: isLoading,
                formatDate: formatDate
            )
        }
        .onAppear {
            Task {
                await fetchPriceHistory()
            }
        }
        .onChange(of: position) { oldValue, newValue in
            Task {
                await fetchPriceHistory()
            }
        }
    }
    
    private func fetchPriceHistory() async {
        guard let symbol = position.instrument?.symbol else { return }
        isLoading = true
        defer { isLoading = false }
        
        let schwabClient = SchwabClient(secrets: &secretsManager.secrets)
        priceHistory = await schwabClient.fetchPriceHistory(symbol: symbol)
    }
}

struct PositionDetailsHeader: View {
    let position: Position
    let accountNumber: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(position.instrument?.symbol ?? "")
                .font(.title2)
                .bold()
            
            HStack(spacing: 20) {
                LeftColumn(position: position)
                RightColumn(position: position, accountNumber: accountNumber)
            }
        }
        .padding()
        .background(backgroundColor)
        .frame(maxWidth: .infinity)
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(.windowBackgroundColor)
        #endif
    }
}

struct LeftColumn: View {
    let position: Position
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailRow(label: "Description", value: position.instrument?.description ?? "")
            DetailRow(label: "Quantity", value: String(format: "%.2f", position.longQuantity ?? 0))
            DetailRow(label: "Average Price", value: String(format: "%.2f", position.averagePrice ?? 0))
            DetailRow(label: "Market Value", value: String(format: "%.2f", position.marketValue ?? 0))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RightColumn: View {
    let position: Position
    let accountNumber: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailRow(label: "P/L", value: String(format: "%.2f", position.longOpenProfitLoss ?? 0))
            DetailRow(label: "P/L %", value: String(format: "%.1f%%", 
                (position.longOpenProfitLoss ?? 0) / (position.marketValue ?? 1) * 100))
            DetailRow(label: "Asset Type", value: position.instrument?.assetType?.rawValue ?? "")
            DetailRow(label: "Account", value: accountNumber)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PriceHistorySection: View {
    let priceHistory: CandleList?
    let isLoading: Bool
    let formatDate: (Int64?) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Price History")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let history = priceHistory {
                PreviousCloseInfo(history: history, formatDate: formatDate)
                PriceHistoryChart(candles: history.candles)
            } else {
                Text("No price history available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding(.vertical)
    }
}

struct PreviousCloseInfo: View {
    let history: CandleList
    let formatDate: (Int64?) -> String
    
    var body: some View {
        HStack(spacing: 20) {
            DetailRow(label: "Previous Close", value: String(format: "%.2f", history.previousClose ?? 0))
            DetailRow(label: "Previous Close Date", value: formatDate(history.previousCloseDate))
        }
        .padding(.horizontal)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .monospacedDigit()
        }
    }
} 
