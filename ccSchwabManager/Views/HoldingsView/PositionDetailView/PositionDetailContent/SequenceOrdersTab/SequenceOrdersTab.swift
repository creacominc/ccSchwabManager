import SwiftUI

struct SequenceOrdersTab: View {
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
                // Buy Sequence Orders Section
                VStack(alignment: .leading, spacing: 0) {
                    // Section Header with critical information
                    HStack {
                        Image(systemName: "arrow.up.circle")
                            .foregroundColor(.orange)
                        Text("Buy Sequence Orders")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Critical information on the same line
                        criticalInfoRow
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.1))
                    
                    // Section Content
                    BuySequenceOrdersSection(
                        symbol: symbol,
                        atrValue: atrValue,
                        taxLotData: taxLotData,
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
