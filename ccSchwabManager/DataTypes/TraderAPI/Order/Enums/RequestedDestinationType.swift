//
//  RequestedDestinationType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//

/**
 requestedDestination    requestedDestinationstring
 Enum:
 [ INET, ECN_ARCA, CBOE, AMEX, PHLX, ISE, BOX, NYSE, NASDAQ, BATS, C2, AUTO ]

 */

public enum RequestedDestinationType : String, Codable, CaseIterable {
    case INET = "INET"
    case ECN_ARCA = "ECN_ARCA"
    case CBOE = "CBOE"
    case AMEX = "AMEX"
    case PHLX = "PHLX"
    case ISE = "ISE"
    case BOX = "BOX"
    case NYSE = "NYSE"
    case NASDAQ = "NASDAQ"
    case BATS = "BATS"
    case C2 = "C2"
    case AUTO = "AUTO"
}
