import SwiftUI


class SapiAccountsInstrument : Codable
{
    // Instrument
    var assetType : SapiAccountInstrumentAssetType?
    var cusip: String?
    var symbol: String?
    var description: String?
    var instrumentId: Int64?
    // Equity
    // Mutual Fund
    var netChange: Double?
    // cash equiv
    var type: SapiAccountCashEquivilantType?
    // FixedIncome
    var maturityDate: String?
    var factor: Double?
    var variableRate: Double?
    // Option
    //var optionDeliverables: [SapiAccountAPIOptionDeliverable]?
    var putCall: SapiPutCallType?
    var optionMultiplier: Int32?
    //var type: SapiAccountOptionType?
    var underlyingSymbol: String?



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

