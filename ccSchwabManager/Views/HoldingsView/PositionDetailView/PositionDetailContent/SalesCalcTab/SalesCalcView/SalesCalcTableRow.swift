import SwiftUI

struct SalesCalcTableRow: View {
    let item: SalesCalcPositionsRecord
    let calculatedWidths: [CGFloat]
    let currentPrice: Double
    let copyToClipboard: (String) -> Void
    let copyToClipboardValue: (Double, String) -> Void
    let isEvenRow: Bool
    let showGainLossDollar: Bool
    
    @State private var isHovered = false
    
    private func rowStyle() -> Color {
        if item.gainLossPct < 0.0 {
            return .red
        } else if item.gainLossPct < 5.0 {
            return .yellow
        }
        return .green
    }
    
    // When the Gain/Loss $ column is hidden, the indices of the
    // trailing columns shift left by one. Compute them safely.
    private var gainLossPercentIndex: Int { showGainLossDollar ? 7 : 6 }
    private var splitColumnIndex: Int { showGainLossDollar ? 8 : 7 }
    
    var body: some View {
        HStack(spacing: 8) {
            Text(item.openDate)
                .frame(width: calculatedWidths[0], alignment: .leading)
                .foregroundStyle(daysSinceDateString(dateString: item.openDate) ?? 0 > 30 ? .green : .red)
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Open Date: \(item.openDate)")
                    copyToClipboard(item.openDate)
                }
            
            Text(String(format: "%.2f", item.quantity))
                .frame(width: calculatedWidths[1], alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Quantity: \(item.quantity)")
                    copyToClipboardValue(item.quantity, "%.2f")
                }
            
            Text(String(format: "%.2f", currentPrice))
                .frame(width: calculatedWidths[2], alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Price: \(currentPrice)")
                    copyToClipboardValue(currentPrice, "%.2f")
                }
            
            Text(String(format: "%.2f", item.costPerShare))
                .frame(width: calculatedWidths[3], alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.costPerShare > item.price ? .red : .primary)
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Cost/Share: \(item.costPerShare)")
                    copyToClipboardValue(item.costPerShare, "%.2f")
                }
            
            Text(String(format: "%.2f", item.marketValue))
                .frame(width: calculatedWidths[4], alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Market Value: \(item.marketValue)")
                    copyToClipboardValue(item.marketValue, "%.2f")
                }
            
            Text(String(format: "%.2f", item.costBasis))
                .frame(width: calculatedWidths[5], alignment: .trailing)
                .monospacedDigit()
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Cost Basis: \(item.costBasis)")
                    copyToClipboardValue(item.costBasis, "%.2f")
                }
            
            if showGainLossDollar {
                Text(String(format: "%.2f", item.gainLossDollar))
                    .frame(width: calculatedWidths[6], alignment: .trailing)
                    .monospacedDigit()
                    .foregroundStyle(item.gainLossDollar > 0.0 ? .green : .red)
                    .onTapGesture {
                        print("SalesCalcTableView: Tap detected on Gain/Loss $: \(item.gainLossDollar)")
                        copyToClipboardValue(item.gainLossDollar, "%.2f")
                    }
            }
            
            Text(String(format: "%.2f%%", item.gainLossPct))
                .frame(width: calculatedWidths[gainLossPercentIndex], alignment: .trailing)
                .monospacedDigit()
                .foregroundStyle(item.gainLossPct > 5.0 ? .green : item.gainLossPct > 0.0 ? .yellow : .red)
                .onTapGesture {
                    print("SalesCalcTableView: Tap detected on Gain/Loss %: \(item.gainLossPct)")
                    copyToClipboardValue(item.gainLossPct, "%.2f")
                }
            
            Text(String(format: "%.0f", item.splitMultiple))
                .frame(width: calculatedWidths[splitColumnIndex], alignment: .trailing)
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

// MARK: - Preview Helper
struct SalesCalcTableRowPreviewHelper {
    // iPad Mini landscape width is approximately 1024 points
    static let iPadMiniLandscapeWidth: CGFloat = 1024
    
    static let wideColumnProportions: [CGFloat] = [0.16, 0.09, 0.09, 0.11, 0.11, 0.11, 0.11, 0.11, 0.05] // Open Date, Quantity, Price, Cost/Share, Market Value, Cost Basis, Gain/Loss $, Gain/Loss %, Split
    static let narrowColumnProportions: [CGFloat] = [0.18, 0.11, 0.11, 0.12, 0.15, 0.15, 0.12, 0.05] // Open Date, Quantity, Price, Cost/Share, Market Value, Cost Basis, Gain/Loss %, Split (no Gain/Loss $)
    
    static func calculateWidths(for containerWidth: CGFloat, showGainLossDollar: Bool = true) -> [CGFloat] {
        let horizontalPadding: CGFloat = 16 * 2
        let proportions = showGainLossDollar ? wideColumnProportions : narrowColumnProportions
        let interColumnSpacing = (CGFloat(proportions.count - 1) * 8)
        let availableWidthForColumns = containerWidth - interColumnSpacing - horizontalPadding
        return proportions.map { $0 * availableWidthForColumns }
    }
    
