

import Foundation

/**
   @TODO:  Verify - used by market data quotes.
 */

public enum EquityAssetSubType: String, Codable, CaseIterable
{
    case COE
    case PRF
    case ADR
    case GDR
    case CEF
    case ETF
    case ETN
    case UIT
    case WAR
    case RGT
}
