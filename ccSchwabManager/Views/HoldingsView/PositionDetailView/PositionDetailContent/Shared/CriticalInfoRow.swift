import SwiftUI

struct CriticalInfoRow: View
{
    let sharesAvailableForTrading: Double?
    let marketValue: Double?
    let position: Position
    let lastPrice: Double
    let atrValue: Double
    
    /// Initializer for full display (e.g., OCOOrdersTab)
    init(
        sharesAvailableForTrading: Double,
        marketValue: Double,
        position: Position,
        lastPrice: Double,
        atrValue: Double
    ) {
        self.sharesAvailableForTrading = sharesAvailableForTrading
        self.marketValue = marketValue
        self.position = position
        self.lastPrice = lastPrice
        self.atrValue = atrValue
    }
    
    /// Initializer for compact display (e.g., SequenceOrdersTab)
    init(
        position: Position,
        lastPrice: Double,
        atrValue: Double
    ) {
        self.sharesAvailableForTrading = nil
        self.marketValue = nil
        self.position = position
        self.lastPrice = lastPrice
        self.atrValue = atrValue
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            
            // Available Shares (optional)
            if let availableShares = sharesAvailableForTrading {
                HStack(spacing: 4) {
                    Text("Avail: ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f", availableShares))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            // Market Value (optional)
            if let mktValue = marketValue {
                HStack(spacing: 4) {
                    Text("Mkt: ")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f", mktValue))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
            
            // P/L%
            HStack(spacing: 4) {
                Text("P/L%: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.1f%%", calculatePLPercent()))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(getPLColor())
            }
            
            // Last Price
            HStack(spacing: 4) {
                Text("Last: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", lastPrice))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Quantity
            HStack(spacing: 4) {
                Text("Qty: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f", (position.longQuantity ?? 0) + (position.shortQuantity ?? 0)))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // ATR
            HStack(spacing: 4) {
                Text("ATR: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(String(format: "%.2f%%", atrValue))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // DTE/# (empty for equity, could be populated for options)
            HStack(spacing: 4) {
                Text("DTE/#: ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("") // Empty for equity, could be populated for options
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Text(" ")
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



