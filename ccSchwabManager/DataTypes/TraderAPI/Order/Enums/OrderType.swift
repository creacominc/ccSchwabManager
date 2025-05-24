//
//  OrderType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

/**
orderTypestring
Enum:
[ MARKET, LIMIT, STOP, STOP_LIMIT, TRAILING_STOP, CABINET, NON_MARKETABLE, MARKET_ON_CLOSE, EXERCISE, TRAILING_STOP_LIMIT, NET_DEBIT, NET_CREDIT, NET_ZERO, LIMIT_ON_CLOSE, UNKNOWN ]
*/

import Foundation

public enum OrderType: String, Codable, CaseIterable
{
    case MARKET = "MARKET"
    case LIMIT = "LIMIT"
    case STOP = "STOP"
    case STOP_LIMIT = "STOP_LIMIT"
    case TRAILING_STOP = "TRAILING_STOP"
    case CABINET = "CABINET"
    case NON_MARKETABLE = "NON_MARKETABLE"
    case EXERCISE = "EXERCISE"
    case TRAILING_STOP_LIMIT = "TRAILING_STOP_LIMIT"
    case MARKET_ON_CLOSE = "MARKET_ON_CLOSE"
    case LIMIT_ON_CLOSE = "LIMIT_ON_CLOSE"
    case UNKNOWN = "UNKNOWN"
}

