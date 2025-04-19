

import Foundation


class SapiPositionContent: Codable, Identifiable
{
    var positions: SapiPosition
}


class SapiPosition: Codable, Identifiable
{
    var shortQuantity                   : Double?
    var averagePrice                    : Double?
    var currentDayProfitLoss            : Double?
    var currentDayProfitLossPercentage  : Double?
    var longQuantity                    : Double?
    var settledLongQuantity             : Double?
    var settledShortQuantity            : Double?
    var agedQuantity                    : Double?
    var instrument                      : SapiAccountsInstrument?
    var marketValue                     : Double?
    var maintenanceRequirement          : Double?
    var averageLongPrice                : Double?
    var averageShortPrice               : Double?
    var taxLotAverageLongPrice          : Double?
    var taxLotAverageShortPrice         : Double?
    var longOpenProfitLoss              : Double?
    var shortOpenProfitLoss             : Double?
    var previousSessionLongQuantity     : Double?
    var previousSessionShortQuantity    : Double?
    var currentDayCost                  : Double?

    func dump() -> String
    {
//        var retVal : String = "\n\t\t\t\t shortQuantity: \(shortQuantity ?? Double(NOTAVAILABLENUMBER)), averagePrice: \(averagePrice ?? Double(NOTAVAILABLENUMBER)), currentDayProfitLoss: \(currentDayProfitLoss ?? Double(NOTAVAILABLENUMBER)), currentDayProfitLossPercentage: \(currentDayProfitLossPercentage ?? Double(NOTAVAILABLENUMBER)), longQuantity: \(longQuantity ?? Double(NOTAVAILABLENUMBER)), settledLongQuantity: \(settledLongQuantity ?? Double(NOTAVAILABLENUMBER)), settledShortQuantity: \(settledShortQuantity ?? Double(NOTAVAILABLENUMBER))"
//        retVal += "\n\t\t\t"
//        retVal += instrument?.dump() ?? NOTAVAILABLE

        // Instrument,Qty,Net Liq,Trade Price,Last,ATR,HT_FPL,Account Name,Company Name,P/L %,P/L Open
        var retVal : String = ""
        retVal += "\(instrument?.symbol ?? "UNSET")"
        retVal += ", \(longQuantity ?? 0.0)"
        retVal += ", \(marketValue ?? 0.0)"
        retVal += ", \(averageLongPrice ?? 0.0 )"
        retVal += ", LAST"
        retVal += ", ATR"
        retVal += ", FPL"
        retVal += ", ACCOUNT"
        retVal += ", \(instrument?.description ?? "N/A")"
        retVal += ", \((longOpenProfitLoss ?? 0.0) / (longQuantity ?? 1))"
        retVal += ", \(longOpenProfitLoss ?? 0.0)"

        return retVal
    }

}


