import SwiftUI

struct PositionDetailContent: View
{
    let position: Position
    let accountNumber: String
    let currentIndex: Int
    let totalPositions: Int
    let symbol: String
    let atrValue: Double
    @Binding var sharesAvailableForTrading: Double
    @Binding var marketValue: Double
    let onNavigate: (Int) -> Void
    let priceHistory: CandleList?
    let isLoadingPriceHistory: Bool
    let isLoadingTransactions: Bool
    let formatDate: (Int64?) -> String
    let quoteData: QuoteData?
    let taxLotData: [SalesCalcPositionsRecord]
    let isLoadingTaxLots: Bool
    let transactions: [Transaction]
    let loadStates: [SecurityDataGroup: SecurityDataLoadState]
    @Binding var selectedTab: Int
    @State private var orders: [Order] = []
    @State private var isLoadingOrders: Bool = true
    
    // Unique ID for price history tab to force re-rendering when data changes
    private var priceHistoryId: String {
        if let history = priceHistory {
            return "priceHistory_\(history.symbol ?? "none")_\(history.candles.count)"
        }
        return "priceHistory_none_0"
    }

    /// Merges live view fields with cache (order recommendations) so tab icons match `SecurityDataSnapshot` rules.
    private var indicatorSnapshot: SecurityDataSnapshot {
        let cached = SecurityDataCacheManager.shared.snapshot(for: symbol)
        return SecurityDataSnapshot(
            symbol: symbol,
            fetchedAt: cached?.fetchedAt ?? Date(),
            priceHistory: priceHistory,
            transactions: transactions,
            quoteData: quoteData,
            atrValue: atrValue,
            taxLotData: taxLotData,
            sharesAvailableForTrading: sharesAvailableForTrading,
            recommendedSellOrders: cached?.recommendedSellOrders,
            recommendedBuyOrders: cached?.recommendedBuyOrders,
            loadStates: loadStates
        )
    }

    private var currentOrdersTabIndicator: SecurityGroupLoadIndicator {
        isLoadingOrders ? .foregroundInFlight : .ready
    }

