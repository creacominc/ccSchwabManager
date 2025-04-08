//
//  testPositionStatementData.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-07.
//

import Testing
import Foundation
@testable import ccSchwabManager

struct testPositionStatementData
{

    @Test func testPositionStatementDataInitialization() async throws
    {
        let csvData = [
            "AAPL", "100", "150000", "1500", "1600", "50", "10000", "Account1", "Company1", "10", "10000"
        ]

        let positionStatement = PositionStatementData(csv: csvData)

        #expect( positionStatement.instrument == "AAPL" )
        #expect( positionStatement.quantity == 100.0 )
        #expect( positionStatement.netLiquid == 150000.0 )
        #expect( positionStatement.tradePrice == 1500.0 )
        #expect( positionStatement.last == 1600.0 )
        #expect( positionStatement.atr == 50.0 )
        #expect( positionStatement.floatingPL == 10000.0 )
        #expect( positionStatement.account == "Account1" )
        #expect( positionStatement.company == "Company1" )
        #expect( positionStatement.plPercent == 10.0 )
        #expect( positionStatement.plOpen == 10000.0 )
    }

    @Test func testStringToDouble() async throws
    {
        #expect(stringToDouble(content: "1234.56") == 1234.56 )
        #expect(stringToDouble(content: "$1234.56") == 1234.56 )
        #expect(stringToDouble(content: "(1234.56)") == -1234.56 )
        #expect(stringToDouble(content: "0") == 0.0 )
        #expect(stringToDouble(content: "$1,234.56") == 1234.56 )
    }
}

