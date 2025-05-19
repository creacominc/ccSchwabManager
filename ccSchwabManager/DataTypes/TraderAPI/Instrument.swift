import Foundation

/**
 
 account -> positions[] -> instrument
 and
  transaction -> transferItems[] -> instrument
 
   Instruments can look like any of the following (and others to come):
 
 EQUITY
 {"assetType":"EQUITY","cusip":"910873405","symbol":"UMC","netChange":0.29}
    
 OPTION
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 expirationDate    string($date-time)
 optionDeliverables    [SapiTransactionAPIOptionDeliverable]
 optionPremiumMultiplier    integer($int64)
 putCall    SapiPutCallType
 strikePrice    number($double)
 type    SapiAccountOptionType
 underlyingSymbol    string
 underlyingCusip    string
 deliverable    { }

 {"assetType":"OPTION","cusip":"0INTC.EG50024500","symbol":"INTC  250516C00024500","description":"INTEL CORP 05/16/2025 $24.5 Call","netChange":-0.0046,"type":"VANILLA","putCall":"CALL","underlyingSymbol":"INTC"}

 INDEX
 activeContract    boolean default: false
 type    InstrumentType

    
 MUTUAL_FUND
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 fundFamilyName    string
 fundFamilySymbol    string
 fundGroup    string
 type    InstrumentType
 exchangeCutoffTime    string($date-time)
 purchaseCutoffTime    string($date-time)
 redemptionCutoffTime    string($date-time)

 {"assetType":"MUTUAL_FUND","cusip":"921926101","symbol":"VEXPX","description":"Vanguard Explorer Inv","netChange":2.29,"type":"NO_LOAD_TAXABLE"}
    
 CASH_EQUIVALENT
 assetType*    AssetType
  cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    SapiTransactionCashEquivalentType
    
 FIXED_INCOME
  assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    InstrumentType
 maturityDate    string($date-time)
 factor    number($double)
 multiplier    number($double)
 variableRate    number($double)

 {"assetType":"FIXED_INCOME","cusip":"06418C5P7","symbol":"06418C5P7","description":"Bank OZK AR 3.9% CD 11/21/2025","maturityDate":"2025-11-21T05:00:00.000+00:00","variableRate":3.9}
    
 CURRENCY
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
    
 COLLECTIVE_INVESTMENT
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    SapiAccountCashEquivilantType

 {"assetType":"COLLECTIVE_INVESTMENT","cusip":"92189F106","symbol":"GDX","description":"VanEck Gold Miners ETF","type":"EXCHANGE_TRADED_FUND"}

 FUTURE
 activeContract    boolean  default: false
 type    InstrumentType
 expirationDate    string($date-time)
 lastTradingDate    string($date-time)
 firstNoticeDate    string($date-time)
 multiplier    number($double)

 FOREX
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type    InstrumentType
 baseCurrency    SapiCurrency
 counterCurrency    SapiCurrency

 PRODUCT
 assetType*    AssetType
 cusip    string
 symbol    string
 description    string
 instrumentId    integer($int64)
 netChange    number($double)
 type   InstrumentType

 */

class Instrument : Codable, Identifiable
{
    public enum Status: String, Codable, CaseIterable
    {
        case ACTIVE = "ACTIVE"
        case INACTIVE = "INACTIVE"
        case DISABLED = "DISABLED"
    }

    // Instrument
    var assetType : AssetType?
    var cusip: String?
    var symbol: String?
    var description: String?
    var instrumentId: Int64?
    // Equity
    var status: Status?
    var closingPrice: Double?
    // Mutual Fund
    var netChange: Double?
    var fundFamilyName: String?
    var fundFamilySymbol: String?
    var fundGroup: String?
    var exchange: String?
    var exchangeCutoffTime: String?
    var purchaseCutoffTime: String?
    var redemptionCutoffTime: String?
    // cash equiv
    var type: InstrumentType?
    // FixedIncome
    var maturityDate: String?
    var factor: Double?
    var multiplier: Double?
    var variableRate: Double?
    // Option
    var optionDeliverables: [TransactionAPIOptionDeliverable]?
    var optionPremiumMultiplier: Int64?
    var putCall: PutCallType?
    var optionMultiplier: Int32?
    var underlyingSymbol: String?
    var underlyingCusip: String?
    var strikePrice: Double?
    // Forex
//    var baseCurrency: Currency?
//    var counterCurrency: Currency?
    // Future
    // Index
    var activeContract: Bool?
    var expirationDate: String?
    var lastTradingDate: String?
    var firstNoticeDate: String?

