import SwiftUI

struct PositionDetailContent: View {
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let symbol: String
    let atrValue: Double
    let sharesAvailableForTrading: Double
    let onNavigate: (Int) -> Void
    let priceHistory: CandleList?
    let isLoadingPriceHistory: Bool
    let isLoadingTransactions: Bool
    let formatDate: (Int64?) -> String
    let quoteData: QuoteData?
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    let transactions: [Transaction]
    @Binding var viewSize: CGSize
    @Binding var selectedTab: Int

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar with integrated navigation
            VStack(spacing: 0) {
                // Navigation and tab header row
                HStack(spacing: 0) {
                    // Previous Position Button
                    Button(action: { onNavigate(currentIndex - 1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .disabled(currentIndex <= 0)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                    
                    // Tab buttons
                    HStack(spacing: 0) {
                        TabButton(
                            title: position.instrument?.symbol ?? "Summary",
                            icon: "list.bullet",
                            isSelected: selectedTab == 0,
                            action: { selectedTab = 0 }
                        )
                        
                        TabButton(
                            title: "Price History",
                            icon: "chart.line.uptrend.xyaxis",
                            isSelected: selectedTab == 1,
                            action: { selectedTab = 1 }
                        )
                        
                        TabButton(
                            title: "Transactions",
                            icon: "list.bullet.rectangle",
                            isSelected: selectedTab == 2,
                            action: { selectedTab = 2 }
                        )
                        
                        TabButton(
                            title: "Sales Calc",
                            icon: "calculator",
                            isSelected: selectedTab == 3,
                            action: { selectedTab = 3 }
                        )
                        
                        TabButton(
                            title: "Current",
                            icon: "clock.arrow.circlepath",
                            isSelected: selectedTab == 4,
                            action: { selectedTab = 4 }
                        )
                        
                        TabButton(
                            title: "OCO",
                            icon: "chart.line.uptrend.xyaxis",
                            isSelected: selectedTab == 5,
                            action: { selectedTab = 5 }
                        )
                        
                        TabButton(
                            title: "Sequence",
                            icon: "arrow.up.circle",
                            isSelected: selectedTab == 6,
                            action: { selectedTab = 6 }
                        )
                    }
                    .background(Color.gray.opacity(0.1))
                    
                    // Next Position Button
                    Button(action: { onNavigate(currentIndex + 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .disabled(currentIndex >= totalPositions - 1)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
                .padding(.horizontal)
                .padding(.bottom, 2)
                
                // Tab content area
                GeometryReader { geometry in
                    // Custom content switcher instead of TabView
                    Group {
                        switch selectedTab {
                        case 0:
                            DetailsTab(
                                position: position,
                                accountNumber: accountNumber,
                                symbol: symbol,
                                atrValue: atrValue,
                                sharesAvailableForTrading: sharesAvailableForTrading,
                                lastPrice: getCurrentPrice(),
                                quoteData: quoteData
                            )
                        case 1:
                            PriceHistoryTab(
                                priceHistory: priceHistory,
                                isLoading: isLoadingPriceHistory,
                                formatDate: formatDate,
                                geometry: geometry
                            )
                        case 2:
                            TransactionsTab(
                                isLoading: isLoadingTransactions,
                                symbol: position.instrument?.symbol ?? "",
                                geometry: geometry,
                                transactions: transactions
                            )
                        case 3:
                            SalesCalcTab(
                                symbol: symbol,
                                atrValue: atrValue,
                                sharesAvailableForTrading: sharesAvailableForTrading,
                                taxLotData: taxLotData,
                                isLoadingTaxLots: isLoadingTaxLots,
                                quoteData: quoteData,
                                geometry: geometry,
                            )
                        case 4:
                            CurrentOrdersTab(symbol: symbol)
                        case 5:
                            OCOOrdersTab(
                                symbol: symbol,
                                atrValue: atrValue,
                                taxLotData: taxLotData,
                                sharesAvailableForTrading: sharesAvailableForTrading,
                                quoteData: quoteData,
                                accountNumber: accountNumber
                            )
                        case 6:
                            SequenceOrdersTab(
                                symbol: symbol,
                                atrValue: atrValue,
                                taxLotData: taxLotData,
                                sharesAvailableForTrading: sharesAvailableForTrading,
                                quoteData: quoteData,
                                accountNumber: accountNumber
                            )
                        default:
                            DetailsTab(
                                position: position,
                                accountNumber: accountNumber,
                                symbol: symbol,
                                atrValue: atrValue,
                                sharesAvailableForTrading: sharesAvailableForTrading,
                                lastPrice: getCurrentPrice(),
                                quoteData: quoteData
                            )
                        }
                    }
                    .onAppear {
                        viewSize = geometry.size
                    }
                    .onChange(of: geometry.size) { oldValue, newValue in
                        viewSize = newValue
                    }
                }
            }
        }
    }
    
    private func getCurrentPrice() -> Double {
        // Use quote data for current price, fallback to price history if quote is not available
        if let quote = quoteData?.quote?.lastPrice {
            return quote
        } else if let extended = quoteData?.extended?.lastPrice {
            return extended
        } else if let regular = quoteData?.regular?.regularMarketLastPrice {
            return regular
        } else {
            // Fallback to price history if no quote data is available
            return priceHistory?.candles.last?.close ?? 0.0
        }
    }
}

// MARK: - TabButton Component
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isSelected ? .accentColor : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
    }
} 
