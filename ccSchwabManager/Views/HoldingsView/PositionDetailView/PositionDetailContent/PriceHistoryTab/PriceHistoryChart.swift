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
        // Only extend slightly to ensure labels are visible: start 1 day earlier, end 1 day later
        let startDate = calendar.date(byAdding: .day, value: -1, to: firstDate) ?? firstDate
        let endDate = calendar.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
        return startDate...endDate
    }
    
    private func formatDate(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    
    private func isFirstDayOfQuarter(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        
        // Quarters start in January (1), April (4), July (7), October (10)
        // and on the 1st day of the month
        return (month == 1 || month == 4 || month == 7 || month == 10) && day == 1
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
                if let date : Date = value.as(Date.self) {
                    // Only show labels for the first and last actual data points
                    let firstDataDate = Date(timeIntervalSince1970: TimeInterval(candles.first?.datetime ?? 0) / 1000)
                    let lastDataDate = Date(timeIntervalSince1970: TimeInterval(candles.last?.datetime ?? 0) / 1000)
                    
                    if Calendar.current.isDate(date, inSameDayAs: firstDataDate) {
                        AxisValueLabel {
                            Text(formatDate(date, format: "MM-dd"))
                        }
                    } else if Calendar.current.isDate(date, inSameDayAs: lastDataDate) {
                        AxisValueLabel {
                            Text(formatDate(date, format: "yyyy-MM-dd"))
                        }
                    } else if isFirstDayOfQuarter(date) {
                        AxisValueLabel {
                            Text(formatDate(date, format: "MM"))
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

#Preview("PriceHistoryChart", traits: .landscapeLeft) {
    let calendar = Calendar.current
    let now = Date()
    
    // Create sample data spanning a full year with monthly data points
    let sampleCandles = [
        // January (Q1)
        Candle(
            close: 145.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -11, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 148.0,
            low: 142.0,
            open: 143.0,
            volume: 1200000
        ),
        // February (Q1)
        Candle(
            close: 152.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -10, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 155.0,
            low: 149.0,
            open: 145.0,
            volume: 1350000
        ),
        // March (Q1)
        Candle(
            close: 158.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -9, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 161.0,
            low: 155.0,
            open: 152.0,
            volume: 1500000
        ),
        // April (Q2)
        Candle(
            close: 162.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -8, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 165.0,
            low: 159.0,
            open: 158.0,
            volume: 1400000
        ),
        // May (Q2)
        Candle(
            close: 168.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -7, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 171.0,
            low: 163.0,
            open: 162.0,
            volume: 1600000
        ),
        // June (Q2)
        Candle(
            close: 175.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -6, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 178.0,
            low: 172.0,
            open: 168.0,
            volume: 1700000
        ),
        // July (Q3)
        Candle(
            close: 182.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -5, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 185.0,
            low: 179.0,
            open: 175.0,
            volume: 1800000
        ),
        // August (Q3)
        Candle(
            close: 188.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -4, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 191.0,
            low: 185.0,
            open: 182.0,
            volume: 1900000
        ),
        // September (Q3)
        Candle(
            close: 195.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -3, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 198.0,
            low: 192.0,
            open: 188.0,
            volume: 2000000
        ),
        // October (Q4)
        Candle(
            close: 190.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -2, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 193.0,
            low: 187.0,
            open: 195.0,
            volume: 1800000
        ),
        // November (Q4)
        Candle(
            close: 185.0,
            datetime: Int64(calendar.date(byAdding: .month, value: -1, to: now)?.timeIntervalSince1970 ?? 0) * 1000,
            high: 188.0,
            low: 182.0,
            open: 190.0,
            volume: 1700000
        ),
        // December (Q4) - Current month
        Candle(
            close: 180.0,
            datetime: Int64(now.timeIntervalSince1970) * 1000,
            high: 183.0,
            low: 178.0,
            open: 185.0,
            volume: 1600000
        )
    ]
    
    return PriceHistoryChart(candles: sampleCandles)
        .padding()
}

 


