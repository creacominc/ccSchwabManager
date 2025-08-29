import SwiftUI

/**
 * column headers
 */
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

/**
 * the column to sort on and the direction of the sort.
 */
struct SalesCalcSortConfig {
    var column: SalesCalcSortableColumn
    var ascending: Bool
}

/**
 * construct a single column header with optional sort indicator.
 */
@ViewBuilder
private func columnHeader(  title: String,
                            column: SalesCalcSortableColumn,
                            alignment: Alignment = .leading,
                            currentSort: SalesCalcSortConfig?,
                            onSortChange: @escaping (SalesCalcSortConfig) -> Void
                        ) -> some View
{
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

struct SalesCalcTable: View
{
    let positionsData: [SalesCalcPositionsRecord]
    @Binding var currentSort: SalesCalcSortConfig?
    let symbol: String
    let currentPrice: Double
    @State private var copiedValue: String = "TBD"

    public func showGainLossDollar(for width: CGFloat) -> Bool {
        return width >= 1024 // iPad Mini landscape width
    }

    public func columnWidths(for width: CGFloat) -> [CGFloat]
    {
        if( showGainLossDollar(for: width) )
        {
            return SalesCalcTableRow.wideColumnProportions
        }
        else
        {
            return SalesCalcTableRow.narrowColumnProportions
        }
    }

    private func calculatedWidths(for width: CGFloat) -> [CGFloat]
    {
        if showGainLossDollar(for: width) {
            return SalesCalcTableRow.wideColumnProportions.map { $0 * width }
        } else {
            return SalesCalcTableRow.narrowColumnProportions.map { $0 * width }
        }
    }

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
        GeometryReader { geometry in
            let width = geometry.size.width
            let showGainLossDollar = showGainLossDollar(for: width)
            let calculatedWidths = calculatedWidths(for: width)
            
            VStack(spacing: 0) {
                headerRow(width: width, showGainLossDollar: showGainLossDollar)
                TableContent(
                    positionsData: sortedData,
                    currentPrice: currentPrice,
                    copiedValue: $copiedValue,
                    copyToClipboard: copyToClipboard,
                    copyToClipboardValue: copyToClipboard,
                    calculatedWidths: calculatedWidths,
                    showGainLossDollar: showGainLossDollar
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
                print("SalesCalcTableView: Geometry width: \(width), showGainLossDollar: \(showGainLossDollar)")
                print("SalesCalcTableView: sortedData count: \(sortedData.count)")
                if !sortedData.isEmpty {
                    print("SalesCalcTableView: First sorted item - Qty: \(sortedData[0].quantity), Price: \(sortedData[0].price)")
                }
            }
        }
    }
    
    private func headerRow(width: CGFloat, showGainLossDollar: Bool) -> some View {
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
            .frame(width: columnWidths(for: width)[0] * width)
            
            columnHeader(title: "Quantity", column: .quantity, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths(for: width)[1] * width)
            columnHeader(title: "Price", column: .price, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths(for: width)[2] * width)
            columnHeader(title: "Cost/Share", column: .costPerShare, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths(for: width)[3] * width)
            columnHeader(title: "Market Value", column: .marketValue, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths(for: width)[4] * width)
            columnHeader(title: "Cost Basis", column: .costBasis, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths(for: width)[5] * width)
            if showGainLossDollar { // Only show if wide enough
                columnHeader(title: "Gain/Loss $", column: .gainLossDollar, alignment: .trailing, currentSort: currentSort) { newSort in
                    currentSort = newSort
                }
                .frame(width: columnWidths(for: width)[6] * width)
            }
            columnHeader(title: "Gain/Loss %", column: .gainLossPct, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths(for: width)[ (showGainLossDollar ? 7 : 6) ] * width)
            columnHeader(title: "Split", column: .splitMultiple, alignment: .trailing, currentSort: currentSort) { newSort in
                currentSort = newSort
            }
            .frame(width: columnWidths(for: width)[ (showGainLossDollar ? 8 : 7 ) ] * width)
        }
        .padding(.horizontal)
        .padding(.vertical, 5)
        .background(Color.gray.opacity(0.1))
    }
}

// contained in a SalesCalcTable
private struct TableContent: View {
    let positionsData: [SalesCalcPositionsRecord]
    let currentPrice: Double
    @Binding var copiedValue: String
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    let calculatedWidths: [CGFloat]
    let showGainLossDollar: Bool

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
                }
            }
        }
    }
}



#Preview("SalesCalcTableView", traits: .landscapeLeft) {
    let samplePositions = [
        SalesCalcPositionsRecord(
            openDate: "2025-01-15 09:30:43",
            gainLossPct: 15.5,
            gainLossDollar: 150.00,
            quantity: 100.0,
            price: 150.00,
            costPerShare: 130.00,
            marketValue: 15000.00,
            costBasis: 13000.00,
            splitMultiple: 1.0
        ),
        SalesCalcPositionsRecord(
            openDate: "2025-02-20 14:11:00",
            gainLossPct: -5.2,
            gainLossDollar: -75.00,
            quantity: 50.0,
            price: 150.00,
            costPerShare: 158.00,
            marketValue: 7500.00,
            costBasis: 7900.00,
            splitMultiple: 1.0
        ),
        SalesCalcPositionsRecord(
            openDate: "2025-03-10 11:30:00",
            gainLossPct: 3.8,
            gainLossDollar: 45.00,
            quantity: 75.0,
            price: 150.00,
            costPerShare: 144.00,
            marketValue: 11250.00,
            costBasis: 10800.00,
            splitMultiple: 2.0
        ),
        SalesCalcPositionsRecord(
            openDate: "2025-04-05 11:21:11",
            gainLossPct: -12.3,
            gainLossDollar: -225.00,
            quantity: 25.0,
            price: 150.00,
            costPerShare: 171.00,
            marketValue: 3750.00,
            costBasis: 4275.00,
            splitMultiple: 1.0
        )
    ]
    
    return  GeometryReader { geometry in
        SalesCalcTable(
            positionsData: samplePositions,
            currentSort: .constant(SalesCalcSortConfig(column: .openDate, ascending: false)),
            symbol: "AAPL",
            currentPrice: 150.00
        )
        .padding( .trailing, 80 )
    }
}
