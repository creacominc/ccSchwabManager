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
