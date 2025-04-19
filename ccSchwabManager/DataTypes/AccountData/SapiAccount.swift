// base class for

import Foundation


class SapiAccountContent: Codable, Identifiable
{
    var securitiesAccount: SapiAccount
    var aggregatedBalance: SapiAggregatedBalance

    public func dump() -> String
    {
        var result: String = ""
        result += "\t securitiesAccount: " + securitiesAccount.dump()
        result += "\n"
        result += "\t aggregatedBalance: " + aggregatedBalance.dump()
        return result
    }

}

let NOTAVAILABLE : String = "Not Available"
let NOTAVAILABLENUMBER : Int = -1

class SapiAccount: Codable, Identifiable
{
    var type                    : SapiSecuritiesAccountTypes?
    var accountNumber           : String?
    var roundTrips              : Int32?
    var isDayTrader             : Bool?
    var isClosingOnlyRestricted : Bool?
    var pfcbFlag                : Bool?
    var positions               : [SapiPosition?]  =  []
    var initialBalances         : SapiCashInitialBalance?
    var currentBalances         : SapiCashInitialBalance?
    var projectedBalances       : SapiCashBalance?

    func dump() -> String
    {
        var result: String = "\n"
        result += "\t\t type="
        result += (type?.rawValue ?? "no type")  + ", "
        result += "\t\t  account="
        result += accountNumber.map({String($0)}) ?? "no account number" + ", "
        result += "\t\t  round="
        result += roundTrips.map({String($0)}) ?? "no round trips" + ", "
        result += "\t\t  day="
        result += isDayTrader.map({String($0)}) ?? "no isDayTrader" + ", "
        result += "\t\t  restricted="
        result += isClosingOnlyRestricted.map({String($0)}) ?? "no isClosingOnlyRestricted" + ", "
        result += "\t\t  pfcbFlag="
        result += pfcbFlag.map({String($0)}) ?? "no pfcbFlag" + "\n"
        result += "\t\t  positions: \(positions.count)\n"
        for position in positions
        {
            result += "\n\t\t"
            result += "Position: "
            result += position?.dump() ?? NOTAVAILABLE
        }
        result += "\n\t\t initialBalances = "
        result += initialBalances?.dump() ?? "no initial balance"
        result += "\n\t\t currentBalances = "
        result += currentBalances?.dump() ?? "no current balance"
        result += "\n\t\t projectedBalances = "
        result += projectedBalances?.dump() ?? "no projected balance"
        return result
    }
    
}
