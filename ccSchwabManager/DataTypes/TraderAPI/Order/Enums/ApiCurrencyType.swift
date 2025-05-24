//
//  ApiCurrencyType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

import Foundation

/**
 apiCurrencyType    string
 Enum:
 [ USD, CAD, EUR, JPY ]

 */

public enum ApiCurrencyType: String, Codable, CaseIterable {
    case USD = "USD"
    case CAD = "CAD"
    case EUR = "EUR"
    case JPY = "JPY"
}
