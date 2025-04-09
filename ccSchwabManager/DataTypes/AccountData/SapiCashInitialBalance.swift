import Foundation

class SapiCashInitialBalance: Codable, Identifiable
{
     var accruedInterest : Double?
     var cashAvailableForTrading : Double?
     var cashAvailableForWithdrawal : Double?
     var cashBalance : Double?
     var bondValue : Double?
     var cashReceipts : Double?
     var liquidationValue : Double?
     var longOptionMarketValue : Double?
     var longStockValue : Double?
     var moneyMarketFund : Double?
     var mutualFundValue : Double?
     var shortOptionMarketValue : Double?
     var shortStockValue : Double?
     var isInCall : Bool?
     var unsettledCash : Double?
     var cashDebitCallValue : Double?
     var pendingDeposits : Double?
     var accountValue : Double?

    func dump() -> String
    {
        var retVal : String = ""
        retVal += "accruedInterest = "
        retVal += String(accruedInterest ?? -1)
        retVal += "cashAvailableForTrading = "
        retVal += String(cashAvailableForTrading ?? -1 )
        return retVal
    }
}

