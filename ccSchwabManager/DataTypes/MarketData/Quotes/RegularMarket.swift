//
//

import Foundation

/**
 "regular": {
   "regularMarketLastPrice": 118.42,
   "regularMarketLastSize": 45019,
   "regularMarketNetChange": -3.25,
   "regularMarketPercentChange": -2.67115969,
   "regularMarketTradeTime": 1736553600002
 }
 */

class RegularMarket : Codable, Identifiable
{

    var regularMarketLastPrice: Double?
    var regularMarketLastSize: Int?
    var regularMarketNetChange: Double?
    var regularMarketPercentChange: Double?
    var regularMarketTradeTime: Int?

    enum CodingKeys: String, CodingKey
    {
        case regularMarketLastPrice = "regularMarketLastPrice"
        case regularMarketLastSize = "regularMarketLastSize"
        case regularMarketNetChange = "regularMarketNetChange"
        case regularMarketPercentChange = "regularMarketPercentChange"
        case regularMarketTradeTime = "regularMarketTradeTime"
    }

    init(regularMarketLastPrice: Double? = nil, regularMarketLastSize: Int? = nil, regularMarketNetChange: Double? = nil, regularMarketPercentChange: Double? = nil, regularMarketTradeTime: Int? = nil)
    {
        self.regularMarketLastPrice = regularMarketLastPrice
        self.regularMarketLastSize = regularMarketLastSize
        self.regularMarketNetChange = regularMarketNetChange
        self.regularMarketPercentChange = regularMarketPercentChange
        self.regularMarketTradeTime = regularMarketTradeTime
    }

}
