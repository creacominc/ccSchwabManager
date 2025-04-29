
import Foundation

/**
 Enum:
 [ EQUITY, OPTION, INDEX, MUTUAL_FUND, CASH_EQUIVALENT, FIXED_INCOME, CURRENCY, COLLECTIVE_INVESTMENT ]

 */

public enum AssetType: String, Codable, CaseIterable
{
    case EQUITY = "EQUITY"
    case OPTION = "OPTION"
    case INDEX = "INDEX"
    case MUTUAL_FUND = "MUTUAL_FUND"
    case CASH_EQUIVALENT = "CASH_EQUIVALENT"
    case FIXED_INCOME = "FIXED_INCOME"
    case CURRENCY = "CURRENCY"
    case COLLECTIVE_INVESTMENT = "COLLECTIVE_INVESTMENT"
    case FUTURE = "FUTURE"
    case FOREX  = "FOREX"
    case PRODUCT = "PRODUCT"
}

