//
//  SapiPositionEffectType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-27.
//

/**
 positionEffect    string
 Enum:
 [ OPENING, CLOSING, AUTOMATIC, UNKNOWN ]

 */

import Foundation

public enum SapiPositionEffectType: String, Codable, CaseIterable
{
    case OPENING = "OPENING"
    case CLOSING = "CLOSING"
    case AUTOMATIC = "AUTOMATIC"
    case UNKNOWN = "UNKNOWN"
}

