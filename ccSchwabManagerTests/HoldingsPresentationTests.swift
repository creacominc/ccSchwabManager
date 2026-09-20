import Testing
@testable import ccSchwabManager

@MainActor
struct HoldingsPresentationTests {
    @Test
    func filteringCombinesTextAssetAccountAndOrderStatus() {
        let model = HoldingsViewModel()
        let apple = makePosition(symbol: "AAPL", description: "Apple", value: 200)
        let fund = makePosition(symbol: "FUND", description: "Income Fund", assetType: .MUTUAL_FUND, value: 100)
        let accounts = [(apple, "767", ""), (fund, "487", "")]

        let filtered = model.filteredHoldings(
            from: [apple, fund],
            searchText: " apple ",
            selectedAssetTypes: [.EQUITY],
            accountPositions: accounts,
            selectedAccountNumbers: ["767"],
            selectedOrderStatuses: [.awaitingSellStopCondition],
            includeNAStatus: false,
            orderStatusCache: ["AAPL": .awaitingSellStopCondition]
        )

        #expect(filtered.count == 1)
        #expect(filtered.first === apple)
    }

    @Test
    func sortingUsesStableSymbolOrderWhenTradeDatesMatch() {
        let model = HoldingsViewModel()
        let beta = makePosition(symbol: "BETA", value: 200)
        let alpha = makePosition(symbol: "ALPHA", value: 100)

        let sorted = model.sortedHoldings(
            [beta, alpha],
            using: SortConfig(column: .lastTradeDate, ascending: false),
            accountPositions: [],
            tradeDateCache: ["ALPHA": "2026-09-20", "BETA": "2026-09-20"],
            orderStatusCache: [:]
        )

        #expect(sorted.map { $0.instrument?.symbol } == ["ALPHA", "BETA"])
    }

    @Test
    func positionDetailCancellationCancelsEveryOwnedTask() {
        let model = PositionDetailViewModel()
        let dataLoad = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
        let tabLoad = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
        let prefetch = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
        let history = Task<Void, Never> { try? await Task.sleep(for: .seconds(60)) }
        model.dataLoadTask = dataLoad
        model.tabLoadTasks[.transactions] = tabLoad
        model.prefetchTasks["AAPL"] = prefetch
        model.historyBackfillTask = history

        model.cancelBackgroundTasks()

        #expect(dataLoad.isCancelled)
        #expect(tabLoad.isCancelled)
        #expect(prefetch.isCancelled)
        #expect(history.isCancelled)
        #expect(model.dataLoadTask == nil)
        #expect(model.tabLoadTasks.isEmpty)
        #expect(model.prefetchTasks.isEmpty)
    }

    private func makePosition(
        symbol: String,
        description: String = "",
        assetType: AssetType = .EQUITY,
        value: Double
    ) -> Position {
        Position(
            averagePrice: value / 10,
            longQuantity: 10,
            instrument: Instrument(assetType: assetType, symbol: symbol, description: description),
            marketValue: value,
            longOpenProfitLoss: value / 10
        )
    }
}
