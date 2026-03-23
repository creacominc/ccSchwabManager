import XCTest
@testable import ccSchwabManager

final class TaxLotPriceLookupTests: XCTestCase {

    func testReturnsNilWhenNoMatchingLot() {
        let lots: [SalesCalcPositionsRecord] = [
            SalesCalcPositionsRecord(
                openDate: "2020-01-01 12:00:00",
                gainLossPct: 0, gainLossDollar: 0, quantity: 1, price: 0, costPerShare: 10, marketValue: 0, costBasis: 0
            )
        ]
        let found = TaxLotPriceLookup.costPerShare(
            taxLots: lots,
            tradeDateISO8601: "2025-06-01T14:00:00+0000",
            transferItemAmount: 1
        )
        XCTAssertNil(found)
    }

    func testResolvesCostPerShareForZeroPricedTrade() {
        let tradeISO = "2025-06-01T14:00:00+0000"
        let iso = ISO8601DateFormatter()
        guard let parsed = iso.date(from: tradeISO) else {
            XCTFail("ISO date parse")
            return
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        let openDate = f.string(from: parsed)

        let lots: [SalesCalcPositionsRecord] = [
            SalesCalcPositionsRecord(
                openDate: openDate,
                gainLossPct: 0, gainLossDollar: 0, quantity: 10, price: 0, costPerShare: 12.34, marketValue: 0, costBasis: 0
            )
        ]

        let price = TaxLotPriceLookup.costPerShare(
            taxLots: lots,
            tradeDateISO8601: tradeISO,
            transferItemAmount: 10
        )
        XCTAssertNotNil(price)
        XCTAssertEqual(price!, 12.34, accuracy: 0.0001)
    }

    func testQuantityTolerance() {
        let tradeISO = "2024-03-10T09:00:00+0000"
        let iso = ISO8601DateFormatter()
        guard let parsed = iso.date(from: tradeISO) else {
            XCTFail("ISO date parse")
            return
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        let openDate = f.string(from: parsed)

        let lots: [SalesCalcPositionsRecord] = [
            SalesCalcPositionsRecord(
                openDate: openDate,
                gainLossPct: 0, gainLossDollar: 0, quantity: 1.005, price: 0, costPerShare: 99, marketValue: 0, costBasis: 0
            )
        ]
        let price = TaxLotPriceLookup.costPerShare(
            taxLots: lots,
            tradeDateISO8601: tradeISO,
            transferItemAmount: 1.0
        )
        XCTAssertNotNil(price)
        XCTAssertEqual(price!, 99, accuracy: 0.0001)
    }
}
