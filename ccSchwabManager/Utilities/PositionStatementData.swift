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


//func parseCSV(url: URL?) -> [PositionStatementData] 
//{
//    do {
//        // print( "Loading \(url!.path())" )
//        let content = try String( contentsOf: url!, encoding: String.Encoding.utf8 )
//        let rows = content.components(separatedBy: "\n")
//        var positionStatementData : [PositionStatementData] = []
//        // print( "row count: \(rows.count)" )
//        for row in rows
//        {
//            /**
//             * The row may contain quoted curency values with commas which we cannot split on.  remove them first.
//             *  If we first split the row on double-quotes, numbering from 0, every odd-numbered row was a quoted string.
//             *  Remove the commas from the odd-numbered rows.
//             */
//            let splitForQuotes = row.components(separatedBy: "\"")
//            var reconstitutedRow : String = ""
//            var indx : Int = 0
//            for element in splitForQuotes
//            {
//                if( indx % 2 != 0 )
//                {
//                    reconstitutedRow += element.replacingOccurrences(of: ",", with: "")
//                }
//                else
//                {
//                    reconstitutedRow += element
//                }
//                indx += 1
//            }
//
//            let values : [String] = reconstitutedRow.components(separatedBy: ",")
//            if( ( PositionStatementColumns.allCases.count == values.count ) && ( PositionStatementColumns.Instrument.rawValue != values[0] ) )
//            {
//                // print( "creating row \(values)" )
//                let dataRow : PositionStatementData = PositionStatementData( csv: values )
//                positionStatementData.append( dataRow )
//                //print( "Appended row \(dataRow)" )
//            }
//        }
//        return positionStatementData
//    } catch {
//        print("Error reading CSV file: \(error)")
//        return []
//    }
//}

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


