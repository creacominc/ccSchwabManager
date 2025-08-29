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
            // Two-column layout: Left | Spacer | Right
            HStack(spacing: 0) {
                // Spacer before columns
                Spacer()
                    .frame(minWidth: 1)
                    .padding(.horizontal, 16)

                // Left column
                VStack(spacing: 0) {
                    ForEach(0..<6) { rowIndex in
                        HStack(spacing: 12) {
                            Text(labels[0][rowIndex])
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 120, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(getFieldValue(rowIndex, 0))
                                .font(.body)
                                .foregroundColor(getFieldColor(rowIndex, 0))
                                .frame(minWidth: 80, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // Spacer between columns
                Spacer()
                    .frame(minWidth: 1)
                    .padding(.horizontal, 16)
                
                // Right column
                VStack(spacing: 0) {
                    ForEach(0..<6) { rowIndex in
                        HStack(spacing: 12) {
                            Text(labels[1][rowIndex])
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 120, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(getFieldValue(rowIndex, 1))
                                .font(.body)
                                .foregroundColor(getFieldColor(rowIndex, 1))
                                .frame(minWidth: 80, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Spacer after columns
                Spacer()
                    .frame(minWidth: 1)
                    .padding(.horizontal, 16)

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
    
    return VStack {
        createMockTabBar()
        DetailsTab(
            position: samplePosition,
            accountNumber: "767",
            symbol: "TATT",
            atrValue: 7.70,
            sharesAvailableForTrading: 7.0,
            lastPrice: 36.55,
            quoteData: nil
        )
    }
}


@MainActor
private func createMockTabBar() -> some View {
    HStack(spacing: 0) {
        TabButton(
            title: "Details",
            icon: "info.circle",
            isSelected: true,
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
