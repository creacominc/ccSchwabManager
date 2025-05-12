/**
 * Position
 *
 */

import Foundation


class Position: NSObject, Codable, Identifiable, Comparable
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

    override init()
    {
        super.init()
    }

    init(shortQuantity: Double? = nil, averagePrice: Double? = nil, currentDayProfitLoss: Double? = nil, currentDayProfitLossPercentage: Double? = nil, longQuantity: Double? = nil, settledLongQuantity: Double? = nil, settledShortQuantity: Double? = nil, agedQuantity: Double? = nil, instrument: Instrument? = nil, marketValue: Double? = nil, maintenanceRequirement: Double? = nil, averageLongPrice: Double? = nil, averageShortPrice: Double? = nil, taxLotAverageLongPrice: Double? = nil, taxLotAverageShortPrice: Double? = nil, longOpenProfitLoss: Double? = nil, shortOpenProfitLoss: Double? = nil, previousSessionLongQuantity: Double? = nil, previousSessionShortQuantity: Double? = nil, currentDayCost: Double? = nil)
    {
        super.init()
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

    required init(from decoder: Decoder) throws {
        super.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortQuantity = try container.decodeIfPresent(Double.self, forKey: .shortQuantity)
        averagePrice = try container.decodeIfPresent(Double.self, forKey: .averagePrice)
        currentDayProfitLoss = try container.decodeIfPresent(Double.self, forKey: .currentDayProfitLoss)
        currentDayProfitLossPercentage = try container.decodeIfPresent(Double.self, forKey: .currentDayProfitLossPercentage)
        longQuantity = try container.decodeIfPresent(Double.self, forKey: .longQuantity)
        settledLongQuantity = try container.decodeIfPresent(Double.self, forKey: .settledLongQuantity)
        settledShortQuantity = try container.decodeIfPresent(Double.self, forKey: .settledShortQuantity)
        agedQuantity = try container.decodeIfPresent(Double.self, forKey: .agedQuantity)
        instrument = try container.decodeIfPresent(Instrument.self, forKey: .instrument)
        marketValue = try container.decodeIfPresent(Double.self, forKey: .marketValue)
        maintenanceRequirement = try container.decodeIfPresent(Double.self, forKey: .maintenanceRequirement)
        averageLongPrice = try container.decodeIfPresent(Double.self, forKey: .averageLongPrice)
        averageShortPrice = try container.decodeIfPresent(Double.self, forKey: .averageShortPrice)
        taxLotAverageLongPrice = try container.decodeIfPresent(Double.self, forKey: .taxLotAverageLongPrice)
        taxLotAverageShortPrice = try container.decodeIfPresent(Double.self, forKey: .taxLotAverageShortPrice)
        longOpenProfitLoss = try container.decodeIfPresent(Double.self, forKey: .longOpenProfitLoss)
        shortOpenProfitLoss = try container.decodeIfPresent(Double.self, forKey: .shortOpenProfitLoss)
        previousSessionLongQuantity = try container.decodeIfPresent(Double.self, forKey: .previousSessionLongQuantity)
        previousSessionShortQuantity = try container.decodeIfPresent(Double.self, forKey: .previousSessionShortQuantity)
        currentDayCost = try container.decodeIfPresent(Double.self, forKey: .currentDayCost)
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

    static func < (lhs: Position, rhs: Position) -> Bool {
        return (lhs.instrument?.symbol ?? "") < (rhs.instrument?.symbol ?? "")
    }
    
    static func == (lhs: Position, rhs: Position) -> Bool {
        return lhs.instrument?.symbol == rhs.instrument?.symbol
    }
}


