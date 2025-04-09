

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
        var retVal : String = "Position:  "
        retVal += "\n\t\t\t shortQuantity: \(shortQuantity ?? Double(NOTAVAILABLENUMBER)), averagePrice: \(averagePrice ?? Double(NOTAVAILABLENUMBER)), currentDayProfitLoss: \(currentDayProfitLoss ?? Double(NOTAVAILABLENUMBER)), currentDayProfitLossPercentage: \(currentDayProfitLossPercentage ?? Double(NOTAVAILABLENUMBER)), longQuantity: \(longQuantity ?? Double(NOTAVAILABLENUMBER)), settledLongQuantity: \(settledLongQuantity ?? Double(NOTAVAILABLENUMBER)), settledShortQuantity: \(settledShortQuantity ?? Double(NOTAVAILABLENUMBER))\n"
        retVal += "\t\t\t Instrument: "
        retVal += instrument?.dump() ?? NOTAVAILABLE
        return retVal
    }

}


