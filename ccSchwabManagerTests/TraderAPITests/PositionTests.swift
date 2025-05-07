//
//  PositionTests.swift
//

import Testing
import Foundation
@testable import ccSchwabManager

/**
 
 {"shortQuantity":0.0,"averagePrice":40.851890220734,"currentDayProfitLoss":-7.390248,"currentDayProfitLossPercentage":-0.25,"longQuantity":61.5854,"settledLongQuantity":61.5854,"settledShortQuantity":0.0,
     "instrument":{"assetType":"COLLECTIVE_INVESTMENT","cusip":"92189F106","symbol":"GDX","description":"VanEck Gold Miners ETF","type":"EXCHANGE_TRADED_FUND"},
     "marketValue":2899.44,"maintenanceRequirement":0.0,"averageLongPrice":41.512245458664,"taxLotAverageLongPrice":40.851890220734,"longOpenProfitLoss":383.560632000008,"previousSessionLongQuantity":61.5854,"currentDayCost":0.0}
 
 {"shortQuantity":0.0,"averagePrice":6.659616806694,"currentDayProfitLoss":4.63839,"currentDayProfitLossPercentage":0.17,"longQuantity":463.839,"settledLongQuantity":463.839,"settledShortQuantity":0.0,"agedQuantity":0.0,
     "instrument":{"assetType":"MUTUAL_FUND","cusip":"665162699","symbol":"NHFIX","description":"Northern High Yield Fixed Income","netChange":0.01,"type":"NO_LOAD_TAXABLE"},
     "marketValue":2764.48,"maintenanceRequirement":0.0,"averageLongPrice":6.658004609783,"taxLotAverageLongPrice":6.659616806694,"longOpenProfitLoss":-324.509560000138,"previousSessionLongQuantity":463.839,"currentDayCost":0.0}

 {"shortQuantity":0.0,"averagePrice":91.805,"currentDayProfitLoss":38.88,"currentDayProfitLossPercentage":5.45,"longQuantity":8.0,"settledLongQuantity":8.0,"settledShortQuantity":0.0,"instrument":{"assetType":"EQUITY","cusip":"15101Q207","symbol":"CLS","netChange":5.28},"marketValue":752.56,"maintenanceRequirement":0.0,"averageLongPrice":91.805,"taxLotAverageLongPrice":91.805,"longOpenProfitLoss":18.12,"previousSessionLongQuantity":8.0,"currentDayCost":0.0}

 */

struct PositionTests
{
    
    /**
     {"shortQuantity":0.0,"averagePrice":91.805,"currentDayProfitLoss":38.88,"currentDayProfitLossPercentage":5.45,"longQuantity":8.0,"settledLongQuantity":8.0,"settledShortQuantity":0.0,
     "instrument":{"assetType":"EQUITY","cusip":"15101Q207","symbol":"CLS","netChange":5.28},
     "marketValue":752.56,"maintenanceRequirement":0.0,"averageLongPrice":91.805,"taxLotAverageLongPrice":91.805,"longOpenProfitLoss":18.12,"previousSessionLongQuantity":8.0,"currentDayCost":0.0}
     */
    @Test func testEncodingEquityPosition() throws
    {
        let instrument : Instrument = Instrument(assetType: .EQUITY,
                                                 cusip: "15101Q207",
                                                 symbol: "CLS",
                                                 netChange: 5.28)
        let position : Position = .init( shortQuantity: 0.0,
                                         averagePrice: 91.805,
                                         currentDayProfitLoss: 38.88,
                                         currentDayProfitLossPercentage: 5.45,
                                         longQuantity: 8.0,
                                         settledLongQuantity: 8.0,
                                         settledShortQuantity: 0.0,
                                         instrument: instrument,
                                         marketValue: 752.56,
                                         maintenanceRequirement: 0.0,
                                         averageLongPrice: 91.805,
                                         taxLotAverageLongPrice: 91.805,
                                         longOpenProfitLoss: 18.12,
                                         previousSessionLongQuantity: 8.0,
                                         currentDayCost: 0.0 )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        // encode
        let jsonData : Data = try encoder.encode( position )
        let jsonString : String = String( data: jsonData, encoding: .utf8 ) ?? ""
        
        let expectedString : String = """
        {
          "averageLongPrice" : 91.805,
          "averagePrice" : 91.805,
          "currentDayCost" : 0,
          "currentDayProfitLoss" : 38.88,
          "currentDayProfitLossPercentage" : 5.45,
          "instrument" : {
            "assetType" : "EQUITY",
            "cusip" : "15101Q207",
            "netChange" : 5.28,
            "symbol" : "CLS"
          },
          "longOpenProfitLoss" : 18.12,
          "longQuantity" : 8,
          "maintenanceRequirement" : 0,
          "marketValue" : 752.56,
          "previousSessionLongQuantity" : 8,
          "settledLongQuantity" : 8,
          "settledShortQuantity" : 0,
          "shortQuantity" : 0,
          "taxLotAverageLongPrice" : 91.805
        }
        """
        #expect( expectedString == jsonString )
    }
    
    
    @Test func testDecodingEquityPosition() throws
    {
        let jsonString : String = """
        {
          "averageLongPrice" : 91.805,
          "averagePrice" : 91.805,
          "currentDayCost" : 0,
          "currentDayProfitLoss" : 38.88,
          "currentDayProfitLossPercentage" : 5.45,
          "instrument" : {
            "assetType" : "EQUITY",
            "cusip" : "15101Q207",
            "netChange" : 5.28,
            "symbol" : "CLS"
          },
          "longOpenProfitLoss" : 18.12,
          "longQuantity" : 8,
          "maintenanceRequirement" : 0,
          "marketValue" : 752.56,
          "previousSessionLongQuantity" : 8,
          "settledLongQuantity" : 8,
          "settledShortQuantity" : 0,
          "shortQuantity" : 0,
          "taxLotAverageLongPrice" : 91.805
        }
        """
        let decoder = JSONDecoder()
        
        let jsonData : Data = jsonString.data(using: .utf8) ?? Data()
        let position: Position = try decoder.decode(Position.self, from: jsonData)
        #expect(position.instrument?.symbol == "CLS")
        #expect(position.longOpenProfitLoss == 18.12)
        #expect(position.taxLotAverageLongPrice == 91.805)
    }
    
