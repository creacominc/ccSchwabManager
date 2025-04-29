//
//  SapiIndexType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 
 string
 Enum:
 [ BROAD_BASED, NARROW_BASED, UNKNOWN ]
 */

public enum SapiIndexType: String, Codable, CaseIterable
{
    case broadBased = "BROAD_BASED"
    case narrowBased = "NARROW_BASED"
    case unknown = "UNKNOWN"
}
