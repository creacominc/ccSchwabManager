//
//  PriceLinkType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 priceLinkType    priceLinkTypestring
 Enum:
 [ VALUE, PERCENT, TICK ]

 */

public enum PriceLinkType: String, Codable, CaseIterable {
    case VALUE = "VALUE"
    case PERCENT = "PERCENT"
    case TICK = "TICK"
}
