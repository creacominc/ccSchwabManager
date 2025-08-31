import SwiftUI

/// Component responsible for displaying recommended sell orders
struct SellOrdersSection: View {
    
    // MARK: - Properties
    let sellOrders: [SalesCalcResultsRecord]
    let selectedIndex: Int?
    let sharesAvailableForTrading: Double
    let onOrderSelection: (Int?) -> Void
    let onCopyValue: (Double, String) -> Void
    let onCopyText: (String) -> Void
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 8) {
            sellOrdersHeaderRow
            
            if sellOrders.isEmpty {
                Text("No sell orders available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(sellOrders.enumerated()), id: \.element.id) { index, order in
                    sellOrderRow(
                        order: order,
                        index: index,
                        isSelected: selectedIndex == index
                    )
                }
            }
        }
    }
    
    // MARK: - Header Row
    private var sellOrdersHeaderRow: some View {
        HStack {
            Text("")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            
            Text("Description")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Shares")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
            
            Text("Stop")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .trailing)
            
            Text("Target")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color.red.opacity(0.1))
    }
    
    // MARK: - Order Row
    private func sellOrderRow(order: SalesCalcResultsRecord, index: Int, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            // First line: checkbox, shares, stop, target
            HStack {
                Button(action: {
                    onOrderSelection(isSelected ? nil : index)
                }) {
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 30, alignment: .center)
                
                Spacer()
                
                Text("\(Int(order.sharesToSell))")
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        onCopyValue(order.sharesToSell, "%.0f")
                    }
                
                Text(String(format: "%.2f%%", order.trailingStop))
                    .font(.caption)
                    .frame(width: 100, alignment: .trailing)
                    .onTapGesture {
                        onCopyValue(order.trailingStop, "%.2f")
                    }
                
                Text(String(format: "%.2f", order.target))
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        onCopyValue(order.target, "%.2f")
                    }
            }
            
            // Second line: description
            HStack {
                Text(order.description)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        onCopyText(order.description)
                    }
            }
            .padding(.leading, 30) // Align with content above checkbox
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(isSelected ? Color.red.opacity(0.2) : Color.red.opacity(0.05))
        .cornerRadius(4)
    }
}

// MARK: - Previews
#Preview("SellOrdersSection - With Orders") {
    let mockOrders = [
        SalesCalcResultsRecord(
            shares: 100,
            rollingGainLoss: 500,
            breakEven: 150.0,
            gain: 3.33,
            sharesToSell: 100,
            trailingStop: 2.5,
            entry: 155.0,
            target: 157.5,
            cancel: 153.0,
            description: "(Top 100) SELL -100 AAPL Target 157.50 TS 2.50% Cost/Share 150.00",
            openDate: "Top100"
        ),
        SalesCalcResultsRecord(
            shares: 50,
            rollingGainLoss: 250,
            breakEven: 152.0,
            gain: 3.62,
            sharesToSell: 50,
            trailingStop: 3.0,
            entry: 154.0,
            target: 156.5,
            cancel: 152.0,
            description: "(Min BE) SELL -50 AAPL Target 156.50 TS 3.00% Cost/Share 152.00",
            openDate: "MinBE"
        )
    ]
    
    return SellOrdersSection(
        sellOrders: mockOrders,
        selectedIndex: 0,
        sharesAvailableForTrading: 150,
        onOrderSelection: { _ in },
        onCopyValue: { _, _ in },
        onCopyText: { _ in }
    )
    .padding()
}

#Preview("SellOrdersSection - Empty") {
    SellOrdersSection(
        sellOrders: [],
        selectedIndex: nil,
        sharesAvailableForTrading: 0,
        onOrderSelection: { _ in },
        onCopyValue: { _, _ in },
        onCopyText: { _ in }
    )
    .padding()
}
