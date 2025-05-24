//
//  Instruction.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 OrderInstructionType
 Enum:
 [ BUY, SELL, BUY_TO_COVER, SELL_SHORT, BUY_TO_OPEN, BUY_TO_CLOSE, SELL_TO_OPEN, SELL_TO_CLOSE, EXCHANGE, SELL_SHORT_EXEMPT ]

 */

public enum OrderInstructionType: String, Codable, CaseIterable {
    case BUY = "BUY"
    case SELL = "SELL"
    case BUY_TO_COVER = "BUY_TO_COVER"
    case SELL_SHORT = "SELL_SHORT"
    case BUY_TO_OPEN = "BUY_TO_OPEN"
    case BUY_TO_CLOSE = "BUY_TO_CLOSE"
    case SELL_TO_OPEN = "SELL_TO_OPEN"
    case SELL_TO_CLOSE = "SELL_TO_CLOSE"
    case EXCHANGE = "EXCHANGE"
    case SELL_SHORT_EXEMPT = "SELL_SHORT_EXEMPT"
}
