import SwiftUI

struct DetailsTab: View {
    let position: Position
    let accountNumber: String
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let lastPrice: Double
    let quoteData: QuoteData?
    
    var body: some View {
        VStack(spacing: 8) {
            // Simple 2-column, 6-row table layout
            ForEach(0..<6) { rowIndex in
                HStack(spacing: 0) {
                    // Left column
                    HStack(spacing: 12) {
                        Text(getFieldForRow(rowIndex, column: 0).label)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(width: 100, alignment: .leading)
                        Text(getFieldForRow(rowIndex, column: 0).getValue(
                            position: position,
                            atrValue: atrValue,
                            sharesAvailableForTrading: sharesAvailableForTrading,
                            accountNumber: accountNumber,
                            lastPrice: lastPrice,
                            quoteData: quoteData
                        ))
                        .font(.body)
                        .foregroundColor(getFieldForRow(rowIndex, column: 0).getColor(position: position, atrValue: atrValue))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Right column
                    HStack(spacing: 12) {
                        Text(getFieldForRow(rowIndex, column: 1).label)
                            .font(.body)
                            .foregroundColor(.primary)
                            .frame(width: 100, alignment: .leading)
                        Text(getFieldForRow(rowIndex, column: 1).getValue(
                            position: position,
                            atrValue: atrValue,
                            sharesAvailableForTrading: sharesAvailableForTrading,
                            accountNumber: accountNumber,
                            lastPrice: lastPrice,
                            quoteData: quoteData
                        ))
                        .font(.body)
                        .foregroundColor(getFieldForRow(rowIndex, column: 1).getColor(position: position, atrValue: atrValue))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
    }
    
    private func getFieldForRow(_ rowIndex: Int, column: Int) -> PositionDetailField {
        let fields: [[PositionDetailField]] = [
            // Row 0: P/L% | P/L
            [.plPercent(atrValue: atrValue), .pl],
            // Row 1: ATR | Quantity  
            [.atr(atrValue: atrValue), .quantity],
            // Row 2: Market Value | Average Price
            [.marketValue, .averagePrice],
            // Row 3: Asset Type | Last Price
            [.assetType, .lastPrice(lastPrice: lastPrice)],
            // Row 4: Dividend Yield | Account
            [.dividendYield, .account(accountNumber: accountNumber)],
            // Row 5: DTE/# | Available
            [.dte, .sharesAvailableForTrading(sharesAvailableForTrading: sharesAvailableForTrading)]
        ]
        
        return fields[rowIndex][column]
    }
    

}

#Preview {
    let samplePosition = Position(
        shortQuantity: 0.0,
        averagePrice: 35.48,
        longQuantity: 18.0,
        instrument: Instrument(
            assetType: .EQUITY,
            symbol: "TATT",
            description: "TAT Technologies Ltd."
        )
    )
    
    return DetailsTab(
        position: samplePosition,
        accountNumber: "767",
        symbol: "TATT",
        atrValue: 7.70,
        sharesAvailableForTrading: 7.0,
        lastPrice: 36.55,
        quoteData: nil
    )
}
