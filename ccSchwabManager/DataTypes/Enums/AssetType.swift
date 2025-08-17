
import Foundation

/**
 
   Account -> Positions[] -> instrument -> assetType

 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]

 */

public enum AssetType: String, Codable, CaseIterable, Comparable
{
    case EQUITY                 = "EQUITY"
    case OPTION                 = "OPTION"
    case INDEX                  = "INDEX"
    case MUTUAL_FUND            = "MUTUAL_FUND"
    case CASH_EQUIVALENT        = "CASH_EQUIVALENT"
    case FIXED_INCOME           = "FIXED_INCOME"
    case CURRENCY               = "CURRENCY"
    case COLLECTIVE_INVESTMENT  = "COLLECTIVE_INVESTMENT"
    case FUTURE                 = "FUTURE"
    case FOREX                  = "FOREX"
    case PRODUCT                = "PRODUCT"
    
    /// Short display name for UI purposes
    var shortDisplayName: String {
        switch self {
        case .EQUITY:
            return "Equity"
        case .OPTION:
            return "Option"
        case .INDEX:
            return "Index"
        case .MUTUAL_FUND:
            return "Mutual"
        case .CASH_EQUIVALENT:
            return "Cash"
        case .FIXED_INCOME:
            return "Fixed"
        case .CURRENCY:
            return "Currency"
        case .COLLECTIVE_INVESTMENT:
            return "Collective"
        case .FUTURE:
            return "Future"
        case .FOREX:
            return "Forex"
        case .PRODUCT:
            return "Product"
        }
    }
    
    /// Implementation of Comparable to enable sorting
    public static func < (lhs: AssetType, rhs: AssetType) -> Bool {
        return lhs.shortDisplayName < rhs.shortDisplayName
    }
}

