//
//  SpecialInstruction.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 specialInstruction    specialInstructionstring
 Enum:
 [ ALL_OR_NONE, DO_NOT_REDUCE, ALL_OR_NONE_DO_NOT_REDUCE ]
 */
public enum SpecialInstruction: String, Codable, CaseIterable {
    case allOrNone = "ALL_OR_NONE"
    case doNotReduce = "DO_NOT_REDUCE"
    case allOrNoneDoNotReduce = "ALL_OR_NONE_DO_NOT_REDUCE"
}
