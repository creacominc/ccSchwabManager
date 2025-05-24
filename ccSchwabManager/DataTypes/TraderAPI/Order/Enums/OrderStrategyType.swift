//
//  OrderStrategyType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 orderStrategyType    orderStrategyTypestring
 Enum:
 [ SINGLE, CANCEL, RECALL, PAIR, FLATTEN, TWO_DAY_SWAP, BLAST_ALL, OCO, TRIGGER ]
 */

public enum OrderStrategyType: String, Codable, CaseIterable {
    case SINGLE = "SINGLE"
    case CANCEL = "CANCEL"
    case RECALL = "RECALL"
    case PAIR = "PAIR"
    case FLATTEN = "FLATTEN"
    case TWO_DAY_SWAP = "TWO_DAY_SWAP"
    case BLAST_ALL = "BLAST_ALL"
    case OCO = "OCO"
    case TRIGGER = "TRIGGER"
}
