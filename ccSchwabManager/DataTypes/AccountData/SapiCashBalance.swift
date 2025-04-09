import Foundation

class SapiCashBalance: Codable, Identifiable
{

        var cashAvailableForTrading : Double?
        var cashAvailableForWithdrawal : Double?
        var cashCall : Double?
        var longNonMarginableMarketValue : Double?
        var totalCash : Double?
        var cashDebitCallValue : Double?
        var unsettledCash : Double?

    func dump() -> String
    {
        var retVal : String = ""
        retVal += "\n\t cashAvailableForTrading = "
        retVal += String( cashAvailableForTrading ?? -1 )
        return retVal
    }
}

