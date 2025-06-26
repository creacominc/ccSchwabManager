//
//

import Foundation

// New structure to match the JSON response format
struct QuoteResponse: Codable {
    let quotes: [String: QuoteData]
    
    init(from decoder: Decoder) throws {
        // The JSON has the symbol as the root key, so we decode the entire object as a dictionary
        let container = try decoder.singleValueContainer()
        quotes = try container.decode([String: QuoteData].self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(quotes)
    }
}

struct QuoteData: Codable {
    let assetMainType: String?
    let assetSubType: String?
    let quoteType: String?
    let realtime: Bool?
    let ssid: Int64?
    let symbol: String?
    let extended: ExtendedMarket?
    let fundamental: Fundamental?
    let quote: Quote?
    let reference: Reference?
    let regular: RegularMarket?
}
