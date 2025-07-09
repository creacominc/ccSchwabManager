//
//  OrderStatusFormatterTests.swift
//  ccSchwabManagerTests
//
//  Created by Harold Tomlinson on 2025-01-07.
//

import XCTest
@testable import ccSchwabManager

class OrderStatusFormatterTests: XCTestCase {
    
    func testPHOrderFormatting() {
        // Test the PH order from the JSON response
        let phOrder = Order(
            orderId: 1003670798912,
            status: .AWAITING_RELEASE_TIME,
            orderType: .TRAILING_STOP_LIMIT,
            quantity: 1,
            filledQuantity: 0,
            remainingQuantity: 1,
            priceLinkBasis: .BID,
            priceLinkType: .PERCENT,
            priceOffset: 3.0,
            stopType: .BID,
            duration: .GOOD_TILL_CANCEL,
            releaseTime: "2025-07-14T13:35:00+0000",
            orderLegCollection: [
                OrderLeg(
                    orderLegType: .EQUITY,
                    legId: 1,
                    instrument: Instrument(
                        assetType: .EQUITY,
                        cusip: "701094104",
                        symbol: "PH",
                        instrumentId: 2799368
                    ),
                    instruction: .BUY,
                    positionEffect: .OPENING,
                    quantity: 1
                )
            ],
            orderStrategyType: .SINGLE
        )
        
        let description = OrderStatusFormatter.formatDetailedOrderDescription(order: phOrder)
        
        // Expected format: "BUY 1 PH @BID+3.00% TRSTPLMT BID GTC SUBMIT AT 2025/07/14 13:35:00 [TO OPEN]"
        XCTAssertTrue(description.contains("BUY 1 PH"))
        XCTAssertTrue(description.contains("@BID+3.00%"))
        XCTAssertTrue(description.contains("TRSTPLMT"))
        XCTAssertTrue(description.contains("BID"))
        XCTAssertTrue(description.contains("GTC"))
        XCTAssertTrue(description.contains("SUBMIT AT"))
        XCTAssertTrue(description.contains("[TO OPEN]"))
        
        print("PH Order Description: \(description)")
    }
    
    func testDurationFormatting() {
        XCTAssertEqual(OrderStatusFormatter.formatDuration(.GOOD_TILL_CANCEL), "GTC")
        XCTAssertEqual(OrderStatusFormatter.formatDuration(.DAY), "DAY")
        XCTAssertEqual(OrderStatusFormatter.formatDuration(.FILL_OR_KILL), "FOK")
    }
    
    func testOrderTypeFormatting() {
        XCTAssertEqual(OrderStatusFormatter.formatOrderType(.TRAILING_STOP_LIMIT), "TRSTPLMT")
        XCTAssertEqual(OrderStatusFormatter.formatOrderType(.LIMIT), "LMT")
        XCTAssertEqual(OrderStatusFormatter.formatOrderType(.MARKET), "MKT")
    }
} 