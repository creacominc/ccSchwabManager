//
//

import Foundation


/**
 "fundamental": {
   "avg10DaysVolume": 585643,
   "avg1YearVolume": 1057134,
   "declarationDate": "2024-12-03T05:00:00Z",
   "divAmount": 4.11852,
   "divExDate": "2025-01-27T05:00:00Z",
   "divFreq": 4,
   "divPayAmount": 1.02858,
   "divPayDate": "2025-02-24T05:00:00Z",
   "divYield": 3.38499,
   "eps": 8.07986,
   "fundLeverageFactor": 0,
   "lastEarningsDate": "2024-12-04T05:00:00Z",
   "nextDivExDate": "2025-04-28T04:00:00Z",
   "nextDivPayDate": "2025-05-27T04:00:00Z",
   "peRatio": 15.05843
 }
 */


class Fundamental : Codable, Identifiable
{
    public var avg10DaysVolume: Double?
    public var avg1YearVolume: Double?
    public var declarationDate: String?
    public var divAmount: Double?
    public var divExDate: String?
    /**
     Dividend frequency 1 – once a year or annually 2 – 2x a year or semi-annualy 3 - 3x a year (ex. ARCO, EBRPF) 4 – 4x a year or quarterly 6 - 6x per yr or every other month 11 – 11x a year (ex. FBND, FCOR) 12 – 12x a year or monthly
     */
    public var divFreq: Int?
    public var divPayAmount: Double?
    public var divPayDate: String?
    public var divYield: Double?
    public var eps: Double?
    public var fundLeverageFactor: Double?
    public var lastEarningsDate: String?
    public var nextDivExDate: String?
    public var nextDivPayDate: String?
    public var peRatio: Double?
    
    enum CodingKeys : String, CodingKey
    {
        case avg10DaysVolume = "avg10DaysVolume"
        case avg1YearVolume = "avg1YearVolume"
        case declarationDate = "declarationDate"
        case divAmount = "divAmount"
        case divExDate = "divExDate"
        case divFreq = "divFreq"
        case divPayAmount = "divPayAmount"
        case divPayDate = "divPayDate"
        case divYield = "divYield"
        case eps = "eps"
        case fundLeverageFactor = "fundLeverageFactor"
        case lastEarningsDate = "lastEarningsDate"
        case nextDivExDate = "nextDivExDate"
        case nextDivPayDate = "nextDivPayDate"
        case peRatio = "peRatio"
    }

    public init(avg10DaysVolume: Double? = nil, avg1YearVolume: Double? = nil, declarationDate: String? = nil, divAmount: Double? = nil, divExDate: String? = nil, divFreq: Int? = nil, divPayAmount: Double? = nil, divPayDate: String? = nil, divYield: Double? = nil, eps: Double? = nil, fundLeverageFactor: Double? = nil, lastEarningsDate: String? = nil, nextDivExDate: String? = nil, nextDivPayDate: String? = nil, peRatio: Double? = nil)
    {
        self.avg10DaysVolume = avg10DaysVolume
        self.avg1YearVolume = avg1YearVolume
        self.declarationDate = declarationDate
        self.divAmount = divAmount
        self.divExDate = divExDate
        self.divFreq = divFreq
        self.divPayAmount = divPayAmount
        self.divPayDate = divPayDate
        self.divYield = divYield
        self.eps = eps
        self.fundLeverageFactor = fundLeverageFactor
        self.lastEarningsDate = lastEarningsDate
        self.nextDivExDate = nextDivExDate
        self.nextDivPayDate = nextDivPayDate
        self.peRatio = peRatio
    }

    
    
}

