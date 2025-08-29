import SwiftUI

struct OrderTableView: View {
    let sequenceOrders: [BuySequenceOrder]
    let adjustedSequenceOrders: [BuySequenceOrder]
    let selectedSequenceOrderIndices: Set<Int>
    let onOrderSelectionChanged: (Int, Bool) -> Void
    let onSubmitSequenceOrders: () -> Void
    let onCopyToClipboard: (Double, String) -> Void
    let onCopyTextToClipboard: (String) -> Void
    
    var body: some View {
        HStack {
            ScrollView {
                VStack(spacing: 0) {
                    OrderTableHeaderView()
                    OrderTableRowsView(
                        sequenceOrders: sequenceOrders,
                        adjustedSequenceOrders: adjustedSequenceOrders,
                        selectedSequenceOrderIndices: selectedSequenceOrderIndices,
                        onOrderSelectionChanged: onOrderSelectionChanged,
                        onCopyToClipboard: onCopyToClipboard,
                        onCopyTextToClipboard: onCopyTextToClipboard
                    )
                }
            }
            
            VStack {
                Spacer()
                if !selectedSequenceOrderIndices.isEmpty {
                    Button(action: onSubmitSequenceOrders) {
                        VStack(spacing: 4) {
                            Image(systemName: "paperplane.circle.fill")
                                .font(.title3)
                            Text("Submit\nSequence")
                                .font(.caption2)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                }
                Spacer()
            }
            .padding(.trailing, 8)
        }
    }
}

// MARK: - Order Table Header

private struct OrderTableHeaderView: View {
    var body: some View {
        HStack {
            Text("")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 30, alignment: .center)
            
            Text("Order")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 60, alignment: .leading)
            
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
        .background(Color.green.opacity(0.1))
    }
}

// MARK: - Order Table Rows

private struct OrderTableRowsView: View {
    let sequenceOrders: [BuySequenceOrder]
    let adjustedSequenceOrders: [BuySequenceOrder]
    let selectedSequenceOrderIndices: Set<Int>
    let onOrderSelectionChanged: (Int, Bool) -> Void
    let onCopyToClipboard: (Double, String) -> Void
    let onCopyTextToClipboard: (String) -> Void
    
    var body: some View {
        ForEach(Array(sequenceOrders.enumerated()), id: \.offset) { index, order in
            // Use adjusted orders for display if any are selected
            let displayOrder = !selectedSequenceOrderIndices.isEmpty ? 
                adjustedSequenceOrders.first { $0.orderIndex == order.orderIndex } ?? order : order
            OrderRowView(
                index: index,
                order: displayOrder,
                isSelected: selectedSequenceOrderIndices.contains(index),
                onOrderSelectionChanged: onOrderSelectionChanged,
                onCopyToClipboard: onCopyToClipboard,
                onCopyTextToClipboard: onCopyTextToClipboard
            )
        }
    }
}

// MARK: - Individual Order Row

private struct OrderRowView: View {
    let index: Int
    let order: BuySequenceOrder
    let isSelected: Bool
    let onOrderSelectionChanged: (Int, Bool) -> Void
    let onCopyToClipboard: (Double, String) -> Void
    let onCopyTextToClipboard: (String) -> Void
    
    private func rowStyle() -> Color {
        if order.orderCost > 1400.0 {
            return .red
        } else if order.trailingStop < 1.0 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // First line: checkbox, order number, shares, stop, target
            HStack {
                Button(action: {
                    onOrderSelectionChanged(index, !isSelected)
                }) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                .frame(width: 30, alignment: .center)
                .disabled(false) // Always enabled for selection
                
                Text("\(order.orderIndex + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 60, alignment: .leading)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("\(Int(order.shares))")
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        onCopyToClipboard(order.shares, "%.0f")
                    }
                
                Text(String(format: "%.2f%%", order.trailingStop))
                    .font(.caption)
                    .frame(width: 100, alignment: .trailing)
                    .onTapGesture {
                        onCopyToClipboard(order.trailingStop, "%.2f")
                    }
                
                Text(String(format: "%.2f", order.targetPrice))
                    .font(.caption)
                    .frame(width: 80, alignment: .trailing)
                    .onTapGesture {
                        onCopyToClipboard(order.targetPrice, "%.2f")
                    }
            }
            
            // Second line: description
            HStack {
                Text(order.description)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture {
                        onCopyTextToClipboard(order.description)
                    }
            }
            .padding(.leading, 90) // Align with content above (30 + 60 for checkbox + order number)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(isSelected ? Color.green.opacity(0.2) : rowStyle().opacity(0.1))
        .cornerRadius(4)
    }
}

#Preview("Order Table - No Orders Selected", traits: .landscapeLeft) {
    let sampleOrders = [
        BuySequenceOrder(
            orderIndex: 0,
            shares: 5.0,
            targetPrice: 150.00,
            entryPrice: 142.50,
            trailingStop: 5.0,
            orderCost: 750.00,
            description: "BUY 5 AAPL Target=150.00 Entry=142.50 TS=5.0% Cost=750.00"
        ),
        BuySequenceOrder(
            orderIndex: 1,
            shares: 5.0,
            targetPrice: 145.00,
            entryPrice: 137.75,
            trailingStop: 5.0,
            orderCost: 725.00,
            description: "BUY 5 AAPL Target=145.00 Entry=137.75 TS=5.0% Cost=725.00"
        )
    ]
    
    return OrderTableView(
        sequenceOrders: sampleOrders,
        adjustedSequenceOrders: sampleOrders,
        selectedSequenceOrderIndices: [],
        onOrderSelectionChanged: { _, _ in },
        onSubmitSequenceOrders: {},
        onCopyToClipboard: { _, _ in },
        onCopyTextToClipboard: { _ in }
    )
}

#Preview("Order Table - First Order Selected", traits: .landscapeLeft) {
    let sampleOrders = [
        BuySequenceOrder(
            orderIndex: 0,
            shares: 5.0,
            targetPrice: 150.00,
            entryPrice: 142.50,
            trailingStop: 5.0,
            orderCost: 750.00,
            description: "BUY 5 AAPL Target=150.00 Entry=142.50 TS=5.0% Cost=750.00"
        ),
        BuySequenceOrder(
            orderIndex: 1,
            shares: 5.0,
            targetPrice: 145.00,
            entryPrice: 137.75,
            trailingStop: 5.0,
            orderCost: 725.00,
            description: "BUY 5 AAPL Target=145.00 Entry=137.75 TS=5.0% Cost=725.00"
        )
    ]
    
    return OrderTableView(
        sequenceOrders: sampleOrders,
        adjustedSequenceOrders: sampleOrders,
        selectedSequenceOrderIndices: [0],
        onOrderSelectionChanged: { _, _ in },
        onSubmitSequenceOrders: {},
        onCopyToClipboard: { _, _ in },
        onCopyTextToClipboard: { _ in }
    )
}
