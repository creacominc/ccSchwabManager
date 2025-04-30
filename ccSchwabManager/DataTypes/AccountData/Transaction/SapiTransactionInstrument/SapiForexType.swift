//
//  SapiForexType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 string
 Enum:
 [ STANDARD, NBBO, UNKNOWN ]
 */

public enum SapiForexType: String, Codable, CaseIterable
{
    case STANDARD = "STANDARD"
    case NBBO = "NBBO"
    case UNKNOWN = "UNKNOWN"
}
