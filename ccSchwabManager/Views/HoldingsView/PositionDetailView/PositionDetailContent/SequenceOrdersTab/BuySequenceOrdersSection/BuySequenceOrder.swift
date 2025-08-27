import Foundation

public struct BuySequenceOrder {
    let orderIndex: Int
    let shares: Double
    let targetPrice: Double
    let entryPrice: Double
    let trailingStop: Double
    let orderCost: Double
    let description: String
}
