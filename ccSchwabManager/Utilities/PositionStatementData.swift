import SwiftUI
import Foundation

/**
 * for the loading and using of the PositionStatement CSV with the position statement downloaded from the Schwab web site.
 */


struct PositionStatementData : Identifiable
{
    let id = UUID()
    var instrument : String = ""
    var quantity : Double = 0.0
    var netLiquid  : Double = 0.0
    var tradePrice : Double = 0.0
    var last  : Double = 0.0
    var atr   : Double = 0.0
    var floatingPL  : Double = 0.0
    var account  : String = ""
    var company  : String = ""
    var plPercent  : Double = 0.0
    var plOpen  : Double = 0.0
    
    init( csv : [String] )
    {
        instrument = csv[0]
        quantity = stringToDouble( content: csv[1] )
        netLiquid  =   stringToDouble( content: csv[2] )
        tradePrice  =  stringToDouble( content: csv[3] )
        last   =  stringToDouble( content: csv[4] )
        atr   =  stringToDouble( content: csv[5] )
        floatingPL  =  stringToDouble( content: csv[6] )
        account = csv[7]
        company  = csv[8]
        plPercent  =  stringToDouble( content: csv[9] )
        plOpen   =  stringToDouble( content: csv[10] )
    }
}

func stringToDouble( content: String ) -> Double
{
    let formatter = NumberFormatter()
    formatter.locale = Locale.current // USA: Locale(identifier: "en_US")
    formatter.numberStyle = .decimal
    var cleanedString : String = content.replacingOccurrences(of: "+", with: "")
        .replacingOccurrences(of: "$", with: "")
        .replacingOccurrences(of: "%", with: "")

    let pattern = "\\($*(\\d+\\.\\d+)\\)"

    if let regex = try? NSRegularExpression(pattern: pattern, options: [])
    {
        let range = NSRange(location: 0, length: cleanedString.utf16.count)
        let modifiedString = regex.stringByReplacingMatches( in: cleanedString, options: [], range: range, withTemplate: "-$1" )
        //print(modifiedString) // Output: -42.8
        cleanedString = modifiedString
    }

    let result  = formatter.number(
        from: cleanedString
    )?.doubleValue
    
    return result ?? 0.0
} // stringToDouble


