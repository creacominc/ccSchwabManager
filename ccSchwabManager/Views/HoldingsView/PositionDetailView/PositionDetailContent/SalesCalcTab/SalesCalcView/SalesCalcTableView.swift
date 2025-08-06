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
    case splitMultiple = "Split"

    var id: String { self.rawValue }

    var defaultAscending: Bool {
        switch self {
        case .costPerShare, .openDate, .quantity, .price, .marketValue, .costBasis, .gainLossDollar, .gainLossPct, .splitMultiple:
            return false
        }
    }

}

struct SalesCalcSortConfig {
    var column: SalesCalcSortableColumn
    var ascending: Bool
}

@ViewBuilder
private func columnHeader(title: String, column: SalesCalcSortableColumn, alignment: Alignment = .leading, currentSort: SalesCalcSortConfig?, onSortChange: @escaping (SalesCalcSortConfig) -> Void) -> some View {
    Button(action: {
        if currentSort?.column == column {
            var newSort = currentSort!
            newSort.ascending.toggle()
            onSortChange(newSort)
        } else {
            onSortChange(SalesCalcSortConfig(column: column, ascending: column.defaultAscending))
        }
    }) {
        HStack {
            if alignment == .trailing {
                Spacer()
            }
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
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

struct SalesCalcTable: View {
    let positionsData: [SalesCalcPositionsRecord]
    @Binding var currentSort: SalesCalcSortConfig?
    let viewSize: CGSize
    let symbol: String
    let currentPrice: Double
    @State private var copiedValue: String = "TBD"
    
    // Define proportional widths for columns
    private let columnWidths: [CGFloat] = [0.16, 0.09, 0.09, 0.11, 0.11, 0.11, 0.11, 0.11, 0.11] // Open Date (wider), Quantity, Price, Cost/Share, Market Value, Cost Basis, Gain/Loss $, Gain/Loss %, Split

    private func copyToClipboard(value: Double, format: String) {
        let formattedValue = String(format: format, value)
        print("SalesCalcTableView: copyToClipboard(value: \(value), format: \(format)) -> formattedValue: \(formattedValue)")
#if os(iOS)
        UIPasteboard.general.string = formattedValue
        let pastedValue = UIPasteboard.general.string ?? "no value"
        copiedValue = pastedValue
        print("SalesCalcTableView: iOS pasteboard - set: \(formattedValue), retrieved: \(pastedValue)")
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedValue, forType: .string)
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no value"
#endif
    }
    
    private func copyToClipboard(text: String) {
        print("SalesCalcTableView: copyToClipboard(text: \(text))")
#if os(iOS)
        UIPasteboard.general.string = text
        let pastedValue = UIPasteboard.general.string ?? "no value"
        copiedValue = pastedValue
        print("SalesCalcTableView: iOS pasteboard - set: \(text), retrieved: \(pastedValue)")
#else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedValue = NSPasteboard.general.string(forType: .string) ?? "no value"
#endif
    }

    private var sortedData: [SalesCalcPositionsRecord] {
        guard let sortConfig = currentSort else { return positionsData }
        return positionsData.sorted { item1, item2 in
            let ascending = sortConfig.ascending
            switch sortConfig.column {
            case .openDate:
                return ascending ? item1.openDate < item2.openDate : item1.openDate > item2.openDate
            case .quantity:
                return ascending ? item1.quantity < item2.quantity : item1.quantity > item2.quantity
            case .price:
                return ascending ? item1.price < item2.price : item1.price > item2.price
            case .costPerShare:
                return ascending ? item1.costPerShare < item2.costPerShare : item1.costPerShare > item2.costPerShare
            case .marketValue:
                return ascending ? item1.marketValue < item2.marketValue : item1.marketValue > item2.marketValue
            case .costBasis:
                return ascending ? item1.costBasis < item2.costBasis : item1.costBasis > item2.costBasis
            case .gainLossDollar:
                return ascending ? item1.gainLossDollar < item2.gainLossDollar : item1.gainLossDollar > item2.gainLossDollar
            case .gainLossPct:
                return ascending ? item1.gainLossPct < item2.gainLossPct : item1.gainLossPct > item2.gainLossPct
            case .splitMultiple:
                return ascending ? item1.splitMultiple < item2.splitMultiple : item1.splitMultiple > item2.splitMultiple
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerRow
            TableContent(
                positionsData: sortedData,
                viewSize: viewSize,
                columnWidths: columnWidths,
                currentPrice: currentPrice,
                copiedValue: $copiedValue,
                copyToClipboard: copyToClipboard,
                copyToClipboardValue: copyToClipboard
            )
            if copiedValue != "TBD" {
                Text("Copied: \(copiedValue)")
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal)
                    .onAppear {
                        print("SalesCalcTableView: Displaying copied value: \(copiedValue)")
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            print("SalesCalcTableView: Table initialized with \(sortedData.count) items for symbol \(symbol)")
        }
    }
    
    private var headerRow: some View {
        HStack(spacing: 8) {
            HStack {
                columnHeader(title: "Open Date", column: .openDate, currentSort: currentSort) { newSort in
                    currentSort = newSort
                }
                Button(action: {
                    CSVExporter.exportTaxLots(sortedData, symbol: symbol)
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .frame(width: columnWidths[0] * viewSize.width)
            
            columnHeader(title: "Quantity", column: .quantity, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[1] * viewSize.width)
            columnHeader(title: "Price", column: .price, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[2] * viewSize.width)
            columnHeader(title: "Cost/Share", column: .costPerShare, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[3] * viewSize.width)
            columnHeader(title: "Market Value", column: .marketValue, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[4] * viewSize.width)
            columnHeader(title: "Cost Basis", column: .costBasis, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[5] * viewSize.width)
            columnHeader(title: "Gain/Loss $", column: .gainLossDollar, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[6] * viewSize.width)
            columnHeader(title: "Gain/Loss %", column: .gainLossPct, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[7] * viewSize.width)
            columnHeader(title: "Split", column: .splitMultiple, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths[8] * viewSize.width)
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
    let currentPrice: Double
    @Binding var copiedValue: String
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(positionsData.enumerated()), id: \.element.id) { index, item in
                    TableRow(
                        item: item,
                        viewSize: viewSize,
                        columnWidths: columnWidths,
                        currentPrice: currentPrice,
                        copyToClipboard: { text in
                            copyToClipboard(text)
                        },
                        copyToClipboardValue: { value, format in
                            copyToClipboardValue(value, format)
                        },
                        isEvenRow: index % 2 == 0
                    )
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TableRow: View {
    let item: SalesCalcPositionsRecord
    let viewSize: CGSize
    let columnWidths: [CGFloat]
    let currentPrice: Double
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    let isEvenRow: Bool
    
    @State private var isHovered = false
    
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
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Open Date: \(item.openDate)")
                    copyToClipboard(item.openDate)
                }
            
            Text(String(format: "%.2f", item.quantity))
                .frame(width: columnWidths[1] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Quantity: \(item.quantity)")
                    copyToClipboardValue(item.quantity, "%.2f")
                }
            
            Text(String(format: "%.2f", currentPrice))
                .frame(width: columnWidths[2] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Price: \(currentPrice)")
                    copyToClipboardValue(currentPrice, "%.2f")
                }
            
            Text(String(format: "%.2f", item.costPerShare))
                .frame(width: columnWidths[3] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.costPerShare > item.price ? .red : .primary)
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Cost/Share: \(item.costPerShare)")
                    copyToClipboardValue(item.costPerShare, "%.2f")
                }
            
            Text(String(format: "%.2f", item.marketValue))
                .frame(width: columnWidths[4] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Market Value: \(item.marketValue)")
                    copyToClipboardValue(item.marketValue, "%.2f")
                }
            
            Text(String(format: "%.2f", item.costBasis))
                .frame(width: columnWidths[5] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Cost Basis: \(item.costBasis)")
                    copyToClipboardValue(item.costBasis, "%.2f")
                }
            
            Text(String(format: "%.2f", item.gainLossDollar))
                .frame(width: columnWidths[6] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.gainLossDollar > 0.0 ? .green : .red)
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Gain/Loss $: \(item.gainLossDollar)")
                    copyToClipboardValue(item.gainLossDollar, "%.2f")
                }
            
            Text(String(format: "%.2f%%", item.gainLossPct))
                .frame(width: columnWidths[7] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.gainLossPct > 5.0 ? .green : item.gainLossPct > 0.0 ? .yellow : .red)
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Gain/Loss %: \(item.gainLossPct)")
                    copyToClipboardValue(item.gainLossPct, "%.2f")
                }
            
            Text(String(format: "%.0f", item.splitMultiple))
                .frame(width: columnWidths[8] * viewSize.width, alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.splitMultiple > 1.0 ? .blue : .secondary)
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Split: \(item.splitMultiple)")
                    copyToClipboardValue(item.splitMultiple, "%.0f")
                }
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(rowBackgroundColor)
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
    }
    
    private var rowBackgroundColor: Color {
        if isHovered {
            return Color.gray.opacity(0.1)
        } else if isEvenRow {
            return Color.clear
        } else {
            return Color.gray.opacity(0.05)
        }
    }
} 
