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
    @State private var crosshairPosition: CGPoint = .zero
    @State private var showCrosshair = false
    @State private var plotFrame: CGRect = .zero

    private var tooltipBackgroundColor: Color {
        #if os(macOS)
        Color(.windowBackgroundColor)
        #else
        Color(.systemBackground)
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
    
    private var xAxisRange: ClosedRange<Date> {
        guard !candles.isEmpty else { return Date()...Date() }
        let firstDate = Date(timeIntervalSince1970: TimeInterval(candles.first?.datetime ?? 0) / 1000)
        let lastDate = Date(timeIntervalSince1970: TimeInterval(candles.last?.datetime ?? 0) / 1000)
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -2, to: firstDate) ?? firstDate
        let endDate = calendar.date(byAdding: .day, value: 2, to: lastDate) ?? lastDate
        return startDate...endDate
    }
    
    var body: some View {
        chartContent
    }
    
    @ViewBuilder
    private var chartContent: some View {
        Chart {
            ForEach(candles, id: \.datetime) { candle in
                LineMark(
                    x: .value("Date", Date(timeIntervalSince1970: TimeInterval(candle.datetime ?? 0) / 1000)),
                    y: .value("Price", candle.close ?? 0)
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXScale(domain: xAxisRange)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    let calendar = Calendar.current
                    let isFirstDayOfMonth = calendar.component(.day, from: date) == 1
                    let isFirstOrLastDate = date == xAxisRange.lowerBound || date == xAxisRange.upperBound
                    
                    if isFirstOrLastDate {
                        AxisValueLabel {
                            Text(date, format: .dateTime.year().month().day())
                        }
                    } else if isFirstDayOfMonth {
                        AxisValueLabel {
                            Text(date, format: .dateTime.year().month())
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel(format: .currency(code: "USD").precision(.fractionLength(2)))
            }
        }
        .chartYScale(domain: yAxisRange)
        .chartPlotStyle { plotArea in
            plotArea
                .background(Color.gray.opacity(0.1))
                .border(Color.gray.opacity(0.2))
        }
        .chartOverlay { proxy in
            chartOverlayContent(proxy: proxy)
        }
        .overlay {
            if showCrosshair {
                CrosshairView(
                    crosshairPosition: crosshairPosition,
                    plotFrame: plotFrame
                )
            }
        }
        .overlay {
            TooltipView(
                selectedDate: selectedDate,
                selectedPrice: selectedPrice,
                tooltipPosition: tooltipPosition,
                tooltipBackgroundColor: tooltipBackgroundColor
            )
        }
    }
    
    @ViewBuilder
    private func chartOverlayContent(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onAppear {
                    if let frame = proxy.plotFrame {
                        plotFrame = geometry[frame]
                    }
                }
                .onChange(of: geometry.size) { oldValue, newValue in
                    if let frame = proxy.plotFrame {
                        plotFrame = geometry[frame]
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChange(value: value, proxy: proxy, geometry: geometry)
                        }
                        .onEnded { _ in
                            selectedDate = nil
                            selectedPrice = nil
                            showCrosshair = false
                        }
                )
        }
    }
    
    private func handleDragChange(value: DragGesture.Value, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = proxy.plotFrame else { return }
        let x = value.location.x - geometry[plotFrame].origin.x
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
            crosshairPosition = CGPoint(x: value.location.x, y: value.location.y)
            showCrosshair = true
        }
    }
}

private struct CrosshairView: View {
    let crosshairPosition: CGPoint
    let plotFrame: CGRect
    
    var body: some View {
        // Vertical line
        Path { path in
            path.move(to: CGPoint(x: crosshairPosition.x, y: plotFrame.minY))
            path.addLine(to: CGPoint(x: crosshairPosition.x, y: plotFrame.maxY))
        }
        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        
        // Horizontal line
        Path { path in
            path.move(to: CGPoint(x: plotFrame.minX, y: crosshairPosition.y))
            path.addLine(to: CGPoint(x: plotFrame.maxX, y: crosshairPosition.y))
        }
        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
    }
}

private struct TooltipView: View {
    let selectedDate: Date?
    let selectedPrice: Double?
    let tooltipPosition: CGPoint
    let tooltipBackgroundColor: Color
    
    var body: some View {
        if let date = selectedDate, let price = selectedPrice {
            VStack(alignment: .leading, spacing: 4) {
                Text(date, format: .dateTime.year().month().day())
                    .font(.caption)
                Text(String(format: "$%.2f", price))
                    .font(.caption)
                    .bold()
            }
            .padding(4)
            .background(tooltipBackgroundColor)
            .cornerRadius(4)
            .shadow(radius: 2)
            .position(x: tooltipPosition.x, y: tooltipPosition.y - 40)
        }
    }
}

