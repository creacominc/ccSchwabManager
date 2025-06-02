//
//  SalesCalcPositionsRecord.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-25.
//

import Foundation

struct SalesCalcPositionsRecord: Identifiable
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

    init(openDate: String, gainLossPct: Double, gainLossDollar: Double, quantity: Double, price: Double, costPerShare: Double, marketValue: Double, costBasis: Double
    ) {
        self.openDate = openDate
        self.gainLossPct = gainLossPct
        self.gainLossDollar = gainLossDollar
        self.quantity = quantity
        self.price = price
        self.costPerShare = costPerShare
        self.marketValue = marketValue
        self.costBasis = costBasis
    }
    
}