    /**
     *
     * {
     * "shortQuantity":0.0,"averagePrice":6.659616806694,"currentDayProfitLoss":4.63839,
     * "currentDayProfitLossPercentage":0.17,"longQuantity":463.839,"settledLongQuantity":463.839,
     * "settledShortQuantity":0.0,"agedQuantity":0.0,
     * "instrument":{"assetType":"MUTUAL_FUND","cusip":"665162699","symbol":"NHFIX",
     *           "description":"Northern High Yield Fixed Income",
     *           "netChange":0.01,"type":"NO_LOAD_TAXABLE"},
     * "marketValue":2764.48,"maintenanceRequirement":0.0,"averageLongPrice":6.658004609783,
     * "taxLotAverageLongPrice":6.659616806694,"longOpenProfitLoss":-324.509560000138,
     * "previousSessionLongQuantity":463.839,"currentDayCost":0.0
     * }
     *
     */
    @Test func testEncodingMutualFundPosition() throws
    {
        let instrument : Instrument = Instrument(    assetType: .MUTUAL_FUND,
                                                     cusip: "665162699",
                                                     symbol: "NHFIX",
                                                     description: "Northern High Yield Fixed Income",
                                                     netChange: 0.01,
                                                     type: .NO_LOAD_TAXABLE )
        let position : Position = Position(shortQuantity: 0.0,
                                           averagePrice: 6.659616806694,
                                           currentDayProfitLoss: 4.63839,
                                           currentDayProfitLossPercentage: 0.17,
                                           longQuantity: 463.839,
                                           settledLongQuantity: 463.839,
                                           settledShortQuantity: 0.0,
                                           agedQuantity: 0.0,
                                           instrument: instrument,
                                           marketValue: 2764.48,
                                           maintenanceRequirement: 0.0,
                                           averageLongPrice: 6.658004609783,
                                           taxLotAverageLongPrice: 6.659616806694,
                                           longOpenProfitLoss: -324.509560000138,
                                           previousSessionLongQuantity: 463.83)
        let encoder : JSONEncoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let jsonData : Data = try encoder.encode(position)
        let jsonString : String = String(data: jsonData, encoding: .utf8)!

        let expectedString : String = """
            {
              "agedQuantity" : 0,
              "averageLongPrice" : 6.658004609783,
              "averagePrice" : 6.659616806694,
              "currentDayProfitLoss" : 4.63839,
              "currentDayProfitLossPercentage" : 0.17,
              "instrument" : {
                "assetType" : "MUTUAL_FUND",
                "cusip" : "665162699",
                "description" : "Northern High Yield Fixed Income",
                "netChange" : 0.01,
                "symbol" : "NHFIX",
                "type" : "NO_LOAD_TAXABLE"
              },
              "longOpenProfitLoss" : -324.509560000138,
              "longQuantity" : 463.839,
              "maintenanceRequirement" : 0,
              "marketValue" : 2764.48,
              "previousSessionLongQuantity" : 463.83,
              "settledLongQuantity" : 463.839,
              "settledShortQuantity" : 0,
              "shortQuantity" : 0,
              "taxLotAverageLongPrice" : 6.659616806694
            }
            """
        #expect(jsonString == expectedString)
    }
    
    
    @Test func testDecodingMutualFundPosition() throws
    {
        let jsonString : String = """
            {
              "agedQuantity" : 0,
              "averageLongPrice" : 6.658004609783,
              "averagePrice" : 6.659616806694,
              "currentDayProfitLoss" : 4.63839,
              "currentDayProfitLossPercentage" : 0.17,
              "instrument" : {
                "assetType" : "MUTUAL_FUND",
                "cusip" : "665162699",
                "description" : "Northern High Yield Fixed Income",
                "netChange" : 0.01,
                "symbol" : "NHFIX",
                "type" : "NO_LOAD_TAXABLE"
              },
              "longOpenProfitLoss" : -324.509560000138,
              "longQuantity" : 463.839,
              "maintenanceRequirement" : 0,
              "marketValue" : 2764.48,
              "previousSessionLongQuantity" : 463.83,
              "settledLongQuantity" : 463.839,
              "settledShortQuantity" : 0,
              "shortQuantity" : 0,
              "taxLotAverageLongPrice" : 6.659616806694
            }
            """
        let decoder = JSONDecoder()

        let jsonData : Data = jsonString.data(using: .utf8) ?? Data()
        let position : Position = try decoder.decode(Position.self, from: jsonData)

        #expect( position.longOpenProfitLoss == -324.509560000138 )
        #expect( position.settledLongQuantity == 463.839 )
        #expect( position.instrument?.assetType == .MUTUAL_FUND )
        #expect( position.averagePrice == 6.659616806694 )

    }

}

