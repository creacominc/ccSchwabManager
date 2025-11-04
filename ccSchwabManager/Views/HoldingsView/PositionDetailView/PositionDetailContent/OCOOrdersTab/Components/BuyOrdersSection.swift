import SwiftUI

/// Component responsible for displaying recommended buy orders
struct BuyOrdersSection: View {
    
    // MARK: - Properties
    let buyOrders: [BuyOrderRecord]
    let selectedIndex: Int?
    let onOrderSelection: (Int?) -> Void
    let onCopyValue: (Double, String) -> Void
    let onCopyText: (String) -> Void
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 8) {
            buyOrdersHeaderRow
            
            if buyOrders.isEmpty {
                Text("No buy orders available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(buyOrders.enumerated()), id: \.element.id) { index, order in
                    buyOrderRow(
                        order: order,
                        index: index,
                        isSelected: selectedIndex == index
                    )
                }
            }
        }
    }
    
    // MARK: - Header Row
    private var buyOrdersHeaderRow: some View {
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
        .background(Color.blue.opacity(0.1))
    }
    
    // MARK: - Order Row
    private func buyOrderRow(order: BuyOrderRecord, index: Int, isSelected: Bool) -> some View {
        VStack(spacing: 4) {
            // First line: checkbox, shares, stop, target
            HStack {
                Button(action: {
                    onOrderSelection(isSelected ? nil : index)
                }) {
                    Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 30, alignment: .center)
                
                Spacer()
                
                Text("\(Int(order.sharesToBuy))")
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        onCopyValue(order.sharesToBuy, "%.0f")
                    }
                
                Text(String(format: "%.2f%%", order.trailingStop))
                    .font(.caption)
                    .frame(width: 100, alignment: .trailing)
                    .onTapGesture {
                        onCopyValue(order.trailingStop, "%.2f")
                    }
                
                Text(String(format: "%.2f", order.targetBuyPrice))
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        onCopyValue(order.targetBuyPrice, "%.2f")
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
        .background(isSelected ? Color.blue.opacity(0.2) : Color.blue.opacity(0.05))
        .cornerRadius(4)
    }
}

// MARK: - Previews
#Preview("BuyOrdersSection - With Orders") {
    let mockOrders = [
        BuyOrderRecord(
            shares: 100,
            targetBuyPrice: 150.0,
            entryPrice: 148.0,
            trailingStop: 2.0,
            targetGainPercent: 8.0,
            currentGainPercent: 5.0,
            sharesToBuy: 100,
            orderCost: 15000.0,
            description: "BUY 100 AAPL (10%) Target=150.00 TS=2.0% Gain=8.0% Cost=15000.00",
            orderType: "BUY",
            submitDate: "",
            isImmediate: false
        ),
        BuyOrderRecord(
            shares: 50,
            targetBuyPrice: 149.0,
            entryPrice: 147.0,
            trailingStop: 2.5,
            targetGainPercent: 10.0,
            currentGainPercent: 5.0,
            sharesToBuy: 50,
            orderCost: 7450.0,
            description: "BUY 50 AAPL (5%) Target=149.00 TS=2.5% Gain=10.0% Cost=7450.00",
            orderType: "BUY",
            submitDate: "",
            isImmediate: false
        )
    ]
    
    return BuyOrdersSection(
        buyOrders: mockOrders,
        selectedIndex: 0,
        onOrderSelection: { _ in },
        onCopyValue: { _, _ in },
        onCopyText: { _ in }
    )
    .padding()
}

#Preview("BuyOrdersSection - Empty") {
    BuyOrdersSection(
        buyOrders: [],
        selectedIndex: nil,
        onOrderSelection: { _ in },
        onCopyValue: { _, _ in },
        onCopyText: { _ in }
    )
    .padding()
}
