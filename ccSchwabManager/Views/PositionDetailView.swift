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
            chartContent
    }
    
    @ViewBuilder
    private var chartContent: some View {
        ZStack {
            Chart {
                // candles were already sorted when they arrive in getPriceHistory
                //ForEach(candles.sorted { ($0.datetime ?? 0) < ($1.datetime ?? 0) }, id: \.datetime) { candle in
                ForEach(candles, id: \.datetime) { candle in
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
                    if let date = value.as(Date.self) {
                        let calendar = Calendar.current
                        let isFirstDayOfMonth = calendar.component(.day, from: date) == 1
                        
                        if isFirstDayOfMonth {
                            AxisValueLabel(format: .dateTime.month())
                        }
                    }
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
                                    guard let plotFrame = proxy.plotFrame else { return }
                                    x = value.location.x - geometry[plotFrame].origin.x
                                    guard x >= 0, x < geometry[plotFrame].width else { return }
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
    }

}

struct PositionDetailsHeader: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let onNavigate: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: { onNavigate(currentIndex - 1) }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex <= 0)
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Spacer()
                
                Text(position.instrument?.symbol ?? "")
                    .font(.title2)
                    .bold()
                
                Spacer()
                
                Button(action: { onNavigate(currentIndex + 1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= totalPositions - 1)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }
            
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

struct TransactionHistorySection: View {
    let transactions: [Transaction]
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction History")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if transactions.isEmpty {
                Text("No transactions available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                Table(transactions) {
                    TableColumn("Date") { (transaction: Transaction) in
                        Text(formatDate(transaction.tradeDate))
                    }
                    TableColumn("Type") { (transaction: Transaction) in
                        Text( transaction.netAmount ?? 0 < 0 ? "Buy" : transaction.netAmount ?? 0 > 0 ? "Sell" : "Unknown" )
                    }
                    TableColumn("Quantity") { (transaction: Transaction) in
                        if let transferItem = transaction.transferItems.first {
                            Text(String(format: "%.2f", transferItem.amount ?? 0))
                        } else {
                            Text("")
                        }
                    }
                    TableColumn("Price") { (transaction: Transaction) in
                        if let transferItem = transaction.transferItems.first {
                            Text(String(format: "%.2f", transferItem.price ?? 0))
                        } else {
                            Text("")
                        }
                    }
                    TableColumn("Net Amount") { (transaction: Transaction) in
                        Text(String(format: "%.2f", transaction.netAmount ?? 0))
                    }
                }
                .frame(height: 300)
            }
        }
        .padding(.vertical)
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct PositionDetailView: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let onNavigate: (Int) -> Void
    @State private var priceHistory: CandleList?
    @State private var transactions: [Transaction] = []
    @State private var isLoadingPriceHistory = false
    @State private var isLoadingTransactions = false
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var viewSize: CGSize = .zero

    private func formatDate(_ timestamp: Int64?) -> String {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            PositionDetailsHeader(
                position: position,
                accountNumber: accountNumber,
                currentIndex: currentIndex,
                totalPositions: totalPositions,
                onNavigate: onNavigate
            )
            .padding(.bottom, 8)
            
            Divider()
                .padding(.vertical, 8)
            
            GeometryReader { geometry in
                TabView {

                    ScrollView {
                        PriceHistorySection(
                            priceHistory: priceHistory,
                            isLoading: isLoadingPriceHistory,
                            formatDate: formatDate
                        )
                        .frame( width: geometry.size.width * 0.83, height: geometry.size.height * 0.83  )
                        //.border(Color.white.opacity(0.3), width: 1)
                    }
                    .tabItem {
                        Label("Price History", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    ScrollView {
                        TransactionHistorySection(
                            transactions: transactions,
                            isLoading: isLoadingTransactions
                        )
                        .frame( width: geometry.size.width * 0.83,  height: geometry.size.height * 0.83  )
                        //.border(Color.white.opacity(0.3), width: 1)
                    }
                    .tabItem {
                        Label("Transactions", systemImage: "list.bullet")
                    }

                } // TabView
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { newSize in
                    viewSize = newSize
                }
            } // GeometryReader
        } // VStack
            .padding(.horizontal)
            .onAppear {
                Task {
                    await fetchPriceHistory()
                    await fetchTransactions()
                }
            }
            .onChange(of: position) { oldValue, newValue in
                Task {
                    await fetchPriceHistory()
                    await fetchTransactions()
                }
            }
    }
    
    private func fetchPriceHistory() async {
        guard let symbol = position.instrument?.symbol else { return }
        isLoadingPriceHistory = true
        defer { isLoadingPriceHistory = false }
        
        priceHistory = await SchwabClient.shared.fetchPriceHistory(symbol: symbol)
    }
    
    private func fetchTransactions() async {
        guard let symbol = position.instrument?.symbol else { return }
        isLoadingTransactions = true
        defer { isLoadingTransactions = false }
        
        transactions = await SchwabClient.shared.fetchTransactionHistory(symbol: symbol)
    }
} 
