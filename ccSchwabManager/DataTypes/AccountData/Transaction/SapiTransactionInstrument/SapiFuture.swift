//
//  SapiFuture.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 SapiFuture{
 activeContract    boolean  default: false
 type    SapiFutureType
 expirationDate    string($date-time)
 lastTradingDate    string($date-time)
 firstNoticeDate    string($date-time)
 multiplier    number($double)
 }
 */

public struct SapiFuture: Codable
{
    public var activeContract: Bool
    public var type: SapiFutureType
    public var expirationDate: String
    public var lastTradingDate: String
    public var firstNoticeDate: String
    public var multiplier: Double
}

