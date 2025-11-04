import SwiftUI

struct EmptyStateView: View
{
    let symbol: String
    let atrValue: Double
    @Binding var sharesAvailableForTrading: Double
    let taxLotDataCount: Int
    let quoteDataAvailable: Bool
    let optionsData: (minimumStrike: Double?, minimumDTE: Int?, contractCount: Int)
    
    var body: some View {
        VStack(spacing: 8) {
            Text("No buy sequence orders available")
                .foregroundColor(.secondary)
            
            // Add debugging information
            VStack(alignment: .leading, spacing: 4) {
                Text("Debug Info:")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Symbol: \(symbol)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("ATR: \(atrValue)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Shares Available: \(sharesAvailableForTrading)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Tax Lots: \(taxLotDataCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Quote Data: \(quoteDataAvailable ? "Available" : "Not Available")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Add options data to debug info
                Text("Options Contracts: \(optionsData.contractCount)")
                    .font(.caption)
                    .foregroundColor(optionsData.contractCount > 0 ? .green : .red)
                if let minStrike = optionsData.minimumStrike {
                    Text("Min Strike: $\(String(format: "%.2f", minStrike))")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Min Strike: Not Available")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if let minDTE = optionsData.minimumDTE {
                    Text("Min DTE: \(minDTE) days")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Min DTE: Not Available")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if optionsData.contractCount == 0 {
                    Text("Note: Buy Sequence Orders require options contracts to be loaded for this symbol")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 4)
                } else {
                    Text("✅ Options data found - Buy Sequence Orders should be available")
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
        }
        .padding()
    }
}

#Preview("Empty State - No Options Available", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 100.0
    EmptyStateView(
        symbol: "AAPL",
        atrValue: 2.5,
        sharesAvailableForTrading: $sharesAvailableForTrading,
        taxLotDataCount: 3,
        quoteDataAvailable: true,
        optionsData: (minimumStrike: nil, minimumDTE: nil, contractCount: 0)
    )
}

#Preview("Empty State - Options Data Available", traits: .landscapeLeft)
{
    @Previewable @State var sharesAvailableForTrading: Double = 50.0
    EmptyStateView(
        symbol: "TSLA",
        atrValue: 3.2,
        sharesAvailableForTrading: $sharesAvailableForTrading,
        taxLotDataCount: 2,
        quoteDataAvailable: false,
        optionsData: (minimumStrike: 180.0, minimumDTE: 45, contractCount: 5)
    )
}
