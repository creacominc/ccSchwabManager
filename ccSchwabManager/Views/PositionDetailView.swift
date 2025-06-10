import SwiftUI
import Charts

// ADD Definitions for Transaction Sorting
struct TransactionSortConfig: Equatable {
    var column: TransactionSortableColumn
    var ascending: Bool
}

enum TransactionSortableColumn: String, CaseIterable, Identifiable {
    case date = "Date"
    case type = "Type" // Buy/Sell derived from netAmount
    case quantity = "Quantity"
    case price = "Price"
    case netAmount = "Net Amount"

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .date, .quantity, .price:
            return false // Typically newest first
        case .type, .netAmount:
            return true
        }
    }
}
// END ADD Definitions

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
    
    private var yAxisRange: ClosedRange<Double> {
        guard !candles.isEmpty else { return 0...100 }
        let closes = candles.compactMap { $0.close }
        guard !closes.isEmpty else { return 0...100 }
        let minClose = closes.min() ?? 0
        let maxClose = closes.max() ?? 100
        let padding = (maxClose - minClose) * 0.1
        return (minClose - padding)...(maxClose + padding)
    }
    
    var body: some View {
            chartContent
    }
    
    @ViewBuilder
    private var chartContent: some View {
        ZStack {
            Chart {
                // candles were already sorted when they arrive in getPriceHistory
                ForEach(candles, id: \.datetime) { candle in
                    LineMark(
                        x: .value("Date", Date(timeIntervalSince1970: TimeInterval(candle.datetime ?? 0) / 1000)),
                        y: .value("Price", candle.close ?? 0)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .chartYScale(domain: yAxisRange)
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
    //
    let symbol: String
    let atrValue: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Previous Position Button
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
                
                // Next Position Button
                Button(action: { onNavigate(currentIndex + 1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= totalPositions - 1)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            HStack(spacing: 20) {
                LeftColumn(position: position,
                           atrValue: atrValue
                )
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
    let atrValue: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DetailRow(label: "Quantity", value: String(format: "%.2f", position.longQuantity ?? 0))
            DetailRow(label: "Average Price", value: String(format: "%.2f", position.averagePrice ?? 0))
            DetailRow(label: "Market Value", value: String(format: "%.2f", position.marketValue ?? 0))
            DetailRow(label: "ATR", value: "\(String(format: "%.2f", atrValue)) %" )
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
//            Text("Price History")
//                .font(.headline)
//                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .progressViewStyle( CircularProgressViewStyle( tint: .accentColor ) )
                    .scaleEffect(2.0, anchor: .center)
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
    let isLoading: Bool
    let symbol: String
    @State private var currentSort: TransactionSortConfig? = TransactionSortConfig(column: .date, ascending: TransactionSortableColumn.date.defaultAscending)

    /** @TODO:  change fetchTransactionHistory to not return an array after adding sort logic to the client*/
    private var sortedTransactions: [Transaction] {
        guard let sortConfig = currentSort else { return SchwabClient.shared.getTransactionsFor( symbol: symbol ) }
        print( "=== Sorting transactions ===  \(symbol)" )
        return SchwabClient.shared.getTransactionsFor( symbol: symbol ).sorted { t1, t2 in
            let ascending = sortConfig.ascending
            switch sortConfig.column {
            case .date:
                let date1 = t1.tradeDate ?? ""
                let date2 = t2.tradeDate ?? ""
                return ascending ? date1 < date2 : date1 > date2
            case .type:
                let type1 = (t1.netAmount ?? 0) < 0 ? "Buy" : (t1.netAmount ?? 0) > 0 ? "Sell" : "Unknown"
                let type2 = (t2.netAmount ?? 0) < 0 ? "Buy" : (t2.netAmount ?? 0) > 0 ? "Sell" : "Unknown"
                return ascending ? type1 < type2 : type1 > type2
            case .quantity:
                // get the amount from the first transferItem with instrumentSymbol matching symbol
                let transferItem1 = t1.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let transferItem2 = t2.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let qty1 = transferItem1?.amount ?? 0
                let qty2 = transferItem2?.amount ?? 0
                return ascending ? qty1 < qty2 : qty1 > qty2
            case .price:
                // get the price from the first transferItem with instrumentSymbol matching symbol
                let transferItem1 = t1.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let transferItem2 = t2.transferItems.first(where: { $0.instrument?.symbol == symbol })
                let price1 = transferItem1?.price ?? 0
                let price2 = transferItem2?.price ?? 0
                return ascending ? price1 < price2 : price1 > price2
            case .netAmount:
                let amount1 = t1.netAmount ?? 0
                let amount2 = t2.netAmount ?? 0
                return ascending ? amount1 < amount2 : amount1 > amount2
            }
        }
    }

    // Define proportional widths for columns
    private let columnProportions: [CGFloat] = [0.25, 0.15, 0.20, 0.20, 0.20] // Date, Type, Qty, Price, Net Amount

    @ViewBuilder
    private func columnHeader(title: String, column: TransactionSortableColumn, alignment: Alignment = .leading) -> some View {
        Button(action: {
            if currentSort?.column == column {
                currentSort?.ascending.toggle()
            } else {
                currentSort = TransactionSortConfig(column: column, ascending: column.defaultAscending)
            }
        }) {
            HStack {
                if alignment == .trailing {
                    Spacer()
                }
                Text(title)
                if alignment == .leading {
                    Spacer()
                }
                if currentSort?.column == column {
                    Image(systemName: currentSort?.ascending ?? true ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private static func round(_ value: Double, precision: Int) -> Double {
        let multiplier = pow(10.0, Double(precision))
        return (value * multiplier).rounded() / multiplier
    }

    struct TransactionRow: View {
        let transaction: Transaction
        let symbol: String
        let calculatedWidths: [CGFloat]
        let formatDate: (String?) -> String
        
        private var isSell: Bool {
            return transaction.netAmount ?? 0 > 0
        }
        
        var body: some View {
            HStack(spacing: 8) {
                Text(formatDate(transaction.tradeDate))
                    .frame(width: calculatedWidths[0], alignment: .leading)
                Text(transaction.netAmount ?? 0 < 0 ? "Buy" : transaction.netAmount ?? 0 > 0 ? "Sell" : "Unknown")
                    .frame(width: calculatedWidths[1], alignment: .leading)
                if let transferItem = transaction.transferItems.first(where: { $0.instrument?.symbol == symbol }) {
                    let amount = TransactionHistorySection.round(transferItem.amount ?? 0, precision: 4)
                    let price = TransactionHistorySection.round(transferItem.price ?? 0, precision: 2)
                    Text(String(format: "%.4f", amount))
                        .frame(width: calculatedWidths[2], alignment: .trailing)
                    Text(String(format: "%.2f", price))
                        .frame(width: calculatedWidths[3], alignment: .trailing)
                } else {
                    Text("").frame(width: calculatedWidths[2])
                    Text("").frame(width: calculatedWidths[3])
                }
                Text(String(format: "%.2f", transaction.netAmount ?? 0))
                    .frame(width: calculatedWidths[4], alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 5)
            .foregroundColor(isSell ? .red : .primary)
            Divider()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
//            Text("Transaction History")
//                .font(.headline)
//                .padding(.horizontal)
//                .padding(.bottom, 5)

            if isLoading {
                ProgressView()
                    .progressViewStyle( CircularProgressViewStyle( tint: .accentColor ) )
                    .scaleEffect(2.0, anchor: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if SchwabClient.shared.getTransactionsFor( symbol: symbol ).isEmpty {
                Text("No transactions available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                GeometryReader { geometry in
                    // Account for HStack spacing AND its horizontal padding (assuming default ~16pts per side)
                    let horizontalPadding: CGFloat = 16 * 2 
                    let interColumnSpacing = (CGFloat(columnProportions.count - 1) * 8) // 8 is the HStack spacing
                    let availableWidthForColumns = geometry.size.width - interColumnSpacing - horizontalPadding
                    let calculatedWidths = columnProportions.map { $0 * availableWidthForColumns }

                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            columnHeader(title: "Date", column: .date).frame(width: calculatedWidths[0])
                            columnHeader(title: "Type", column: .type).frame(width: calculatedWidths[1])
                            // right justify the Quantity column header
                            columnHeader(title: "Quantity", column: .quantity, alignment: .trailing).frame(width: calculatedWidths[2])
                            // right justify the Price column header
                            columnHeader(title: "Price", column: .price, alignment: .trailing).frame(width: calculatedWidths[3])
                            // right justify the Net Amount column header
                            columnHeader(title: "Net Amount", column: .netAmount, alignment: .trailing).frame(width: calculatedWidths[4])
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 5)
                        .background(Color.gray.opacity(0.1))
                        
                        Divider()

                        ScrollView {
                            LazyVStack(spacing: 0) {
                                /** @TODO:  change fetchTransactionHistory to not return an array after adding sort logic to the client*/
                                ForEach(sortedTransactions) { transaction in
                                    TransactionRow(
                                        transaction: transaction,
                                        symbol: symbol,
                                        calculatedWidths: calculatedWidths,
                                        formatDate: formatDate
                                    )
                                }
                            }
                        }
//                        .frame(height: .infinity)
//                        .task {
//                            // print each record of the savedTransactions
//                            for transaction in sortedTransactions {
//                                print(transaction.dump())
//                            }
//                        }
                    }
                }
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

struct TransactionsTab: View {
    let isLoading: Bool
    let symbol: String
    let geometry: GeometryProxy
    
    var body: some View {
        ScrollView {
            TransactionHistorySection(
                isLoading: isLoading,
                symbol: symbol
            )
            .frame(width: geometry.size.width * 0.88, height: geometry.size.height * 0.90)
        }
        .tabItem {
            Label("Transactions", systemImage: "list.bullet")
        }
    }
}

struct SalesCalcTab: View {
    // SellOrderDetailSection
    let symbol: String
    let atrValue: Double
    let geometry: GeometryProxy
//    // current position and tax lots for a given security
//    let currentCostBasis: Double
//    let currentShares: Int
//    let transactionList : [Transaction]

//    let sellOrder: SalesCalcResultsRecord
//    let copiedValue: String

    var body: some View {
        ScrollView {
//            VStack
//            {
//                Text( "symbol: \(symbol)" )
//                Text( "ATR: \(atrValue) %" )
//            }
            SalesCalcView(
                symbol: symbol,
                atrValue: atrValue
                //,
//                currentCostBasis: currentCostBasis,
//                currentShares: currentShares,
//                transactionList: transactionList
//                sellOrder: sellOrder
//                copiedValue: copiedValue
            )
            .frame(width: geometry.size.width * 0.90, height: geometry.size.height * 0.90)
//            .padding(.horizontal)
//            .border(Color.pink)
        }
        .tabItem {
            Label("Sales Calc", systemImage: "calculator")
        }
    }
}

struct PositionDetailContent: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let symbol: String
    let atrValue: Double
    let onNavigate: (Int) -> Void
    let priceHistory: CandleList?
    let isLoadingPriceHistory: Bool
    let isLoadingTransactions: Bool
    let formatDate: (Int64?) -> String
    @Binding var viewSize: CGSize
//    // current position and tax lots for a given security
//    let currentCostBasis: Double
//    let currentShares: Int
//    let transactionList : [Transaction]

//    let sellOrder: SalesCalcResultsRecord
//    let copiedValue: String

    var body: some View {
        VStack(spacing: 0) {
            PositionDetailsHeader(
                position: position,
                accountNumber: accountNumber,
                currentIndex: currentIndex,
                totalPositions: totalPositions,
                onNavigate: onNavigate,
                symbol: symbol,
                atrValue: atrValue
            )
            .padding(.bottom, 8)
            
            Divider()
                .padding(.vertical, 8)
            
            GeometryReader { geometry in
                TabView {
                    PriceHistoryTab(
                        priceHistory: priceHistory,
                        isLoading: isLoadingPriceHistory,
                        formatDate: formatDate,
                        geometry: geometry
                    )
                    
                    TransactionsTab(
                        isLoading: isLoadingTransactions,
                        symbol: position.instrument?.symbol ?? "",
                        geometry: geometry
                    )
                    
                    SalesCalcTab(
                        symbol: symbol,
                        atrValue: atrValue,
                        geometry: geometry
//                        currentCostBasis: currentCostBasis,
//                        currentShares: currentShares,
//                        transactionList: transactionList
                        //,
//                        sellOrder: sellOrder,
//                        copiedValue: copiedValue
                    )
                }
                .onAppear {
                    viewSize = geometry.size
                }
                .onChange(of: geometry.size) { oldValue, newValue in
                    viewSize = newValue
                }
            }
        }
    }
}

struct PositionDetailView: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let symbol: String
    let atrValue: Double
    let onNavigate: (Int) -> Void
    @State private var priceHistory: CandleList?
    @State private var isLoadingPriceHistory = false
    @State private var isLoadingTransactions = false
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var viewSize: CGSize = .zero
    @StateObject private var loadingState = LoadingState()

    private func formatDate(_ timestamp: Int64?) -> String {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func fetchHistoryForSymbol() async {
        loadingState.isLoading = true
        defer { loadingState.isLoading = false }
        
        isLoadingPriceHistory = true
        isLoadingTransactions = true
        
        if let symbol = position.instrument?.symbol {
            priceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            _ = SchwabClient.shared.getTransactionsFor(symbol: symbol)
        }
        
        isLoadingPriceHistory = false
        isLoadingTransactions = false
    }

    var body: some View {
        ZStack {
            PositionDetailContent(
                position: position,
                accountNumber: accountNumber,
                currentIndex: currentIndex,
                totalPositions: totalPositions,
                symbol: symbol,
                atrValue: atrValue,
                onNavigate: { newIndex in
                    guard newIndex >= 0 && newIndex < totalPositions else { return }
                    loadingState.isLoading = true
                    onNavigate(newIndex)
                },
                priceHistory: priceHistory,
                isLoadingPriceHistory: isLoadingPriceHistory,
                isLoadingTransactions: isLoadingTransactions,
                formatDate: formatDate,
                viewSize: $viewSize
            )
            .padding(.horizontal)
        }
        .onAppear {
            loadingState.isLoading = true
            Task {
                print( " --- onAppear Fetching history for symbol: \(symbol) ---" )
                await fetchHistoryForSymbol()
            }
        }
        .onChange(of: position) { oldValue, newValue in
            loadingState.isLoading = true
            Task {
                print( " --- onChange Fetching history for symbol: \(symbol) ---" )
                await fetchHistoryForSymbol()
            }
        }
        .withLoadingState(loadingState)
    }
} 