    static func shouldShowGainLossDollar(for containerWidth: CGFloat) -> Bool {
        return containerWidth >= iPadMiniLandscapeWidth
    }
}

#Preview("SalesCalcTableRow - Multiple Rows", traits: .landscapeLeft) {
    let samplePositions = [
        SalesCalcPositionsRecord(
            openDate: "2025-01-15",
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
            openDate: "2025-02-20",
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
            openDate: "2025-03-10",
            gainLossPct: 3.8,
            gainLossDollar: 45.00,
            quantity: 75.0,
            price: 150.00,
            costPerShare: 144.00,
            marketValue: 11250.00,
            costBasis: 10800.00,
            splitMultiple: 2.0
        )
    ]
    
    return GeometryReader { geometry in
        let showGainLossDollar = SalesCalcTableRowPreviewHelper.shouldShowGainLossDollar(for: geometry.size.width)
        let calculatedWidths = SalesCalcTableRowPreviewHelper.calculateWidths(for: geometry.size.width, showGainLossDollar: showGainLossDollar)
        
        VStack(spacing: 0) {
            // Simulate a table header
            HStack(spacing: 8) {
                Text("Open Date").frame(width: calculatedWidths[0], alignment: .leading)
                Text("Quantity").frame(width: calculatedWidths[1], alignment: .trailing)
                Text("Price").frame(width: calculatedWidths[2], alignment: .trailing)
                Text("Cost/Share").frame(width: calculatedWidths[3], alignment: .trailing)
                Text("Market Value").frame(width: calculatedWidths[4], alignment: .trailing)
                Text("Cost Basis").frame(width: calculatedWidths[5], alignment: .trailing)
                if showGainLossDollar {
                    Text("Gain/Loss $").frame(width: calculatedWidths[6], alignment: .trailing)
                }
                Text("Gain/Loss %").frame(width: calculatedWidths[showGainLossDollar ? 7 : 6], alignment: .trailing)
                Text("Split").frame(width: calculatedWidths[showGainLossDollar ? 8 : 7], alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.1))
            .font(.caption)
            .fontWeight(.semibold)
            
            Divider()
            
            // Table rows
            ForEach(Array(samplePositions.enumerated()), id: \.element.id) { index, position in
                SalesCalcTableRow(
                    item: position,
                    calculatedWidths: calculatedWidths,
                    currentPrice: 150.00,
                    copyToClipboard: { _ in },
                    copyToClipboardValue: { _, _ in },
                    isEvenRow: index % 2 == 0,
                    showGainLossDollar: showGainLossDollar
                )
                Divider()
            }
        }
    }
    .padding()
}

#Preview("SalesCalcTableRow - Narrow Layout (No Gain/Loss $)", traits: .portrait) {
    let samplePositions = [
        SalesCalcPositionsRecord(
            openDate: "2025-01-15",
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
            openDate: "2025-02-20",
            gainLossPct: -5.2,
            gainLossDollar: -75.00,
            quantity: 50.0,
            price: 150.00,
            costPerShare: 158.00,
            marketValue: 7500.00,
            costBasis: 7900.00,
            splitMultiple: 1.0
        )
    ]
    
    return GeometryReader { geometry in
        // Force narrow layout by constraining width to less than iPad Mini landscape width
        let constrainedWidth: CGFloat = 800 // Less than 1024
        let showGainLossDollar = SalesCalcTableRowPreviewHelper.shouldShowGainLossDollar(for: constrainedWidth)
        let calculatedWidths = SalesCalcTableRowPreviewHelper.calculateWidths(for: constrainedWidth, showGainLossDollar: showGainLossDollar)
        
        VStack(spacing: 0) {
            // Simulate a table header
            HStack(spacing: 8) {
                Text("Open Date").frame(width: calculatedWidths[0], alignment: .leading)
                Text("Quantity").frame(width: calculatedWidths[1], alignment: .trailing)
                Text("Price").frame(width: calculatedWidths[2], alignment: .trailing)
                Text("Cost/Share").frame(width: calculatedWidths[3], alignment: .trailing)
                Text("Market Value").frame(width: calculatedWidths[4], alignment: .trailing)
                Text("Cost Basis").frame(width: calculatedWidths[5], alignment: .trailing)
                if showGainLossDollar {
                    Text("Gain/Loss $").frame(width: calculatedWidths[6], alignment: .trailing)
                }
                Text("Gain/Loss %").frame(width: calculatedWidths[showGainLossDollar ? 7 : 6], alignment: .trailing)
                Text("Split").frame(width: calculatedWidths[showGainLossDollar ? 8 : 7], alignment: .trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.1))
            .font(.caption)
            .fontWeight(.semibold)
            
            Divider()
            
            // Table rows
            ForEach(Array(samplePositions.enumerated()), id: \.element.id) { index, position in
                SalesCalcTableRow(
                    item: position,
                    calculatedWidths: calculatedWidths,
                    currentPrice: 150.00,
                    copyToClipboard: { _ in },
                    copyToClipboardValue: { _, _ in },
                    isEvenRow: index % 2 == 0,
                    showGainLossDollar: showGainLossDollar
                )
                Divider()
            }
        }
        .frame(width: constrainedWidth)
    }
    .padding()
}
