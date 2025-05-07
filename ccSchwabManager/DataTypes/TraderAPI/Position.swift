

import Foundation


class Position: Codable, Identifiable
{
    var shortQuantity                   : Double?
    var averagePrice                    : Double?
    var currentDayProfitLoss            : Double?
    var currentDayProfitLossPercentage  : Double?
    var longQuantity                    : Double?
    var settledLongQuantity             : Double?
    var settledShortQuantity            : Double?
    var agedQuantity                    : Double?
    var instrument                      : Instrument?
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

    enum CodingKeys : String, CodingKey
    {
        case shortQuantity                   = "shortQuantity"
        case averagePrice                    = "averagePrice"
        case currentDayProfitLoss            = "currentDayProfitLoss"
        case currentDayProfitLossPercentage  = "currentDayProfitLossPercentage"
        case longQuantity                    = "longQuantity"
        case settledLongQuantity             = "settledLongQuantity"
        case settledShortQuantity            = "settledShortQuantity"
        case agedQuantity                    = "agedQuantity"
        case instrument                      = "instrument"
        case marketValue                     = "marketValue"
        case maintenanceRequirement          = "maintenanceRequirement"
        case averageLongPrice                = "averageLongPrice"
        case averageShortPrice               = "averageShortPrice"
        case taxLotAverageLongPrice          = "taxLotAverageLongPrice"
        case taxLotAverageShortPrice         = "taxLotAverageShortPrice"
        case longOpenProfitLoss              = "longOpenProfitLoss"
        case shortOpenProfitLoss             = "shortOpenProfitLoss"
        case previousSessionLongQuantity     = "previousSessionLongQuantity"
        case previousSessionShortQuantity    = "previousSessionShortQuantity"
        case currentDayCost                  = "currentDayCost"
    }

    init(shortQuantity: Double? = nil, averagePrice: Double? = nil, currentDayProfitLoss: Double? = nil, currentDayProfitLossPercentage: Double? = nil, longQuantity: Double? = nil, settledLongQuantity: Double? = nil, settledShortQuantity: Double? = nil, agedQuantity: Double? = nil, instrument: Instrument? = nil, marketValue: Double? = nil, maintenanceRequirement: Double? = nil, averageLongPrice: Double? = nil, averageShortPrice: Double? = nil, taxLotAverageLongPrice: Double? = nil, taxLotAverageShortPrice: Double? = nil, longOpenProfitLoss: Double? = nil, shortOpenProfitLoss: Double? = nil, previousSessionLongQuantity: Double? = nil, previousSessionShortQuantity: Double? = nil, currentDayCost: Double? = nil)
    {
        self.shortQuantity = shortQuantity
        self.averagePrice = averagePrice
        self.currentDayProfitLoss = currentDayProfitLoss
        self.currentDayProfitLossPercentage = currentDayProfitLossPercentage
        self.longQuantity = longQuantity
        self.settledLongQuantity = settledLongQuantity
        self.settledShortQuantity = settledShortQuantity
        self.agedQuantity = agedQuantity
        self.instrument = instrument
        self.marketValue = marketValue
        self.maintenanceRequirement = maintenanceRequirement
        self.averageLongPrice = averageLongPrice
        self.averageShortPrice = averageShortPrice
        self.taxLotAverageLongPrice = taxLotAverageLongPrice
        self.taxLotAverageShortPrice = taxLotAverageShortPrice
        self.longOpenProfitLoss = longOpenProfitLoss
        self.shortOpenProfitLoss = shortOpenProfitLoss
        self.previousSessionLongQuantity = previousSessionLongQuantity
        self.previousSessionShortQuantity = previousSessionShortQuantity
        self.currentDayCost = currentDayCost
    }


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