struct PositionDetailsHeader: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let onNavigate: (Int) -> Void
    let symbol: String
    let atrValue: Double
    let lastPrice: Double
    let quoteData: QuoteData?
    @State private var showDetails = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Previous Position Button
                Button(action: { onNavigate(currentIndex - 1) }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex <= 0)
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Spacer()
                Spacer()

                Text(position.instrument?.symbol ?? "")
                    .font(.title2)
                    .bold()
                
                Spacer()

                // Details disclosure button
                Button(action: {
                    withAnimation {
                        showDetails.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showDetails ? "chevron.down" : "chevron.right")
                            .foregroundColor(.accentColor)
                        Text("Details")
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)

                Spacer()

                // Next Position Button
                Button(action: { onNavigate(currentIndex + 1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= totalPositions - 1)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            if showDetails {
                HStack(spacing: 10) {
                    ForEach(0..<4) { columnIndex in
                        PositionDetailColumn(
                            fields: getFieldsForColumn(columnIndex),
                            position: position,
                            atrValue: atrValue,
                            accountNumber: accountNumber,
                            lastPrice: lastPrice,
                            quoteData: quoteData
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(backgroundColor)
        .frame(maxWidth: .infinity)
    }
    
    private var backgroundColor: Color {
        #if os(macOS)
        Color(.windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
    
    private func getFieldsForColumn(_ columnIndex: Int) -> [PositionDetailField] {
        switch columnIndex {
        case 0: // Performance & Risk
            return [
                .plPercent(atrValue: atrValue),
                .pl,
                .atr(atrValue: atrValue)
            ]
        case 1: // Position Details
            return [
                .quantity,
                .marketValue,
                .averagePrice
            ]
        case 2: // Market Info
            return [
                .assetType,
                .lastPrice(lastPrice: lastPrice),
                .dividendYield
            ]
        case 3: // Account Info
            return [
                .account(accountNumber: accountNumber),
                .symbol,
                .empty
            ]
        default:
            return []
        }
    }
}

// MARK: - Field Definitions

enum PositionDetailField {
    case plPercent(atrValue: Double)
    case pl
    case atr(atrValue: Double)
    case quantity
    case marketValue
    case averagePrice
    case assetType
    case lastPrice(lastPrice: Double)
    case dividendYield
    case account(accountNumber: String)
    case symbol
    case empty
    
    var label: String {
        switch self {
        case .plPercent: return "P/L%"
        case .pl: return "P/L"
        case .atr: return "ATR"
        case .quantity: return "Quantity"
        case .marketValue: return "Market Value"
        case .averagePrice: return "Average Price"
        case .assetType: return "Asset Type"
        case .lastPrice: return "Last"
        case .dividendYield: return "Div Yield"
        case .account: return "Account"
        case .symbol: return "Symbol"
        case .empty: return ""
        }
    }
    
    func getValue(position: Position, atrValue: Double, accountNumber: String, lastPrice: Double, quoteData: QuoteData?) -> String {
        switch self {
        case .plPercent(_):
            let pl = position.longOpenProfitLoss ?? 0
            let mv = position.marketValue ?? 0
            let costBasis = mv - pl
            let plPercent = costBasis != 0 ? (pl / costBasis) * 100 : 0
            return String(format: "%.1f%%", plPercent)
        case .pl:
            return String(format: "%.2f", position.longOpenProfitLoss ?? 0)
        case .atr(let atrValue):
            return "\(String(format: "%.2f", atrValue)) %"
        case .quantity:
            return String(format: "%.2f", ((position.longQuantity ?? 0) + (position.shortQuantity ?? 0)))
        case .marketValue:
            return String(format: "%.2f", position.marketValue ?? 0)
        case .averagePrice:
            return String(format: "%.2f", position.averagePrice ?? 0)
        case .assetType:
            return position.instrument?.assetType?.rawValue ?? ""
        case .lastPrice(let lastPrice):
            return String(format: "%.2f", lastPrice)
        case .dividendYield:
            if let divYield = quoteData?.fundamental?.divYield {
                let formattedYield = String(format: "%.2f%%", divYield)
                print("PositionDetailView - Dividend yield for \(position.instrument?.symbol ?? "unknown"):")
                print("  Raw value: \(divYield)")
                print("  Formatted: \(formattedYield)")
                return formattedYield
            }
            print("PositionDetailView - No dividend yield data for \(position.instrument?.symbol ?? "unknown")")
            return "N/A"
        case .account(let accountNumber):
            return accountNumber
        case .symbol:
            return position.instrument?.symbol ?? ""
        case .empty:
            return ""
        }
    }
    
    func getColor(position: Position, atrValue: Double) -> Color? {
        switch self {
        case .plPercent(let atrValue):
            let pl = position.longOpenProfitLoss ?? 0
            let mv = position.marketValue ?? 0
            let costBasis = mv - pl
            let plPercent = costBasis != 0 ? (pl / costBasis) * 100 : 0
            
            if plPercent < 0 {
                return .red
            }
            let threshold = min(5.0, 2 * atrValue)
            if plPercent <= threshold {
                return .orange
            } else {
                return .green
            }
        case .pl:
            let pl = position.longOpenProfitLoss ?? 0
            let mv = position.marketValue ?? 0
            let costBasis = mv - pl
            let plPercent = costBasis != 0 ? (pl / costBasis) * 100 : 0
            
            if plPercent < 0 {
                return .red
            }
            let threshold = min(5.0, 2 * atrValue)
            if plPercent <= threshold {
                return .orange
            } else {
                return .green
            }
        default:
            return nil
        }
    }
}

// MARK: - Column View

struct PositionDetailColumn: View {
    let fields: [PositionDetailField]
    let position: Position
    let atrValue: Double
    let accountNumber: String
    let lastPrice: Double
    let quoteData: QuoteData?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(fields, id: \.label) { field in
                if field.label.isEmpty {
                    Spacer()
                        .frame(height: 20)
                } else {
                    DetailRow(
                        label: field.label,
                        value: field.getValue(position: position, atrValue: atrValue, accountNumber: accountNumber, lastPrice: lastPrice, quoteData: quoteData)
                    )
                    .foregroundColor(field.getColor(position: position, atrValue: atrValue))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PriceHistorySection: View {
    let priceHistory: CandleList?
    let isLoading: Bool
    let formatDate: (Int64?) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            
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
            .padding(.vertical, 3)
            .foregroundColor(isSell ? .red : .primary)
            Divider()
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                        HStack(spacing: 4) {
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
                        .padding(.vertical, 3)
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
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
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
    let symbol: String
    let atrValue: Double
    let geometry: GeometryProxy

    var body: some View {
        ScrollView {

            SalesCalcView(
                symbol: symbol,
                atrValue: atrValue
            )
            .frame(width: geometry.size.width * 0.96, height: geometry.size.height * 0.45)

            Divider()

            SellListView(
                symbol: symbol,
                atrValue: atrValue
                )
            .frame(width: geometry.size.width * 0.96, height: geometry.size.height * 0.45)

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
    let quoteData: QuoteData?
    @Binding var viewSize: CGSize
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 0) {
            PositionDetailsHeader(
                position: position,
                accountNumber: accountNumber,
                currentIndex: currentIndex,
                totalPositions: totalPositions,
                onNavigate: onNavigate,
                symbol: symbol,
                atrValue: atrValue,
                lastPrice: priceHistory?.candles.last?.close ?? 0.0,
                quoteData: quoteData
            )
            .padding(.bottom, 4)
            
            Divider()
                .padding(.vertical, 4)
            
            GeometryReader { geometry in
                TabView(selection: $selectedTab) {
                    PriceHistoryTab(
                        priceHistory: priceHistory,
                        isLoading: isLoadingPriceHistory,
                        formatDate: formatDate,
                        geometry: geometry
                    )
                    .tag(0)
                    
                    TransactionsTab(
                        isLoading: isLoadingTransactions,
                        symbol: position.instrument?.symbol ?? "",
                        geometry: geometry
                    )
                    .tag(1)
                    
                    SalesCalcTab(
                        symbol: symbol,
                        atrValue: atrValue,
                        geometry: geometry
                    )
                    .tag(2)
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
    @Binding var selectedTab: Int
    @State private var priceHistory: CandleList?
    @State private var isLoadingPriceHistory = false
    @State private var isLoadingTransactions = false
    @State private var quoteData: QuoteData?
    @State private var isLoadingQuote = false
    @EnvironmentObject var secretsManager: SecretsManager
    @State private var viewSize: CGSize = .zero
    @StateObject private var loadingState = LoadingState()

    private func formatDate(_ timestamp: Int64?) -> String {
        guard let timestamp = timestamp else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func fetchHistoryForSymbol() {
        //print("🔍 PositionDetailView.fetchHistoryForSymbol - Setting loading to TRUE")
        loadingState.isLoading = true
        defer { 
            //print("🔍 PositionDetailView.fetchHistoryForSymbol - Setting loading to FALSE")
            loadingState.isLoading = false
        }
        
        // Connect loading state to SchwabClient
        //print("🔗 PositionDetailView - Setting SchwabClient.loadingDelegate")
        SchwabClient.shared.loadingDelegate = loadingState
        
        isLoadingPriceHistory = true
        isLoadingTransactions = true
        isLoadingQuote = true
        
        if let symbol = position.instrument?.symbol {
            priceHistory = SchwabClient.shared.fetchPriceHistory(symbol: symbol)
            _ = SchwabClient.shared.getTransactionsFor(symbol: symbol)
            quoteData = SchwabClient.shared.fetchQuote(symbol: symbol)
        }
        
        isLoadingPriceHistory = false
        isLoadingTransactions = false
        isLoadingQuote = false
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
                quoteData: quoteData,
                viewSize: $viewSize,
                selectedTab: $selectedTab
            )
            .padding(.horizontal)
        }
        .onAppear {
            loadingState.isLoading = true
            fetchHistoryForSymbol()
        }
        .onDisappear {
            //print("🔗 PositionDetailView - Clearing SchwabClient.loadingDelegate")
            SchwabClient.shared.loadingDelegate = nil
        }
        .onChange(of: position) { oldValue, newValue in
            loadingState.isLoading = true
            fetchHistoryForSymbol()
        }
        .withLoadingState(loadingState)
    }
} 

