//
//

import Testing
import Foundation
@testable import ccSchwabManager


/**
 
 *
 *     "transferItems": [
 *     {
 *         "instrument": {
 *             "assetType": "EQUITY",
 *             "status": "ACTIVE",
 *             "symbol": "SFM",
 *             "instrumentId": 1806651,
 *             "closingPrice": 169.76,
 *             "type": "COMMON_STOCK"
 *         },
 *         "amount": 3.0,
 *         "cost": -501.9,
 *         "price": 167.3,
 *         "positionEffect": "OPENING"
 *     }
 *    ]
 *
 
 
 */




struct TransferItemTests
{
    
    @Test func testEncodingTransferItem() throws
    {
        
        let instrument : Instrument = Instrument( assetType: .EQUITY,
                                                  symbol: "SFM",
                                                  instrumentId: 12345,
                                                  status: .ACTIVE,
                                                  closingPrice: 128.42,
                                                  type: .COMMON_STOCK
        )
        
        let transferItem : TransferItem = TransferItem( instrument: instrument,
                                                        amount: 42.42,
                                                        cost: 4.24,
                                                        price: 42.24,
                                                        positionEffect: .OPENING
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // Act
        let jsonData = try encoder.encode(transferItem)
        let jsonString = String(data: jsonData, encoding: .utf8)
        
        // Assert
        #expect( nil != jsonString, "Encoded JSON string should not be nil")
        print("Encoded JSON:\n\(jsonString ?? "Nil")")
        
        // test the contents of the details
        #expect( jsonString?.contains( "\"amount\" : 42.42" ) ?? false, "The amount property does not match" )
        #expect( jsonString?.contains( "\"cost\" : 4.24" ) ?? false, "The cost property does not match" )
        #expect( jsonString?.contains( "\"instrument\" : {" ) ?? false, "The JSON does not contain the expected opening brace for the instrument object" )
        #expect( jsonString?.contains( "\"assetType\" : \"EQUITY\"" ) ?? false , "The assetType property does not match")
        #expect( jsonString?.contains( "\"symbol\" : \"SFM\"" ) ?? false ,  "The symbol property does not match")
        #expect( jsonString?.contains( "\"instrumentId\" : 12345" ) ?? false ,  "The instrumentId property does not match")
        #expect( jsonString?.contains( "\"type\" : \"COMMON_STOCK\"" ) ?? false ,  "The type property does not match")
        #expect( jsonString?.contains( "\"status\" : \"ACTIVE\"" ) ?? false ,  "The status property does not match")
        #expect( jsonString?.contains( "\"closingPrice\" : 128.42" ) ?? false ,  "The closingPrice property does not match")
        #expect( jsonString?.contains( "\"positionEffect\" : \"OPENING\"" ) ?? false , "The positionEffect should be OPENING" )
        #expect( jsonString?.contains( "\"price\" : 42.24" ) ?? false, "The price property does not match" )
        
    }
    
    
    @Test func testDecodingTransferItem() throws
    {
        // Arrange
        let jsonString = """
        {
             "instrument": {
                 "assetType": "EQUITY",
                 "status": "ACTIVE",
                 "symbol": "SFM",
                 "instrumentId": 1806651,
                 "closingPrice": 169.76,
                 "type": "COMMON_STOCK"
             },
             "amount": 3.0,
             "cost": -501.9,
             "price": 167.3,
             "positionEffect": "OPENING"
         }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // Act
        let decodedEquity = try decoder.decode(TransferItem.self, from: jsonData)
        
        // Assert
        #expect(decodedEquity.amount == 3.0, "amount should be 3.0")
        #expect(decodedEquity.cost == -501.9, "Cost should be -501.9")
        #expect(decodedEquity.price == 167.30, "Price should be 167.30")
        #expect(decodedEquity.positionEffect == .OPENING, "effect should be OPENING")
        #expect(decodedEquity.instrument?.assetType == .EQUITY, "Asset type should be .EQUITY")
        #expect(decodedEquity.instrument?.symbol == "SFM", "Symbol should be 'SFM'")
        #expect(decodedEquity.instrument?.instrumentId == 1806651, "Instrument ID should be 1806651")
        #expect(decodedEquity.instrument?.closingPrice == 169.76, "Closing price should be 169.76")
        #expect(decodedEquity.instrument?.type == .COMMON_STOCK, "Type should be .COMMON_STOCK")
    }
    
}
