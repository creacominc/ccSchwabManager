import Testing
@testable import ccSchwabManager

struct TransactionHistoryStoreTests {
    @Test
    func mergeDeduplicatesAndFiltersBySymbol() async {
        let store = TransactionHistoryStore()
        let apple = makeTransaction(activityId: 1, symbol: "AAPL")
        let nvidia = makeTransaction(activityId: 2, symbol: "NVDA")

        await store.merge([apple, nvidia, apple])

        #expect(await store.allTransactions().count == 2)
        #expect(await store.transactions(for: "AAPL") == [apple])
    }

    @Test
    func sliceReservationsDoNotOverlap() async {
        let store = TransactionHistoryStore()

        async let first = store.reserveNextSlice(upTo: 3)
        async let second = store.reserveNextSlice(upTo: 3)
        async let third = store.reserveNextSlice(upTo: 3)
        let months = await [first?.month, second?.month, third?.month].compactMap { $0 }

        #expect(Set(months) == Set([1, 2, 3]))
        #expect(await store.reserveNextSlice(upTo: 3) == nil)
    }

    private func makeTransaction(activityId: Int64, symbol: String) -> Transaction {
        Transaction(
            activityId: activityId,
            tradeDate: "2026-01-01T12:00:00+0000",
            transferItems: [
                TransferItem(
                    instrument: Instrument(assetType: .EQUITY, symbol: symbol),
                    amount: 1,
                    price: 10,
                    positionEffect: .OPENING
                )
            ]
        )
    }
}
