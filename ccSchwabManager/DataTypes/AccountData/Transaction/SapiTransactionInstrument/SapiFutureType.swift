//
//  SapiFutureType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-29.
//

import Foundation

/**
 string
 Enum:
 [ STANDARD, UNKNOWN ]

 */

public enum SapiFutureType: String, Codable, CaseIterable
{
    case STANDARD = "STANDARD"
    case UNKNOWN = "UNKNOWN"
}
