import SwiftUI

struct BuySequenceHeaderView: View {
    let sequenceOrdersCount: Int
    let selectedSequenceOrderIndices: Set<Int>
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    
    var body: some View {
        HStack {
            Text("Buy Sequence Orders")
                .font(.headline)
            
            // Add debugging info
            Text("(\(sequenceOrdersCount) orders)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if sequenceOrdersCount > 0 {
                Button(selectedSequenceOrderIndices.count == sequenceOrdersCount ? "Deselect All" : "Select All") {
                    if selectedSequenceOrderIndices.count == sequenceOrdersCount {
                        onDeselectAll()
                    } else {
                        onSelectAll()
                    }
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
        .padding(.horizontal)
    }
}

#Preview("Header - No Orders", traits: .landscapeLeft) {
    BuySequenceHeaderView(
        sequenceOrdersCount: 0,
        selectedSequenceOrderIndices: [],
        onSelectAll: {},
        onDeselectAll: {}
    )
}

#Preview("Header - Orders Available (None Selected)", traits: .landscapeLeft) {
    BuySequenceHeaderView(
        sequenceOrdersCount: 3,
        selectedSequenceOrderIndices: [],
        onSelectAll: {},
        onDeselectAll: {}
    )
}

#Preview("Header - Orders Available (All Selected)", traits: .landscapeLeft) {
    BuySequenceHeaderView(
        sequenceOrdersCount: 3,
        selectedSequenceOrderIndices: [0, 1, 2],
        onSelectAll: {},
        onDeselectAll: {}
    )
}
