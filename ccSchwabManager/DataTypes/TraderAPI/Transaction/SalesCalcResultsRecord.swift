//
//  SalesCalcResultsRecord.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-25.
//

import Foundation

struct SalesCalcResultsRecord: Identifiable
{
    let id = UUID()
    var shares : Double = 0.0
    var rollingGainLoss: Double = 0.0
    var breakEven: Double = 0.0
    var gain: Double = 0.0
    var sharesToSell: Double = 0.0
    var trailingStop: Double = 0.0
    var entry: Double = 0.0
    var target: Double = 0.0
    var cancel: Double = 0.0
    var description: String = ""
    var openDate: String = ""
}

