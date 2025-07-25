
import Foundation

/**
 
 Account -> Positions[] -> instrument ->type
 
 */

public enum InstrumentType: String, Codable, CaseIterable
{
    // Equity
    case COMMON_STOCK = "COMMON_STOCK"
    case PREFERRED_STOCK = "PREFERRED_STOCK"
    case DEPOSITORY_RECEIPT = "DEPOSITORY_RECEIPT"
    case RESTRICTED_STOCK = "RESTRICTED_STOCK"
    case COMPONENT_UNIT = "COMPONENT_UNIT"
    case RIGHT = "RIGHT"
    case WARRANT = "WARRANT"
    case CONVERTIBLE_PREFERRED_STOCK = "CONVERTIBLE_PREFERRED_STOCK"
    case CONVERTIBLE_STOCK = "CONVERTIBLE_STOCK"
    case LIMITED_PARTNERSHIP = "LIMITED_PARTNERSHIP"
    case WHEN_ISSUED = "WHEN_ISSUED"

    // Fixed Income
    case BOND_UNIT = "BOND_UNIT"
    case CERTIFICATE_OF_DEPOSIT = "CERTIFICATE_OF_DEPOSIT"
    case CONVERTIBLE_BOND = "CONVERTIBLE_BOND"
    case COLLATERALIZED_MORTGAGE_OBLIGATION = "COLLATERALIZED_MORTGAGE_OBLIGATION"
    case CORPORATE_BOND = "CORPORATE_BOND"
    case GOVERNMENT_MORTGAGE = "GOVERNMENT_MORTGAGE"
    case GNMA_BONDS = "GNMA_BONDS"
    case MUNICIPAL_ASSESSMENT_DISTRICT = "MUNICIPAL_ASSESSMENT_DISTRICT"
    case MUNICIPAL_BOND = "MUNICIPAL_BOND"
    case OTHER_GOVERNMENT = "OTHER_GOVERNMENT"
    case SHORT_TERM_PAPER = "SHORT_TERM_PAPER"
    case US_TREASURY_BOND = "US_TREASURY_BOND"
    case US_TREASURY_BILL = "US_TREASURY_BILL"
    case US_TREASURY_NOTE = "US_TREASURY_NOTE"
    case US_TREASURY_ZERO_COUPON = "US_TREASURY_ZERO_COUPON"
    case AGENCY_BOND = "AGENCY_BOND"
    case WHEN_AS_AND_IF_ISSUED_BOND = "WHEN_AS_AND_IF_ISSUED_BOND"
    case ASSET_BACKED_SECURITY = "ASSET_BACKED_SECURITY"

    case sweepVehicle = "SWEEP_VEHICLE"
    case savings = "SAVINGS"
    case moneyMarketFund = "MONEY_MARKET_FUND"
    // Index
    case broadBased = "BROAD_BASED"
    case narrowBased = "NARROW_BASED"
    // mutual fund
    case NOT_APPLICABLE = "NOT_APPLICABLE"
    case OPEN_END_NON_TAXABLE = "OPEN_END_NON_TAXABLE"
    case OPEN_END_TAXABLE = "OPEN_END_TAXABLE"
    case NO_LOAD_TAXABLE = "NO_LOAD_TAXABLE"
    case EXCHANGE_TRADED_FUND = "EXCHANGE_TRADED_FUND"
    case CLOSED_END_FUND = "CLOSED_END_FUND"
    // option
    case VANILLA = "VANILLA"
    case BINARY = "BINARY"
    case BARRIER = "BARRIER"
    // Forex
    // Future
    case STANDARD = "STANDARD"
    case NBBO = "NBBO"
    // Product
    case TBD = "TBD"

    case UNKNOWN = "UNKNOWN"
}
