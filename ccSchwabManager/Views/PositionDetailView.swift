import SwiftUI

struct PositionDetailView: View {
    let position: Position
    let accountNumber: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(position.instrument?.symbol ?? "")
                .font(.title)
                .padding(.bottom)
                .onAppear {
                    print(position.instrument?.symbol ?? "") 
                }
            
            Group {
                DetailRow(label: "Description", value: position.instrument?.description ?? "")
                DetailRow(label: "Quantity", value: String(format: "%.2f", position.longQuantity ?? 0))
                DetailRow(label: "Average Price", value: String(format: "%.2f", position.averagePrice ?? 0))
                DetailRow(label: "Market Value", value: String(format: "%.2f", position.marketValue ?? 0))
                DetailRow(label: "P/L", value: String(format: "%.2f", position.longOpenProfitLoss ?? 0))
                DetailRow(label: "P/L %", value: String(format: "%.1f%%", 
                    (position.longOpenProfitLoss ?? 0) / (position.marketValue ?? 1) * 100))
                DetailRow(label: "Asset Type", value: position.instrument?.assetType?.rawValue ?? "")
                DetailRow(label: "Account", value: accountNumber)
            }
        }
        .padding()
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .monospacedDigit()
        }
    }
} 