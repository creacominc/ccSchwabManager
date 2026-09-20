//
//

import Foundation


/**
 
 
 CandleList{
 candles    [Candle{...}]
 empty    boolean
 previousClose    number($double)
 previousCloseDate    integer($int64)
 previousCloseDateISO8601    string($yyyy-MM-dd)
 symbol    string
 }
 */

struct CandleList: Codable, Identifiable, Sendable
{
    public var id: String { symbol ?? "unknown" }
    public let candles: [Candle]
    public let empty: Bool?
    public let previousClose: Double?
    public let previousCloseDate: Int64?
    public let previousCloseDateISO8601: String?
    public let symbol: String?
    
    enum CodingKeys: String, CodingKey
    {
        case candles = "candles"
        case empty = "empty"
        case previousClose = "previousClose"
        case previousCloseDate = "previousCloseDate"
        case previousCloseDateISO8601 = "previousCloseDateISO8601"
        case symbol = "symbol"
    }
 
    public init( candles: [Candle], empty: Bool? = nil,
                 previousClose: Double? = nil,
                 previousCloseDate: Int64? = nil,
                 previousCloseDateISO8601: String? = nil,
                 symbol: String? = nil )
    {
        self.candles = candles
        self.empty = empty
        self.previousClose = previousClose
        self.previousCloseDate = previousCloseDate
        self.previousCloseDateISO8601 = previousCloseDateISO8601
        self.symbol = symbol
    }

}
