//
//
//

import Foundation

/**

 Candle{
 close    number($double)
 datetime    integer($int64)
 datetimeISO8601    string($yyyy-MM-dd)
 high    number($double)
 low    number($double)
 open    number($double)
 volume    integer($int64)
 }

 */


class Candle: Codable, Identifiable
{
    public var close: Double?
    public var datetime: Int64?
    public var datetimeISO8601: String?
    public var high: Double?
    public var low: Double?
    public var open: Double?
    public var volume: Int64?

    enum CodingKeys: String, CodingKey
    {
        case close = "close"
        case datetime = "datetime"
        case datetimeISO8601 = "datetimeISO8601"
        case high = "high"
        case low = "low"
        case open = "open"
        case volume = "volume"
    }

    public init( close: Double? = nil, datetime: Int64? = nil,
          datetimeISO8601: String? = nil, high: Double? = nil,
          low: Double? = nil, open: Double? = nil, volume: Int64? = nil )
    {
        self.close = close
        self.datetime = datetime
        self.datetimeISO8601 = datetimeISO8601
        self.high = high
        self.low = low
        self.open = open
        self.volume = volume
    }
    
}



