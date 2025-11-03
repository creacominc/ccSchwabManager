import SwiftUI

struct SalesCalcTab: View
{
    let symbol: String
    let atrValue: Double
    let position: Position
    @Binding var sharesAvailableForTrading: Double
    @Binding var marketValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    let quoteData: QuoteData?
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
                    Image(systemName: "number.circle.fill")
                        .foregroundColor(.blue)
                    Text("Sales Calc")
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

                SalesCalcView(
                    symbol: symbol,
                    atrValue: atrValue,
                    taxLotData: taxLotData,
                    isLoadingTaxLots: isLoadingTaxLots,
                    quoteData: quoteData
                )
                .frame(height: geometry.size.height - 50) // Subtract approximate header height
            }
        }
    }
}

#Preview("SalesCalcTab - With Data", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 500
    @Previewable @State var marketValue: Double = 300.0
    let atrValue: Double = 2.45 // Initial value from parent, will be recomputed
    let lastPrice: Double = 50.50
    
    VStack(spacing: 0)
    {
        // Simulate the tab button area
        createMockTabBar()
        // Tab content area
        SalesCalcTab(
            symbol: "AAPL",
            atrValue: atrValue,
            position: Position(shortQuantity: 0, longQuantity: 0,
                               marketValue: marketValue, longOpenProfitLoss: 0.0),
            sharesAvailableForTrading: $sharesAvailableForTrading,
            marketValue: $marketValue,
            taxLotData: createMockTaxLotData(),
            isLoadingTaxLots: false,
            quoteData: createMockQuoteData(),
            lastPrice: lastPrice
        )
        .background(Color.blue.opacity(0.1)) // Add background to see the content area
    }
}

#Preview("SalesCalcTab - Loading State", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 300.0
    @Previewable @State var marketValue: Double = 300.0
    let atrValue: Double = 3.12 // Initial value from parent, will be recomputed
    let lastPrice: Double = 50.50

    VStack(spacing: 0)
    {
        // Simulate the tab button area
        createMockTabBar()
        
        // Tab content area
        SalesCalcTab(
            symbol: "TSLA",
            atrValue: atrValue,
            position: Position(shortQuantity: 0, longQuantity: 0,
                               marketValue: marketValue, longOpenProfitLoss: 0.0),
            sharesAvailableForTrading: $sharesAvailableForTrading,
            marketValue: $marketValue,
            taxLotData: createMockTaxLotData(),
            isLoadingTaxLots: true,
            quoteData: createMockQuoteData(),
            lastPrice: lastPrice
        )
    }
}

#Preview("SalesCalcTab - No Data", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 200.0
    @Previewable @State var marketValue: Double = 300.0
    let atrValue: Double = 1.87 // Initial value from parent, will be recomputed
    let lastPrice: Double = 50.50

    VStack(spacing: 0)
    {
        // Simulate the tab button area
        createMockTabBar()

        // Tab content area
        SalesCalcTab(
            symbol: "NVDA",
            atrValue: atrValue,
            position: Position(shortQuantity: 0, longQuantity: 0,
                               marketValue: marketValue, longOpenProfitLoss: 0.0),
            sharesAvailableForTrading: $sharesAvailableForTrading,
            marketValue: $marketValue,
            taxLotData: [],
            isLoadingTaxLots: false,
            quoteData: createMockQuoteData(),
            lastPrice: lastPrice
        )
    }
}

// MARK: - Mock Data for Previews
private func createMockTaxLotData() -> [SalesCalcPositionsRecord]
{
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

private func createMockQuoteData() -> QuoteData
{
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
private func createMockTabBar() -> some View
{
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
            icon: "number.circle.fill",
            isSelected: true,
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
