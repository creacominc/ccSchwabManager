//
//  OrderExecutionType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 executionType    string
 Enum:
 [ FILL ]

 */

public enum OrderExecutionType: String, Codable, CaseIterable {
    case FILL = "FILL"
    case CANCELED = "CANCELED"
}
