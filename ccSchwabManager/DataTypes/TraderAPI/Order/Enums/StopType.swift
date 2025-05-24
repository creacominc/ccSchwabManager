//
//  StopType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 stopType    stopTypestring
 Enum:
 [ STANDARD, BID, ASK, LAST, MARK ]

 */

public enum StopType: String, Codable, CaseIterable {
    case STANDARD = "STANDARD"
    case BID = "BID"
    case ASK = "ASK"
    case LAST = "LAST"
    case MARK = "MARK"
}