    public init(assetType: AssetType? = nil, cusip: String? = nil,
                symbol: String? = nil, description: String? = nil,
                instrumentId: Int64? = nil,
                status: Status? = nil, closingPrice: Double? = nil,
                netChange: Double? = nil, fundFamilyName: String? = nil,
                fundFamilySymbol: String? = nil, fundGroup: String? = nil,
                exchange: String? = nil,
                exchangeCutoffTime: String? = nil,
                purchaseCutoffTime: String? = nil,
                redemptionCutoffTime: String? = nil,
                type: InstrumentType? = nil, maturityDate: String? = nil,
                factor: Double? = nil, multiplier: Double? = nil,
                variableRate: Double? = nil,
                optionDeliverables: [TransactionAPIOptionDeliverable]? = nil,
                optionPremiumMultiplier: Int64? = nil,
                putCall: PutCallType? = nil, optionMultiplier: Int32? = nil,
                underlyingSymbol: String? = nil, underlyingCusip: String? = nil,
                strikePrice: Double? = nil, activeContract: Bool? = nil,
                expirationDate: String? = nil, lastTradingDate: String? = nil,
                firstNoticeDate: String? = nil)
    {
        self.assetType = assetType
        self.cusip = cusip
        self.symbol = symbol
        self.description = description
        self.instrumentId = instrumentId
        self.status = status
        self.closingPrice = closingPrice
        self.netChange = netChange
        self.fundFamilyName = fundFamilyName
        self.fundFamilySymbol = fundFamilySymbol
        self.fundGroup = fundGroup
        self.exchange = exchange
        self.exchangeCutoffTime = exchangeCutoffTime
        self.purchaseCutoffTime = purchaseCutoffTime
        self.redemptionCutoffTime = redemptionCutoffTime
        self.type = type
        self.maturityDate = maturityDate
        self.factor = factor
        self.multiplier = multiplier
        self.variableRate = variableRate
        self.optionDeliverables = optionDeliverables
        self.optionPremiumMultiplier = optionPremiumMultiplier
        self.putCall = putCall
        self.optionMultiplier = optionMultiplier
        self.underlyingSymbol = underlyingSymbol
        self.underlyingCusip = underlyingCusip
        self.strikePrice = strikePrice
        self.activeContract = activeContract
        self.expirationDate = expirationDate
        self.lastTradingDate = lastTradingDate
        self.firstNoticeDate = firstNoticeDate
    }

    enum codingKeys : String, CodingKey
    {
        case assetType = "assetType"
        case cusip = "cusip"
        case symbol = "symbol"
        case description = "description"
        case instrumentId = "instrumentId"
        case status = "status"
        case closingPrice = "closingPrice"
        case netChange = "netChange"
        case fundFamilyName = "fundFamilyName"
        case fundFamilySymbol = "fundFamilySymbol"
        case fundGroup = "fundGroup"
        case exchange = "exchange"
        case exchangeCutoffTime = "exchangeCutoffTime"
        case purchaseCutoffTime = "purchaseCutoffTime"
        case redemptionCutoffTime = "redemptionCutoffTime"
        case type = "type"
        case maturityDate = "maturityDate"
        case factor = "factor"
        case multiplier = "multiplier"
        case optionDeliverables = "optionDeliverables"
        case optionPremiumMultiplier = "optionPremiumMultiplier"
        case putCall = "putCall"
        case optionMultiplier = "optionMultiplier"
        case underlyingSymbol = "underlyingSymbol"
        case underlyingCusip = "underlyingCusip"
        case strikePrice = "strikePrice"
        case activeContract = "activeContract"
        case expirationDate = "expirationDate"
        case lastTradingDate = "lastTradingDate"
        case firstNoticeDate = "firstNoticeDate"
    }


    func dump() -> String
    {
        var retVal : String = "Instrument: "
        retVal += "assetType="
        retVal += assetType?.rawValue ?? NOTAVAILABLE
        retVal += ", cusip="
        retVal += cusip ?? NOTAVAILABLE
        retVal += ", symbol="
        retVal += symbol ?? NOTAVAILABLE
        retVal += ", description="
        retVal += description ?? NOTAVAILABLE
        retVal += ", instrumentId="
        retVal += "\(instrumentId ?? Int64(NOTAVAILABLENUMBER))"
        retVal += ", netChange="
        retVal += "\(netChange ?? Double(NOTAVAILABLENUMBER))"
        retVal += ", maturityDate="
        retVal += maturityDate ?? NOTAVAILABLE
        retVal += ", factor="
        retVal += "\(factor ?? Double(NOTAVAILABLENUMBER))"
        retVal += ", variableRate="
        retVal += "\(variableRate ?? Double(NOTAVAILABLENUMBER))"

        return retVal
    }    
}

