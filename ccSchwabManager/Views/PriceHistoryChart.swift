import SwiftUI
import Charts

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

// MARK: - Supporting Views

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

// MARK: - Price History Section

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

// MARK: - Price History Tab

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