// base class for

import Foundation


class SapiAccountContent: Codable, Identifiable
{
    var securitiesAccount: SapiAccount
    var aggregatedBalance: SapiAggregatedBalance
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
        var result: String = ""
        result += "type="  
        result += (type?.rawValue ?? "no type")  + ", "
        result += " account=" 
        result += accountNumber.map({String($0)}) ?? "no account number" + ", "
        result += " round=" 
        result += roundTrips.map({String($0)}) ?? "no round trips" + ", "
        result += " day="  
        result += isDayTrader.map({String($0)}) ?? "no isDayTrader" + ", "
        result += " restricted="  
        result += isClosingOnlyRestricted.map({String($0)}) ?? "no isClosingOnlyRestricted" + ", "
        result += " pfcbFlag="  
        result += pfcbFlag.map({String($0)}) ?? "no pfcbFlag" + "\n"
        result += "\t positions: \(positions.count)\n"
        for position in positions
        {
            result += "\t\t"
            result += "position="  
            result += position?.dump() ?? NOTAVAILABLE
        }
        result += "\n\t initialBalances = "
        result += initialBalances?.dump() ?? "no initial balance"
        result += "\n\t currentBalances = "
        result += currentBalances?.dump() ?? "no current balance"
        result += "\n\t projectedBalances = "
        result += projectedBalances?.dump() ?? "no projected balance"
        return result
    }
    
}

import SwiftUI

#Preview
{
    
    struct TestView: View
    {
        var body: some View
        {
            var account: SapiAccount = getTestAccount()
            VStack
            {
                Text( "Account Number: \(account.accountNumber ?? NOTAVAILABLE)"  )
                Text( "positions: \((account.positions).count)" )
                let count = account.positions.count

                 List
                 {
                    Grid
                    {
                        GridRow
                        {
                            Text("Instrument")
                            Text("Qty")
                            Text("Net Liq")
                            Text("Trade Price(*)")
                            Text("Last")
                            Text("ATR(*)")
                            Text("HT_FPL(*)")
                            Text("Account Name(*)")
                            Text("Company Name(*)")
                            Text("P/L %")
                            Text("P/L Open")
                         }
                         .bold()
                         Divider()

                        let accountNumber : String = account.accountNumber ?? NOTAVAILABLE
                        let accountName : String = "****\( accountNumber.suffix(3) )"

                        ForEach(0..<count)
                        { indx in
                            let instrument : String = ( account.positions[indx]?.instrument?.symbol ?? NOTAVAILABLE )
                            let qty : Double = ( ( account.positions[indx]?.longQuantity ?? 0 )
                                                 + ( account.positions[indx]?.shortQuantity ?? 0 ) )
                            let netLiq : Double = (  account.positions[indx]?.marketValue ?? -1 )
                             // using Average for Trade Price - TBD
                            let tradePrice : Double = ( account.positions[indx]?.averagePrice ?? -1 )
                            let lastPrice : Double = (  netLiq / qty ) 
                            let atr : Double = -1.42 // TBD
                            let htFpl : Double = -1.42 // TBD
                            let companyName : String = instrument //TBD
                            let profitLoss : Double = ((  account.positions[indx]?.longOpenProfitLoss ?? 0 ) + (  account.positions[indx]?.shortOpenProfitLoss ?? 0 ))
                            let plPercent : Double = profitLoss / netLiq * 100

                            GridRow
                            {
                                Text( instrument )
                                Text( String( format: "%.4f", qty ) )
                                Text( String( format: "%.2f", netLiq ) )
                                Text( String( format: "%.2f", tradePrice ) )
                                Text( String( format: "%.2f", lastPrice ) )
                                Text( String( format: "%.2f", atr ) )
                                Text( String( format: "%.2f", htFpl ) )
                                Text( accountName )
                                Text( companyName )
                                Text( String( format: "%.1f", plPercent ) )
                                Text( String( format: "%.2f", profitLoss ) )
                            }
                        }

                        
                    }
                 }
            }
            .scrollDisabled(false)
        }

        func getTestAccount() -> SapiAccount
        {
            if let url = Bundle.main.url(forResource: "testdata", withExtension: "json")
            {
                do
                {
                    let data = try Data(contentsOf: url)
                    let decoder = JSONDecoder()
                    let content : [SapiAccountContent] = try decoder.decode([SapiAccountContent].self, from: data)
                    print( "Accounts[0]: \( content[0].securitiesAccount.dump()  )" )
                    return ( content[0].securitiesAccount )
                }
                catch
                {
                    print("error:\(error)")
                }
            }
            else
            {
                print( "error getting file" )
            }
            return SapiAccount()
        }


    }
    return TestView()
    
}
