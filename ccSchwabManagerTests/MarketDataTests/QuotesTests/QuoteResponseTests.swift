import XCTest
@testable import ccSchwabManager

final class QuoteResponseTests: XCTestCase {
    
    func testQuoteResponseDecoding() throws {
        // Sample JSON that matches the expected format
        let jsonString = """
        {
          "NVDA": {
            "assetMainType": "EQUITY",
            "assetSubType": "COE",
            "quoteType": "NBBO",
            "realtime": true,
            "ssid": 382397811,
            "symbol": "NVDA",
            "extended": {
              "askPrice": 156.1,
              "askSize": 138,
              "bidPrice": 156.07,
              "bidSize": 102,
              "lastPrice": 156.09,
              "lastSize": 193,
              "mark": 156.09,
              "quoteTime": 1750912984000,
              "totalVolume": 0,
              "tradeTime": 1750912984000
            },
            "fundamental": {
              "avg10DaysVolume": 173287688,
              "avg1YearVolume": 271631279,
              "declarationDate": "2025-05-28T00:00:00Z",
              "divAmount": 0.04,
              "divExDate": "2025-06-11T00:00:00Z",
              "divFreq": 4,
              "divPayAmount": 0.01,
              "divPayDate": "2025-07-03T00:00:00Z",
              "divYield": 0.02775,
              "eps": 2.94,
              "fundLeverageFactor": 0,
              "lastEarningsDate": "2025-05-28T00:00:00Z",
              "nextDivExDate": "2025-09-11T00:00:00Z",
              "nextDivPayDate": "2025-10-03T00:00:00Z",
              "peRatio": 47.69845
            },
            "quote": {
              "52WeekHigh": 154.45,
              "52WeekLow": 86.62,
              "askMICId": "ARCX",
              "askPrice": 154.6,
              "askSize": 40,
              "askTime": 1750895995640,
              "bidMICId": "XNAS",
              "bidPrice": 154.59,
              "bidSize": 2,
              "bidTime": 1750895995639,
              "closePrice": 147.9,
              "highPrice": 154.45,
              "lastMICId": "XADF",
              "lastPrice": 154.6,
              "lastSize": 50,
              "lowPrice": 149.26,
              "mark": 154.59,
              "markChange": 6.69,
              "markPercentChange": 4.52332657,
              "netChange": 6.7,
              "netPercentChange": 4.5300879,
              "openPrice": 149.27,
              "postMarketChange": 0.29,
              "postMarketPercentChange": 0.18793338,
              "quoteTime": 1750895995640,
              "securityStatus": "Normal",
              "totalVolume": 269146471,
              "tradeTime": 1750895998642
            },
            "reference": {
              "cusip": "67066G104",
              "description": "NVIDIA CORP",
              "exchange": "Q",
              "exchangeName": "NASDAQ",
              "isHardToBorrow": false,
              "isShortable": true,
              "htbRate": 0
            },
            "regular": {
              "regularMarketLastPrice": 154.31,
              "regularMarketLastSize": 13300429,
              "regularMarketNetChange": 6.41,
              "regularMarketPercentChange": 4.33400947,
              "regularMarketTradeTime": 1750881600025
            }
          }
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        do {
            let quoteResponse = try decoder.decode(QuoteResponse.self, from: jsonData)
            
            // Verify the response contains the expected symbol
            XCTAssertTrue(quoteResponse.quotes.keys.contains("NVDA"))
            
            // Get the quote data for NVDA
            guard let nvdaQuote = quoteResponse.quotes["NVDA"] else {
                XCTFail("NVDA quote data not found")
                return
            }
            
            // Verify basic fields
            XCTAssertEqual(nvdaQuote.symbol, "NVDA")
            XCTAssertEqual(nvdaQuote.assetMainType, "EQUITY")
            XCTAssertEqual(nvdaQuote.assetSubType, "COE")
            XCTAssertTrue(nvdaQuote.realtime ?? false)
            
            // Verify fundamental data
            XCTAssertNotNil(nvdaQuote.fundamental)
            XCTAssertEqual(nvdaQuote.fundamental?.divYield, 0.02775)
            XCTAssertEqual(nvdaQuote.fundamental?.divAmount, 0.04)
            XCTAssertEqual(nvdaQuote.fundamental?.eps, 2.94)
            XCTAssertEqual(nvdaQuote.fundamental?.peRatio, 47.69845)
            
            // Verify quote data
            XCTAssertNotNil(nvdaQuote.quote)
            XCTAssertEqual(nvdaQuote.quote?.lastPrice, 154.6)
            XCTAssertEqual(nvdaQuote.quote?.closePrice, 147.9)
            
            // Verify reference data
            XCTAssertNotNil(nvdaQuote.reference)
            XCTAssertEqual(nvdaQuote.reference?.description, "NVIDIA CORP")
            XCTAssertEqual(nvdaQuote.reference?.exchange, "Q")
            XCTAssertEqual(nvdaQuote.reference?.exchangeName, "NASDAQ")
            
        } catch {
            XCTFail("Failed to decode QuoteResponse: \(error)")
        }
    }
    
    func testDividendYieldFormatting() {
        // Test the dividend yield formatting logic
        let divYield = 0.02775
        
        // Format as percentage (multiply by 100 and format to 2 decimal places)
        let formattedYield = String(format: "%.2f%%", round( divYield * 10000.0 ) / 100.0 )
        
        XCTAssertEqual(formattedYield, "2.78%")
    }
} 
