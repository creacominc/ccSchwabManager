//
//  DivCapGains.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 divCapGains    string
 Enum:
 [ REINVEST, PAYOUT ]

 */

public enum DivCapGains: String, Codable, CaseIterable {
    case REINVEST = "REINVEST"
    case PAYOUT = "PAYOUT"
}
