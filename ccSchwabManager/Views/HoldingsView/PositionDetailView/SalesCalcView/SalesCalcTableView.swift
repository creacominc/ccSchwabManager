import SwiftUI

enum SalesCalcSortableColumn: String, CaseIterable, Identifiable {
    case openDate = "Open Date"
    case quantity = "Quantity"
    case price = "Price"
    case costPerShare = "Cost/Share"
    case marketValue = "Market Value"
    case costBasis = "Cost Basis"
    case gainLossDollar = "Gain/Loss $"
    case gainLossPct = "Gain/Loss %"

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .costPerShare, .openDate, .quantity, .price, .marketValue, .costBasis, .gainLossDollar, .gainLossPct:
            return false
        }
    }

}

struct SalesCalcSortConfig {
    var column: SalesCalcSortableColumn
    var ascending: Bool
}

struct SalesCalcTable: View {
    let positionsData: [SalesCalcPositionsRecord]
    @Binding var currentSort: SalesCalcSortConfig?
    let viewSize: CGSize
    
    // Define proportional widths for columns
    private let columnWidths: [CGFloat] = [0.15, 0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0.10, 0.15]
    
    var sortedData: [SalesCalcPositionsRecord] {
        print("SalesCalcTable - Received \(positionsData.count) records")
        guard let sort = currentSort else { return positionsData }
        
        return positionsData.sorted { t1, t2 in
            let ascending = sort.ascending
            switch sort.column {
            case .openDate:
                return ascending ? t1.openDate < t2.openDate : t1.openDate > t2.openDate
            case .quantity:
                return ascending ? t1.quantity < t2.quantity : t1.quantity > t2.quantity
            case .price:
                return ascending ? t1.price < t2.price : t1.price > t2.price
            case .costPerShare:
                return ascending ? t1.costPerShare < t2.costPerShare : t1.costPerShare > t2.costPerShare
            case .marketValue:
                return ascending ? t1.marketValue < t2.marketValue : t1.marketValue > t2.marketValue
            case .costBasis:
                return ascending ? t1.costBasis < t2.costBasis : t1.costBasis > t2.costBasis
            case .gainLossDollar:
                return ascending ? t1.gainLossDollar < t2.gainLossDollar : t1.gainLossDollar > t2.gainLossDollar
            case .gainLossPct:
                return ascending ? t1.gainLossPct < t2.gainLossPct : t1.gainLossPct > t2.gainLossPct
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TableHeader(currentSort: $currentSort, viewSize: viewSize, columnWidths: columnWidths)
            Divider()
            TableContent(
                positionsData: sortedData,
                viewSize: viewSize,
                columnWidths: columnWidths
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .border(Color.blue, width: 2) // Add blue border to show the entire table's frame
//        .onAppear {
//            print("SalesCalcTable appeared with \(positionsData.count) records")
//            print("View size: \(viewSize.width) x \(viewSize.height)")
//        }
    }
}

private struct TableHeader: View {
    @Binding var currentSort: SalesCalcSortConfig?
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    
    @ViewBuilder
    private func columnHeader(title: String, column: SalesCalcSortableColumn, alignment: Alignment = .leading) -> some View {
        Button(action: {
            if currentSort?.column == column {
                currentSort?.ascending.toggle()
            } else {
                currentSort = SalesCalcSortConfig(column: column, ascending: column.defaultAscending)
            }
        }) {
            HStack {
                if alignment == .trailing {
                    Spacer()
                }
                Text(title)
                if alignment == .leading {
                    Spacer()
                }
                if currentSort?.column == column {
                    Image(systemName: currentSort?.ascending ?? true ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            columnHeader(title: "Open Date", column: .openDate)
                .frame(width: columnWidths[0] * viewSize.width)
            columnHeader(title: "Quantity", column: .quantity, alignment: .trailing)
                .frame(width: columnWidths[1] * viewSize.width)
            columnHeader(title: "Price", column: .price, alignment: .trailing)
                .frame(width: columnWidths[2] * viewSize.width)
            columnHeader(title: "Cost/Share", column: .costPerShare, alignment: .trailing)
                .frame(width: columnWidths[3] * viewSize.width)
            columnHeader(title: "Market Value", column: .marketValue, alignment: .trailing)
                .frame(width: columnWidths[4] * viewSize.width)
            columnHeader(title: "Cost Basis", column: .costBasis, alignment: .trailing)
                .frame(width: columnWidths[5] * viewSize.width)
            columnHeader(title: "Gain/Loss $", column: .gainLossDollar, alignment: .trailing)
                .frame(width: columnWidths[6] * viewSize.width)
            columnHeader(title: "Gain/Loss %", column: .gainLossPct, alignment: .trailing)
                .frame(width: columnWidths[7] * viewSize.width)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
    }
}

private struct TableContent: View {
    let positionsData: [SalesCalcPositionsRecord]
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(positionsData) { item in
                    TableRow(
                        item: item,
                        viewSize: viewSize,
                        columnWidths: columnWidths
                    )
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .onAppear {
//            print("TableContent ScrollView appeared with \(positionsData.count) records")
//        }
    }
}

private struct TableRow: View {
    let item: SalesCalcPositionsRecord
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    
    private func rowStyle() -> Color {
        if item.gainLossPct < 0.0 {
            return .red
        } else if item.gainLossPct < 5.0 {
            return .yellow
        }
        return .green
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(item.openDate)
                .frame(width: columnWidths[0] * viewSize.width, alignment: .leading)
                .foregroundStyle(daysSinceDateString(dateString: item.openDate) ?? 0 > 30 ? .green : .red)
            
            Text(String(format: "%.2f", item.quantity))
                .frame(width: columnWidths[1] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
            
            Text(String(format: "%.2f", item.price))
                .frame(width: columnWidths[2] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
            
            Text(String(format: "%.2f", item.costPerShare))
                .frame(width: columnWidths[3] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
            
            Text(String(format: "%.2f", item.marketValue))
                .frame(width: columnWidths[4] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
            
            Text(String(format: "%.2f", item.costBasis))
                .frame(width: columnWidths[5] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
            
            Text(String(format: "%.2f", item.gainLossDollar))
                .frame(width: columnWidths[6] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.gainLossDollar > 0.0 ? .green : .red)
            
            Text(String(format: "%.2f%%", item.gainLossPct))
                .frame(width: columnWidths[7] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.gainLossPct > 5.0 ? .green : item.gainLossPct > 0.0 ? .yellow : .red)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.05))
//        .onAppear {
//            print("Rendering row for date: \(item.openDate)")
//        }
    }
} 
