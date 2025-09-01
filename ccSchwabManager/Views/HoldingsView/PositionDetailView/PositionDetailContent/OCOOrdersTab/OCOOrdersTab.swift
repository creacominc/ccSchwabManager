import SwiftUI

struct OCOOrdersTab: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let sharesAvailableForTrading: Double
    let quoteData: QuoteData?
    let accountNumber: String
    let position: Position
    let lastPrice: Double
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // OCO Orders Section
                VStack(alignment: .leading, spacing: 0) {
                    // Section Header with critical information
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.green)
                        Text("Recommended Orders (Single or OCO)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Critical information on the same line
                        criticalInfoRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.green.opacity(0.1))
                    
                    // Section Content - Using refactored version for better maintainability
                    RecommendedOCOOrdersSection(
                        symbol: symbol,
                        atrValue: atrValue,
                        sharesAvailableForTrading: sharesAvailableForTrading,
                        quoteData: quoteData,
                        accountNumber: accountNumber
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                // Add bottom padding to ensure content is fully visible
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.black.opacity(0.1))
    }
    
    private var criticalInfoRow: some View {
        HStack(spacing: 16) {
            // P/L%
            HStack(spacing: 4) {
                Text("P/L%:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", calculatePLPercent()))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(getPLColor())
            }
            
            // Last Price
            HStack(spacing: 4) {
                Text("Last:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", lastPrice))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Quantity
            HStack(spacing: 4) {
                Text("Qty:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", (position.longQuantity ?? 0) + (position.shortQuantity ?? 0)))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // ATR
            HStack(spacing: 4) {
                Text("ATR:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f%%", atrValue))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // DTE/# (empty for equity, could be populated for options)
            HStack(spacing: 4) {
                Text("DTE/#:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("") // Empty for equity, could be populated for options
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
    
    private func calculatePLPercent() -> Double {
        let pl = position.longOpenProfitLoss ?? 0
        let mv = position.marketValue ?? 0
        let costBasis = mv - pl
        return costBasis != 0 ? (pl / costBasis) * 100 : 0
    }
    
    private func getPLColor() -> Color {
        let plPercent = calculatePLPercent()
        if plPercent < 0 {
            return .red
        }
        let threshold = min(5.0, 2 * atrValue)
        if plPercent <= threshold {
            return .orange
        } else {
            return .green
        }
    }
}

#Preview("OCOOrdersTab - With Data", traits: .landscapeLeft) {
    VStack(spacing: 0) {
        createMockTabBar()
        OCOOrdersTab(
            symbol: "AAPL",
            atrValue: 2.45,
            taxLotData: createMockTaxLotData(),
            sharesAvailableForTrading: 500.0,
            quoteData: createMockQuoteData(),
            accountNumber: "123456789",
            position: Position(shortQuantity: 50, longQuantity: 100, marketValue: 17550.0, longOpenProfitLoss: 2525.0),
            lastPrice: 175.50
        )
        .background(Color.blue.opacity(0.1))
    }
}

#Preview("OCOOrdersTab - No Data", traits: .landscapeLeft) {
    VStack(spacing: 0) {
        createMockTabBar()
        OCOOrdersTab(
            symbol: "XYZ",
            atrValue: 0.0,
            taxLotData: [],
            sharesAvailableForTrading: 0.0,
            quoteData: nil,
            accountNumber: "987654321",
            position: Position(shortQuantity: 0, longQuantity: 0, marketValue: 0.0, longOpenProfitLoss: 0.0),
            lastPrice: 0.0
        )
        .background(Color.blue.opacity(0.1))
    }
}

// MARK: - Mock Data for Previews
private func createMockTaxLotData() -> [SalesCalcPositionsRecord] {
    return [
        SalesCalcPositionsRecord(
            openDate: "2024-01-15 09:30:43",
            gainLossPct: 16.8,
            gainLossDollar: 2525.00,
            quantity: 100,
            price: 175.50,
            costPerShare: 150.25,
            marketValue: 17550.00,
            costBasis: 15025.00
        ),
        SalesCalcPositionsRecord(
            openDate: "2024-03-20 14:11:00",
            gainLossPct: 20.4,
            gainLossDollar: 1487.50,
            quantity: 50,
            price: 175.50,
            costPerShare: 145.75,
            marketValue: 8775.00,
            costBasis: 7287.50
        ),
        SalesCalcPositionsRecord(
            openDate: "2024-06-10 11:30:00",
            gainLossPct: 9.7,
            gainLossDollar: 1162.50,
            quantity: 75,
            price: 175.50,
            costPerShare: 160.00,
            marketValue: 13162.50,
            costBasis: 12000.00
        )
    ]
}

private func createMockQuoteData() -> QuoteData {
    let quote = Quote(
        askPrice: 175.55,
        askSize: 150,
        bidPrice: 175.45,
        bidSize: 200,
        closePrice: 174.50,
        highPrice: 176.25,
        lastPrice: 175.50,
        lastSize: 100,
        lowPrice: 173.75,
        netChange: 1.00,
        openPrice: 174.00,
        totalVolume: 5000000
    )
    
    let regularMarket = RegularMarket(
        regularMarketLastPrice: 174.50,
        regularMarketLastSize: 100,
        regularMarketNetChange: 0.75,
        regularMarketTradeTime: 1640995200
    )
    
    return QuoteData(
        assetMainType: "EQUITY",
        assetSubType: "COMMON_STOCK",
        quoteType: "REALTIME",
        realtime: true,
        ssid: 12345,
        symbol: "AAPL",
        extended: nil,
        fundamental: nil,
        quote: quote,
        reference: nil,
        regular: regularMarket
    )
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
            isSelected: false,
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
            icon: "calculator",
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
            isSelected: true,
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


