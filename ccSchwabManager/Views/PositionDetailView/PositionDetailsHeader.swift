import SwiftUI

struct PositionDetailsHeader: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let onNavigate: (Int) -> Void
    let symbol: String
    let atrValue: Double
    let lastPrice: Double
    let quoteData: QuoteData?
    @State private var showDetails = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // Previous Position Button
                Button(action: { onNavigate(currentIndex - 1) }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(currentIndex <= 0)
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Spacer()
                Spacer()

                Text(position.instrument?.symbol ?? "")
                    .font(.title2)
                    .bold()
                
                Spacer()

                // Details disclosure button
                Button(action: {
                    withAnimation {
                        showDetails.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: showDetails ? "chevron.down" : "chevron.right")
                            .foregroundColor(.accentColor)
                        Text("Details")
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)

                Spacer()

                // Next Position Button
                Button(action: { onNavigate(currentIndex + 1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(currentIndex >= totalPositions - 1)
                .keyboardShortcut(.rightArrow, modifiers: [])
            }

            if showDetails {
                HStack(spacing: 10) {
                    ForEach(0..<4) { columnIndex in
                        PositionDetailColumn(
                            fields: getFieldsForColumn(columnIndex),
                            position: position,
                            atrValue: atrValue,
                            accountNumber: accountNumber,
                            lastPrice: lastPrice,
                            quoteData: quoteData
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(backgroundColor)
        .frame(maxWidth: .infinity)
    }
    
    private var backgroundColor: Color {
        #if os(macOS)
        Color(.windowBackgroundColor)
        #else
        Color(.systemBackground)
        #endif
    }
    
    private func getFieldsForColumn(_ columnIndex: Int) -> [PositionDetailField] {
        switch columnIndex {
        case 0: // Performance & Risk
            return [
                .plPercent(atrValue: atrValue),
                .pl,
                .atr(atrValue: atrValue)
            ]
        case 1: // Position Details
            return [
                .quantity,
                .marketValue,
                .averagePrice
            ]
        case 2: // Market Info
            return [
                .assetType,
                .lastPrice(lastPrice: lastPrice),
                .dividendYield
            ]
        case 3: // Account Info
            return [
                .account(accountNumber: accountNumber),
                .symbol,
                .empty
            ]
        default:
            return []
        }
    }
} 