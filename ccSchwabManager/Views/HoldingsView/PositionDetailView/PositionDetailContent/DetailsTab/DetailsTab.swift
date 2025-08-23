import SwiftUI

struct DetailsTab: View {
    let position: Position
    let accountNumber: String
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let lastPrice: Double
    let quoteData: QuoteData?

    // labels
    let labels = [
        ["P/L%", "ATR", "Market Value", "Asset Type", "Div Yield", "DTE/#"],
        ["P/L", "Quantity", "Average Price", "Last", "Account", "Available"]
    ]


    var body: some View {
        VStack(spacing: 8) {
            // Three-column layout: Left | Spacer | Right
            ForEach(0..<6) { rowIndex in
                HStack(spacing: 0) {
                    ForEach(0..<2)
                    { colIndex in
                        // add spacer before all but first column
                        if colIndex > 0 {
                            // Spacer column - fills the gap
                            Spacer()
                                .frame(minWidth: 1)
                                .padding(.horizontal, 8)
                        }
                        // column
                        HStack(spacing: 12)
                        {
                            Text( labels[ colIndex ][ rowIndex ] )
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 120, alignment: .leading)
                            Text( getFieldValue( rowIndex, colIndex ) )
                                .font(.body)
                                .foregroundColor( getFieldColor( rowIndex, colIndex ) )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
    }

    private func getFieldValue(_ rowIndex: Int, _ colIndex: Int) -> String
    {
        switch colIndex {
            case 0:
                // Left column logic
                switch rowIndex {
                    case 0:
                        let pl = position.longOpenProfitLoss ?? 0
                        let mv = position.marketValue ?? 0
                        let costBasis = mv - pl
                        let plPercent = costBasis != 0 ? (pl / costBasis) * 100 : 0
                        return String(format: "%.1f%%", plPercent)
                    case 1: return String(format: "%.2f %%", atrValue)
                    case 2: return String(format: "%.2f", position.marketValue ?? 0)
                    case 3: return position.instrument?.assetType?.rawValue ?? ""
                    case 4:
                        if let divYield = quoteData?.fundamental?.divYield {
                            return String(format: "%.2f%%", divYield)
                        }
                        return "N/A"
                    case 5: return "" // DTE/# - no value for equity
                    default: return ""
                }
            
            case 1:
                // Right column logic
                switch rowIndex {
                    case 0:
                        let pl = position.longOpenProfitLoss ?? 0
                        return String(format: "%.2f", pl)
                    case 1:
                        let quantity = (position.longQuantity ?? 0) + (position.shortQuantity ?? 0)
                        return String(format: "%.2f", quantity)
                    case 2: return String(format: "%.2f", position.averagePrice ?? 0)
                    case 3: return String(format: "%.2f", lastPrice)
                    case 4: return accountNumber
                    case 5: return String(format: "%.2f", sharesAvailableForTrading)
                    default: return ""
                }

            default:
                AppLogger.shared.warning("Unhandled column index \(colIndex)")
                return ""
        }
    }
    
    private func getFieldColor(_ rowIndex: Int, _ colIndex: Int) -> Color {
        if colIndex == 0 {
            // Left column logic
            switch rowIndex {
            case 0: 
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
            default: return .primary
            }
        } else {
            // Right column logic
            switch rowIndex {
            case 0: 
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
            default: return .primary
            }
        }
    }
    

    

}

#Preview("Details", traits: .landscapeLeft) {
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
