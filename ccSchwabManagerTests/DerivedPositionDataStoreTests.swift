import Testing
@testable import ccSchwabManager

struct DerivedPositionDataStoreTests {
    @Test
    func cachesIndependentSymbols() async {
        let store = DerivedPositionDataStore()
        let apple = CandleList(candles: [Candle(close: 100)], empty: false, symbol: "AAPL")
        let nvidia = CandleList(candles: [Candle(close: 200)], empty: false, symbol: "NVDA")

        await store.cachePriceHistory(apple, for: "AAPL")
        await store.cachePriceHistory(nvidia, for: "NVDA")
        await store.cacheATR(1.5, for: "AAPL")

        #expect(await store.priceHistory(for: "AAPL")?.candles.first?.close == 100)
        #expect(await store.priceHistory(for: "NVDA")?.candles.first?.close == 200)
        #expect(await store.atr(for: "AAPL") == 1.5)
    }

    @Test
    func clearingMarketDataDoesNotRetainStaleValues() async {
        let store = DerivedPositionDataStore()
        await store.cachePriceHistory(
            CandleList(candles: [Candle(close: 100)], empty: false, symbol: "AAPL"),
            for: "AAPL"
        )
        await store.cacheATR(1.5, for: "AAPL")

        await store.clearPriceHistory()
        await store.clearATR()

        #expect(await store.priceHistory(for: "AAPL") == nil)
        #expect(await store.atr(for: "AAPL") == nil)
    }
}
