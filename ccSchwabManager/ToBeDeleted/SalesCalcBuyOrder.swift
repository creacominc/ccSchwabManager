//
//  BuyOrder.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-25.
//

import Foundation


// BUY 10% (of +138 currently) PLTR @89.85 (LAST+0.05%) TRSTPLMT LAST+5.93%(5.60) (STP 94.36) BID GTC OCO #1002926348365 SUBMIT AT 3/12/25 09:40:00 WHEN PLTR BID AT OR ABOVE 89.82
struct SalesCalcBuyOrder: Identifiable
{
    let id = UUID()
    var percent          : Double = 0.0
    var equivalentShares : Int = 0
    var trailingStop     : Double = 0.0
    var submitDate       : Date = Date()
    var bidPriceOver     : Double = 0.0
}


