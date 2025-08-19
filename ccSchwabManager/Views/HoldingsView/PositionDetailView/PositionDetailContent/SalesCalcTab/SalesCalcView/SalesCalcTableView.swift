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
            if viewSize.width >= 1024 { // Only show if wide enough
                columnHeader(title: "Gain/Loss $", column: .gainLossDollar, alignment: .trailing, currentSort: currentSort) { newSort in
                    currentSort = newSort
                }
                .frame(width: columnWidths[6] * viewSize.width)
            }
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
    
    private var showGainLossDollar: Bool {
        return viewSize.width >= 1024 // iPad Mini landscape width
    }
    
    private var calculatedWidths: [CGFloat] {
        let horizontalPadding: CGFloat = 16 * 2
        let effectiveColumnCount = showGainLossDollar ? columnWidths.count : columnWidths.count - 1
        let interColumnSpacing = (CGFloat(effectiveColumnCount - 1) * 8)
        let availableWidthForColumns = viewSize.width - interColumnSpacing - horizontalPadding
        
        if showGainLossDollar {
            return columnWidths.map { $0 * availableWidthForColumns }
        } else {
            // Remove the Gain/Loss $ column (index 6) and redistribute the space
            var adjustedWidths: [CGFloat] = []
            for (index, width) in columnWidths.enumerated() {
                if index != 6 { // Skip Gain/Loss $ column
                    adjustedWidths.append(width * availableWidthForColumns)
                }
            }
            return adjustedWidths
        }
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(positionsData.enumerated()), id: \.element.id) { index, item in
                    SalesCalcTableRow(
                        item: item,
                        calculatedWidths: calculatedWidths,
                        currentPrice: currentPrice,
                        copyToClipboard: { text in
                            copyToClipboard(text)
                        },
                        copyToClipboardValue: { value, format in
                            copyToClipboardValue(value, format)
                        },
                        isEvenRow: index % 2 == 0,
                        showGainLossDollar: showGainLossDollar
                    )
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

 