    private var detailsTabView: some View
    {
        DetailsTab(
            position: position,
            accountNumber: accountNumber,
            symbol: symbol,
            atrValue: atrValue,
            sharesAvailableForTrading: $sharesAvailableForTrading,
            lastPrice: getCurrentPrice(),
            quoteData: quoteData
        )
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            // Custom tab bar with integrated navigation
            VStack(spacing: 0)
            {
                // Navigation and tab header row
                HStack(spacing: 0)
                {
                    // Previous Position Button
                    Button(action: { onNavigate(currentIndex - 1) })
                    {
                        Image(systemName: "chevron.left")
                            .tableCellFont()
                            .foregroundColor(.accentColor)
                    }
                    .disabled(currentIndex <= 0)
                    .keyboardShortcut(.leftArrow, modifiers: [])
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)

                    // Tab buttons
                    HStack(spacing: 0)
                    {
                        TabButton(
                            title: position.instrument?.symbol ?? "Summary",
                            icon: "list.bullet",
                            isSelected: selectedTab == 0,
                            iconLoadIndicator: indicatorSnapshot.groupLoadIndicator(for: .details),
                            action: { selectedTab = 0 }
                        )

                        TabButton(
                            title: "Price History",
                            icon: "chart.line.uptrend.xyaxis",
                            isSelected: selectedTab == 1,
                            iconLoadIndicator: indicatorSnapshot.groupLoadIndicator(for: .priceHistory),
                            action: { selectedTab = 1 }
                        )

                        TabButton(
                            title: "Transactions",
                            icon: "list.bullet.rectangle",
                            isSelected: selectedTab == 2,
                            iconLoadIndicator: indicatorSnapshot.groupLoadIndicator(for: .transactions),
                            action: { selectedTab = 2 }
                        )

                        TabButton(
                            title: "Sales Calc",
                            icon: "number.circle.fill",
                            isSelected: selectedTab == 3,
                            iconLoadIndicator: indicatorSnapshot.groupLoadIndicator(for: .taxLots),
                            action: { selectedTab = 3 }
                        )

                        TabButton(
                            title: "Current",
                            icon: "clock.arrow.circlepath",
                            isSelected: selectedTab == 4,
                            iconLoadIndicator: currentOrdersTabIndicator,
                            action: { selectedTab = 4 }
                        )
                        
                        TabButton(
                            title: "OCO",
                            icon: "chart.line.uptrend.xyaxis",
                            isSelected: selectedTab == 5,
                            iconLoadIndicator: indicatorSnapshot.combinedGroupLoadIndicator(groups: [.taxLots, .orderRecommendations]),
                            action: { selectedTab = 5 }
                        )

                        TabButton(
                            title: "Sequence",
                            icon: "arrow.up.circle",
                            isSelected: selectedTab == 6,
                            iconLoadIndicator: indicatorSnapshot.combinedGroupLoadIndicator(groups: [.taxLots, .orderRecommendations]),
                            action: { selectedTab = 6 }
                        )
                    }
                    .background(Color.gray.opacity(0.1))

                    // Next Position Button
                    Button(action: { onNavigate(currentIndex + 1) })
                    {
                        Image(systemName: "chevron.right")
                            .tableCellFont()
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
                GeometryReader
                { geometry in
                    // Custom content switcher instead of TabView
                    Group
                    {
                        switch selectedTab
                        {
                        case 1:
                            PriceHistoryTab(
                                priceHistory: priceHistory,
                                isLoading: isLoadingPriceHistory,
                                formatDate: formatDate,
                                atrValue: atrValue,
                                position: position,
                                sharesAvailableForTrading: $sharesAvailableForTrading,
                                marketValue: $marketValue,
                                lastPrice: getCurrentPrice()
                            )
                            .id(priceHistoryId)
                        case 2:
                            TransactionsTab(
                                isLoading: isLoadingTransactions,
                                symbol: position.instrument?.symbol ?? "",
                                transactions: transactions,
                                atrValue: atrValue,
                                position: position,
                                sharesAvailableForTrading: $sharesAvailableForTrading,
                                marketValue: $marketValue,
                                lastPrice: getCurrentPrice()
                            )
                        case 3:
                            SalesCalcTab(
                                symbol: symbol,
                                atrValue: atrValue,
                                position: position,
                                sharesAvailableForTrading: $sharesAvailableForTrading,
                                marketValue: $marketValue,
                                taxLotData: taxLotData,
                                isLoadingTaxLots: isLoadingTaxLots,
                                quoteData: quoteData,
                                lastPrice: getCurrentPrice()
                            )
                        case 4:
                            CurrentOrdersTab(
                                symbol: symbol, orders: orders,
                                position: position,
                                sharesAvailableForTrading: $sharesAvailableForTrading,
                                marketValue: $marketValue,
                                atrValue: atrValue,
                                lastPrice: getCurrentPrice()
                            )
                        case 5:
                            OCOOrdersTab(
                                symbol: symbol,
                                atrValue: atrValue,
                                taxLotData: taxLotData,
                              isLoadingTaxLots: isLoadingTaxLots,
                                sharesAvailableForTrading: $sharesAvailableForTrading,
                                marketValue: $marketValue,
                                quoteData: quoteData,
                                accountNumber: accountNumber,
                                position: position,
                                lastPrice: getCurrentPrice()
                            )
                        case 6:
                            SequenceOrdersTab(
                                symbol: symbol,
                                atrValue: atrValue,
                                taxLotData: taxLotData,
                                sharesAvailableForTrading: $sharesAvailableForTrading,
                                marketValue: $marketValue,
                                quoteData: quoteData,
                                accountNumber: accountNumber,
                                position: position,
                                lastPrice: getCurrentPrice()
                            )
                        case 0:
                            detailsTabView
                        default:
                            detailsTabView
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        fetchOrders()
                    }
                    .onChange(of: symbol) { _, _ in
                        fetchOrders()
                    }
                }
            }
        }
    }

    private func getCurrentPrice() -> Double
    {
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

    private func fetchOrders()
    {
        isLoadingOrders = true
        Task
        {
            let fetchedOrders = SchwabClient.shared.getOrderList()
            await MainActor.run {
                self.orders = fetchedOrders
                self.isLoadingOrders = false
            }
        }
    }
}

// MARK: - TabButton Component
struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    /// When set, only the SF Symbol is tinted (red = foreground load, orange = prefetch, green = ready).
    var iconLoadIndicator: SecurityGroupLoadIndicator? = nil
    let action: () -> Void

    private var iconForegroundColor: Color {
        guard let iconLoadIndicator else {
            return isSelected ? Color.accentColor : Color.primary
        }
        switch iconLoadIndicator {
        case .foregroundInFlight:
            return .red
        case .prefetchInFlight:
            return .orange
        case .ready:
            return .green
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .detailFont()
                    .foregroundStyle(iconForegroundColor)
                Text(title)
                    .font(FontStyles.detailSmall)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        }
        .buttonStyle(.plain)
    }
} 
