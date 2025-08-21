import SwiftUI

// ADD Definitions for Transaction Sorting
struct TransactionSortConfig: Equatable {
    var column: TransactionSortableColumn
    var ascending: Bool
}

enum TransactionSortableColumn: String, CaseIterable, Identifiable {
    case date = "Date"
    case type = "Type" // Buy/Sell derived from netAmount
    case quantity = "Quantity"
    case price = "Price"
    case netAmount = "Net Amount"

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .date, .quantity, .price:
            return false // Typically newest first
        case .type, .netAmount:
            return true
        }
    }
}

#Preview("TransactionSortConfig", traits: .landscapeLeft) {
    VStack(spacing: 20) {
        Text("Transaction Sort Configuration")
            .font(.title)
            .padding()
        
        VStack(alignment: .leading, spacing: 10) {
            ForEach(TransactionSortableColumn.allCases) { column in
                HStack {
                    Text(column.rawValue)
                        .font(.headline)
                    Spacer()
                    Text("Default: \(column.defaultAscending ? "Ascending" : "Descending")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        
        Spacer()
    }
    .padding()
}

#Preview("TransactionSortConfig - Sortable Columns", traits: .landscapeLeft) {
    List(TransactionSortableColumn.allCases) { column in
        HStack {
            Text(column.rawValue)
            Spacer()
            Image(systemName: column.defaultAscending ? "chevron.up" : "chevron.down")
                .foregroundColor(.blue)
        }
    }
    .navigationTitle("Sortable Columns")
}
