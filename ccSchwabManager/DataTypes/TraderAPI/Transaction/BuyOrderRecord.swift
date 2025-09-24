//
//  BuyOrderRecord.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-16.
//

import Foundation

struct BuyOrderRecord: Identifiable
{
    let id = UUID()
    var shares: Double = 0.0
    var targetBuyPrice: Double = 0.0
    var entryPrice: Double = 0.0
    var trailingStop: Double = 0.0
    var targetGainPercent: Double = 0.0
    var currentGainPercent: Double = 0.0
    var sharesToBuy: Double = 0.0
    var orderCost: Double = 0.0
    var description: String = ""
    var orderType: String = ""
    var submitDate: String = ""
    var isImmediate: Bool = false
    // When true, this buy prefers a DAY time-in-force instead of GTC
    var preferDayDuration: Bool = false
}
