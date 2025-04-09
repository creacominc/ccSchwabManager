
import Foundation

/**
 SWEEP_VEHICLE, SAVINGS, MONEY_MARKET_FUND, UNKNOWN
 */

public enum SapiAccountCashEquivilantType: String, Codable, CaseIterable
{
    case sweepVehicle = "SWEEP_VEHICLE"
    case savings = "SAVINGS"
    case moneyMarketFund = "MONEY_MARKET_FUND"
    // mutual fund
    case NO_LOAD_TAXABLE = "NO_LOAD_TAXABLE"
    case EXCHANGE_TRADED_FUND = "EXCHANGE_TRADED_FUND"
    case unknown = "UNKNOWN"
}
