//
//  PriceLinkBasis.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 priceLinkBasis    priceLinkBasisstring
 Enum:
 [ MANUAL, BASE, TRIGGER, LAST, BID, ASK, ASK_BID, MARK, AVERAGE ]

 */

public enum PriceLinkBasis: String, Codable, CaseIterable {
    case MANUAL = "MANUAL"
    case BASE = "BASE"
    case TRIGGER = "TRIGGER"
    case LAST = "LAST"
    case BID = "BID"
    case ASK = "ASK"
    case ASK_BID = "ASK_BID"
    case MARK = "MARK"
    case AVERAGE = "AVERAGE"
}
