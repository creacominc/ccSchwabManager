//
//  SalesCalcColumns.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-25.
//

import Foundation

enum SalesCalcColumns : String, CaseIterable
{
    case OpenDate         = "Open Date"
    case Quantity         = "Quantity"
    case Price            = "Price"
    case CostPerShare     = "Cost/Share"
    case MarketValue      = "Market Value"
    case CostBasis        = "Cost Basis"
    case GainLossDollar   = "Gain/Loss $"
    case GainLossPct      = "Gain/Loss %"
}

