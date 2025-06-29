import SwiftUI

// MARK: - Helper Functions

private func extractExpirationDate(from symbol: String?, description: String?) -> Date? {
    // Primary method: Extract 6-digit date from option symbol
    if let symbol = symbol {
        // Look for 6 consecutive digits after the underlying symbol
        // Example: "INTC  250516C00025000" -> extract "250516"
        let pattern = #"(\d{6})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: symbol, range: NSRange(symbol.startIndex..., in: symbol)) {
            let dateString = String(symbol[Range(match.range(at: 1), in: symbol)!])
            
            // Parse the date (format: YYMMDD)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyMMdd"
            formatter.timeZone = TimeZone.current
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
    }
    
    // Secondary method: Extract date from description
    if let description = description {
        // Look for date pattern like "05/16/2025" or "2025-01-16"
        let patterns = [
            #"(\d{1,2})/(\d{1,2})/(\d{4})"#,  // MM/DD/YYYY
            #"(\d{4})-(\d{1,2})-(\d{1,2})"#   // YYYY-MM-DD
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
                
                let formatter = DateFormatter()
                if pattern.contains("/") {
                    formatter.dateFormat = "MM/dd/yyyy"
                } else {
                    formatter.dateFormat = "yyyy-MM-dd"
                }
                formatter.timeZone = TimeZone.current
                
                let dateString = String(description[Range(match.range, in: description)!])
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }
    }
    
    return nil
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
    case dte
    case sharesAvailableForTrading
    
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
        case .dte: return "DTE/#"
        case .sharesAvailableForTrading: return "Available"
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
                // print("PositionDetailField - Dividend yield for \(position.instrument?.symbol ?? "unknown"):")
                // print("  Raw value: \(divYield)")
                // print("  Formatted: \(formattedYield)")
                return formattedYield
            }
            // print("PositionDetailField - No dividend yield data for \(position.instrument?.symbol ?? "unknown")")
            return "N/A"
        case .account(let accountNumber):
            return accountNumber
        case .dte:
            // Use the efficient DTE methods from SchwabClient
            let dte : Int? = SchwabClient.shared.getDTEForPosition(position)
            let count : Double = SchwabClient.shared.getContractCountForSymbol(position.instrument?.symbol ?? "")
            // return the DTE and the number of contracts
            return (nil == dte) ? "" : String( format: "%d / %.1f", dte ?? 0, count )
        case .sharesAvailableForTrading:
            return String( format: "%.1f", SchwabClient.shared.getSharesAvailableForTrade(for: position.instrument?.symbol ?? "") )
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
