import XCTest
@testable import ccSchwabManager

final class SecurityDataCacheManagerTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        SecurityDataCacheManager.shared.clear()
    }

    override func tearDownWithError() throws {
        SecurityDataCacheManager.shared.clear()
        try super.tearDownWithError()
    }

    func testStoreAndRetrieveSnapshot() {
        let symbol = "AAPL"
        let snapshot = makeSnapshot(symbol: symbol)

        _ = SecurityDataCacheManager.shared.update(symbol: symbol) { cached in
            cached = snapshot
        }

        let cached = SecurityDataCacheManager.shared.snapshot(for: symbol)

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.symbol, symbol)
        XCTAssertEqual(cached?.atrValue, snapshot.atrValue)
        XCTAssertEqual(cached?.sharesAvailableForTrading, snapshot.sharesAvailableForTrading)
    }

    func testLRUEvictionRemovesOldestEntry() {
        // Fill cache to capacity
        for index in 0..<10 {
            _ = SecurityDataCacheManager.shared.update(symbol: "SYM\(index)") { cached in
                cached = makeSnapshot(symbol: "SYM\(index)")
            }
        }

        // Access a middle entry to keep it fresh
        _ = SecurityDataCacheManager.shared.snapshot(for: "SYM5")

        // Add a new entry to trigger eviction
        _ = SecurityDataCacheManager.shared.update(symbol: "NEW") { cached in
            cached = makeSnapshot(symbol: "NEW")
        }

        // Oldest entry should be evicted (SYM0)
        XCTAssertNil(SecurityDataCacheManager.shared.snapshot(for: "SYM0"))
        // Frequently accessed entry should remain
        XCTAssertNotNil(SecurityDataCacheManager.shared.snapshot(for: "SYM5"))
        // New entry should be present
        XCTAssertNotNil(SecurityDataCacheManager.shared.snapshot(for: "NEW"))
    }

    func testRemoveClearsSpecificSymbol() {
        let symbol = "TSLA"
        _ = SecurityDataCacheManager.shared.update(symbol: symbol) { cached in
            cached = makeSnapshot(symbol: symbol)
        }

        SecurityDataCacheManager.shared.remove(symbol: symbol)

        XCTAssertNil(SecurityDataCacheManager.shared.snapshot(for: symbol))
    }

    func testGroupsNeedingBackgroundWork_MissingSymbol_ReturnsAllGroups() {
        let groups: [SecurityDataGroup] = [.details, .priceHistory]
        let needed = SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(symbol: "XYZ", among: groups)
        XCTAssertEqual(Set(needed), Set(groups))
    }

    func testGroupsNeedingBackgroundWork_LoadedGroupExcluded() {
        let symbol = "AAPL"
        _ = SecurityDataCacheManager.shared.markLoaded(symbol: symbol, group: .details) { $0.quoteData = nil }

        let needed = SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(
            symbol: symbol,
            among: [.details, .transactions]
        )
        XCTAssertEqual(needed, [.transactions])
    }

    func testGroupsNeedingBackgroundWork_LoadingGroupExcluded() {
        let symbol = "MSFT"
        _ = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: [.details])

        let needed = SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(
            symbol: symbol,
            among: [.details, .priceHistory]
        )
        XCTAssertEqual(needed, [.priceHistory])
    }

    func testGroupsNeedingBackgroundWork_PrefetchLoadingGroupExcluded() {
        let symbol = "AMD"
        _ = SecurityDataCacheManager.shared.markLoadingPrefetch(symbol: symbol, groups: [.priceHistory])

        let needed = SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(
            symbol: symbol,
            among: [.priceHistory, .transactions]
        )
        XCTAssertEqual(needed, [.transactions])
    }

    func testHoldingsSortInProgress_suppressesPrefetchFlag() {
        XCTAssertFalse(SecurityDataCacheManager.shared.isPrefetchCacheSuppressed)
        SecurityDataCacheManager.shared.setHoldingsListSortInProgress(true)
        XCTAssertTrue(SecurityDataCacheManager.shared.isPrefetchCacheSuppressed)
        SecurityDataCacheManager.shared.setHoldingsListSortInProgress(false)
        XCTAssertFalse(SecurityDataCacheManager.shared.isPrefetchCacheSuppressed)
    }

    func testClear_resetsPrefetchSuppression() {
        SecurityDataCacheManager.shared.setHoldingsListSortInProgress(true)
        XCTAssertTrue(SecurityDataCacheManager.shared.isPrefetchCacheSuppressed)
        SecurityDataCacheManager.shared.clear()
        XCTAssertFalse(SecurityDataCacheManager.shared.isPrefetchCacheSuppressed)
    }

    func testRevertPrefetchLoadingStates_clearsLoadingWithoutData() {
        let symbol = "NVDA"
        _ = SecurityDataCacheManager.shared.markLoading(symbol: symbol, groups: [.details, .transactions])
        SecurityDataCacheManager.shared.revertPrefetchLoadingStates(symbol: symbol, groups: [.details, .transactions])

        let needed = SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(
            symbol: symbol,
            among: [.details, .transactions]
        )
        XCTAssertEqual(Set(needed), Set([SecurityDataGroup.details, SecurityDataGroup.transactions]))
    }

    func testRevertPrefetchLoadingStates_clearsPrefetchLoadingWithoutData() {
        let symbol = "INTC"
        _ = SecurityDataCacheManager.shared.markLoadingPrefetch(symbol: symbol, groups: [.details])
        SecurityDataCacheManager.shared.revertPrefetchLoadingStates(symbol: symbol, groups: [.details])

        let needed = SecurityDataCacheManager.shared.groupsNeedingBackgroundWork(symbol: symbol, among: [.details])
        XCTAssertEqual(needed, [.details])
    }

    func testGroupLoadIndicator_prefetchVsForeground() {
        let sym = "TEST"
        var snap = SecurityDataSnapshot(symbol: sym, loadStates: [.details: .loadingPrefetch(Date())])
        XCTAssertEqual(snap.groupLoadIndicator(for: .details), .prefetchInFlight)
        snap.loadStates[.details] = .loading(Date())
        XCTAssertEqual(snap.groupLoadIndicator(for: .details), .foregroundInFlight)
    }

    // MARK: - Helpers

    private func makeSnapshot(symbol: String) -> SecurityDataSnapshot {
        let candleList = CandleList(candles: [])
        let transaction = Transaction(transferItems: [])
        let taxLot = SalesCalcPositionsRecord(
            openDate: "2024-01-01",
            gainLossPct: 1.0,
            gainLossDollar: 10.0,
            quantity: 5.0,
            price: 2.0,
            costPerShare: 2.0,
            marketValue: 10.0,
            costBasis: 10.0
        )

        return SecurityDataSnapshot(
            symbol: symbol,
            fetchedAt: Date(),
            priceHistory: candleList,
            transactions: [transaction],
            quoteData: nil,
            atrValue: 1.23,
            taxLotData: [taxLot],
            sharesAvailableForTrading: 42.0
        )
    }
}
