//
//

import Foundation

class QuotesResponse : Codable, Identifiable
{
    public var symbol: Symbol?
    public var fundamental: Fundamental?
    public var quote: Quote?
    public var reference: Reference?
    public var regular: RegularMarket?

    enum CodingKeys: String, CodingKey
    {
        case symbol = "symbol"
        case fundamental = "fundamental"
        case quote = "quote"
        case reference = "reference"
        case regular = "regular"
    }

    public init(symbol: Symbol? = nil, fundamental: Fundamental? = nil, quote: Quote? = nil, reference: Reference? = nil, regular: RegularMarket? = nil)
    {
        self.symbol = symbol
        self.fundamental = fundamental
        self.quote = quote
        self.reference = reference
        self.regular = regular
    }


}

