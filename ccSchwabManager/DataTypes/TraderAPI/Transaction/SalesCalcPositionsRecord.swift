//
//  SalesCalcPositionsRecord.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-25.
//

import Foundation

struct SalesCalcPositionsRecord: Identifiable, Equatable
{
    let id = UUID()
    var openDate: String = ""
    var gainLossPct: Double = 0.0
    var gainLossDollar: Double = 0.0
    var quantity: Double = 0
    var price: Double = 0.0
    var costPerShare: Double = 0.0
    var marketValue: Double = 0.0
    var costBasis: Double = 0.0
    var splitMultiple: Double = 1.0  // Cumulative split multiple (1.0 = no splits)

    init(openDate: String, gainLossPct: Double, gainLossDollar: Double, quantity: Double, price: Double, costPerShare: Double, marketValue: Double, costBasis: Double, splitMultiple: Double = 1.0
    ) {
        self.openDate = openDate
        self.gainLossPct = gainLossPct
        self.gainLossDollar = gainLossDollar
        self.quantity = quantity
        self.price = price
        self.costPerShare = costPerShare
        self.marketValue = marketValue
        self.costBasis = costBasis
        self.splitMultiple = splitMultiple
    }
    
}


