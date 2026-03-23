import Foundation

/// Pure helpers for matching transaction rows to computed tax-lot cost (merged/renamed securities).
enum TaxLotPriceLookup {
    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    /// Returns cost per share from tax lots when the trade used a zero reported price (e.g. merger ticker).
    static func costPerShare(
        taxLots: [SalesCalcPositionsRecord],
        tradeDateISO8601: String,
        transferItemAmount: Double
    ) -> Double? {
        guard let date = ISO8601DateFormatter().date(from: tradeDateISO8601) else {
            return nil
        }
        let transactionDateString = displayDateFormatter.string(from: date)
        for taxLot in taxLots {
            if taxLot.openDate == transactionDateString && abs(taxLot.quantity - transferItemAmount) < 0.01 {
                return taxLot.costPerShare
            }
        }
        return nil
    }
}
