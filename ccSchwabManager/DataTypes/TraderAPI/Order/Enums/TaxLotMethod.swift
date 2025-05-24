//
//  TaxLotMethod.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 taxLotMethod    taxLotMethodstring
 Enum:
 [ FIFO, LIFO, HIGH_COST, LOW_COST, AVERAGE_COST, SPECIFIC_LOT, LOSS_HARVESTER ]

 */

public enum TaxLotMethod: String, Codable, CaseIterable {
    case FIFO = "FIFO"
    case LIFO = "LIFO"
    case HIGH_COST = "HIGH_COST"
    case LOW_COST = "LOW_COST"
    case AVERAGE_COST = "AVERAGE_COST"
    case SPECIFIC_LOT = "SPECIFIC_LOT"
    case LOSS_HARVESTER = "LOSS_HARVESTER"
}
