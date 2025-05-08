//
//

import Foundation

class Symbol : Codable, Identifiable
{
    public var assetType: AssetType?
    public var assetSubType: EquityAssetSubType?
    public var quoteType: QuoteType?
    public var realtime: Bool?
    public var ssid: Int?
    public var symbol: String?
    public var extended: ExtendedMarket?
    
    enum CodingKeys: String, CodingKey
    {
        case assetType = "assetType"
        case assetSubType = "assetSubType"
        case quoteType = "quoteType"
        case realtime = "realtime"
        case ssid = "ssid"
        case symbol = "symbol"
        case extended = "extended"
    }
    
    public init(assetType: AssetType? = nil, assetSubType: EquityAssetSubType? = nil, quoteType: QuoteType? = nil, realtime: Bool? = nil, ssid: Int? = nil, symbol: String? = nil, extended: ExtendedMarket? = nil)
    {
        self.assetType = assetType
        self.assetSubType = assetSubType
        self.quoteType = quoteType
        self.realtime = realtime
        self.ssid = ssid
        self.symbol = symbol
        self.extended = extended
    }
    
}



