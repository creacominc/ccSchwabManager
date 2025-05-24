//
//  QuantityType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 quantityType    string
 Enum:
 [ ALL_SHARES, DOLLARS, SHARES ]

 */

public enum QuantityType: String, Codable, CaseIterable {
    case allShares = "ALL_SHARES"
    case dollars = "DOLLARS"
    case shares = "SHARES"
}
