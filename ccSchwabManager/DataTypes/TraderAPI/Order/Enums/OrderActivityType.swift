//
//  OrderActivityType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 activityType    string
 Enum:
 [ EXECUTION, ORDER_ACTION ]

 */

public enum OrderActivityType: String, Codable, CaseIterable {
    case execution = "EXECUTION"
    case orderAction = "ORDER_ACTION"
}
