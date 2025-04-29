//
//  SapiCandle.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-19.
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
 
 
 CandleList{
 candles    [Candle{...}]
 empty    boolean
 previousClose    number($double)
 previousCloseDate    integer($int64)
 previousCloseDateISO8601    string($yyyy-MM-dd)
 symbol    string
 }
 
 
 */


public struct SapiCandle: Codable {
    public let close: Double
    public let datetime: Int64
    // public let datetimeISO8601: String?
    public let high: Double
    public let low: Double
    public let open: Double
    public let volume: Int64
}


public struct SapiCandleList: Codable {
    public let candles: [SapiCandle]
    public let empty: Bool
    public let previousClose: Double
    public let previousCloseDate: Int64
    // public let previousCloseDateISO8601: String?
    public let symbol: String
}


