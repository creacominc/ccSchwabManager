//
//  ResultsColumns.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-25.
//

import Foundation


enum SalesCalcResultsColumns : String, CaseIterable
{
    case RollingGainLoss  = "Rolling Gain/Loss"
    case Breakeven        = "Breakeven"
    case SharesToSell     = "Shares to Sell"
    case Gain             = "Gain"
    case TrailingStop     = "TS"
    case Entry            = "Entry"
    case Cancel           = "Cancel"
    case Description      = "Description"
}


