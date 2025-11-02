import SwiftUI

// IOS or VisionOS
#if os(iOS) ||  os(visionOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct SalesCalcView: View {
    let symbol: String
    let atrValue: Double
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    let quoteData: QuoteData?

    @State private var currentSort: SalesCalcSortConfig? = SalesCalcSortConfig(column: .costPerShare, ascending: SalesCalcSortableColumn.costPerShare.defaultAscending )
    @State private var showIncompleteDataWarning = false
    
    private func getCurrentPrice() -> Double {
        // Use quote data for current price, fallback to price history if quote is not available
        if let quote = quoteData?.quote?.lastPrice {
            return quote
        } else if let extended = quoteData?.extended?.lastPrice {
            return extended
        } else if let regular = quoteData?.regular?.regularMarketLastPrice {
            return regular
        } else {
            // Fallback to a default value if no quote data is available
            return 0.0
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if isLoadingTaxLots
                {
                    ProgressView()
                        .progressViewStyle( CircularProgressViewStyle( tint: .accentColor ) )
                        .scaleEffect(2.0, anchor: .center)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                else
                {
                    SalesCalcTable(
                        positionsData: taxLotData,
                        currentSort: $currentSort,
                        symbol: symbol,
                        currentPrice: getCurrentPrice()
                    )
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            print("SalesCalcView: onAppear - taxLotData count: \(taxLotData.count), isLoadingTaxLots: \(isLoadingTaxLots)")
            if !taxLotData.isEmpty {
                print("SalesCalcView: First record - Qty: \(taxLotData[0].quantity), Price: \(taxLotData[0].price)")
            }
        }
        .onChange(of: SchwabClient.shared.showIncompleteDataWarning) { oldValue, newValue in
            showIncompleteDataWarning = newValue
        }
        .alert("Incomplete Data Warning", isPresented: $showIncompleteDataWarning) {
            Button("OK") { }
        } message: {
            Text("Some data may be incomplete or missing. Please refresh to get the latest information.")
        }
    }

} // SalesCalcView

#Preview("SalesCalcView - With Data", traits: .landscapeLeft) {
    SalesCalcView(
        symbol: "AAPL",
        atrValue: 2.45,
        taxLotData: createMockTaxLotData(),
        isLoadingTaxLots: false,
        quoteData: createMockQuoteData()
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal)
}

#Preview("SalesCalcView - Loading State", traits: .landscapeLeft) {
    SalesCalcView(
        symbol: "TSLA",
        atrValue: 3.12,
        taxLotData: [],
        isLoadingTaxLots: true,
        quoteData: nil
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal)
}

#Preview("SalesCalcView - No Data", traits: .landscapeLeft) {
    SalesCalcView(
        symbol: "NVDA",
        atrValue: 1.87,
        taxLotData: [],
        isLoadingTaxLots: false,
        quoteData: nil
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal)
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

