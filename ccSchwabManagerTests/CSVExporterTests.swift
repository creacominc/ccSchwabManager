import XCTest
@testable import ccSchwabManager

class CSVExporterTests: XCTestCase {
    
    func testGenerateTransactionCSV() {
        // Create test transaction data
        let testTransactions = [
            Transaction(
                activityId: 1,
                time: "2025-07-13T10:00:00+0000",
                tradeDate: "2025-07-13T10:00:00+0000",
                netAmount: -100.0,
                transferItems: [
                    TransferItem(
                        instrument: Instrument(
                            assetType: .EQUITY,
                            symbol: "AAPL",
                            description: "Apple Inc"
                        ),
                        amount: 1.0,
                        price: 100.0
                    )
                ]
            ),
            Transaction(
                activityId: 2,
                time: "2025-07-13T11:00:00+0000",
                tradeDate: "2025-07-13T11:00:00+0000",
                netAmount: 150.0,
                transferItems: [
                    TransferItem(
                        instrument: Instrument(
                            assetType: .EQUITY,
                            symbol: "AAPL",
                            description: "Apple Inc"
                        ),
                        amount: -1.5,
                        price: 100.0
                    )
                ]
            )
        ]
        
        // Test CSV generation
        let csvContent = CSVExporter.generateTransactionCSV(testTransactions, symbol: "AAPL")
        
        // Verify CSV format
        XCTAssertTrue(csvContent.contains("Date,Type,Quantity,Price,Net Amount"))
        XCTAssertTrue(csvContent.contains("Buy"))
        XCTAssertTrue(csvContent.contains("Sell"))
        XCTAssertTrue(csvContent.contains("1.0000"))
        XCTAssertTrue(csvContent.contains("-1.5000"))
        XCTAssertTrue(csvContent.contains("100.00"))
        XCTAssertTrue(csvContent.contains("-100.00"))
        XCTAssertTrue(csvContent.contains("150.00"))
    }
    
    func testGenerateTaxLotCSV() {
        // Create test tax lot data
        let testTaxLots = [
            SalesCalcPositionsRecord(
                openDate: "2025-01-15",
                gainLossPct: 5.2,
                gainLossDollar: 52.0,
                quantity: 100.0,
                price: 105.0,
                costPerShare: 100.0,
                marketValue: 10500.0,
                costBasis: 10000.0,
                splitMultiple: 1.0
            ),
            SalesCalcPositionsRecord(
                openDate: "2025-02-20",
                gainLossPct: -2.1,
                gainLossDollar: -21.0,
                quantity: 50.0,
                price: 98.0,
                costPerShare: 100.0,
                marketValue: 4900.0,
                costBasis: 5000.0,
                splitMultiple: 2.0
            )
        ]
        
        // Test CSV generation
        let csvContent = CSVExporter.generateTaxLotCSV(testTaxLots)
        
        // Verify CSV format
        XCTAssertTrue(csvContent.contains("Open Date,Quantity,Price,Cost/Share,Market Value,Cost Basis,Gain/Loss $,Gain/Loss %,Split Multiple"))
        XCTAssertTrue(csvContent.contains("2025-01-15"))
        XCTAssertTrue(csvContent.contains("2025-02-20"))
        XCTAssertTrue(csvContent.contains("100.00"))
        XCTAssertTrue(csvContent.contains("50.00"))
        XCTAssertTrue(csvContent.contains("105.00"))
        XCTAssertTrue(csvContent.contains("98.00"))
        XCTAssertTrue(csvContent.contains("100.00"))
        XCTAssertTrue(csvContent.contains("10500.00"))
        XCTAssertTrue(csvContent.contains("4900.00"))
        XCTAssertTrue(csvContent.contains("10000.00"))
        XCTAssertTrue(csvContent.contains("5000.00"))
        XCTAssertTrue(csvContent.contains("52.00"))
        XCTAssertTrue(csvContent.contains("-21.00"))
        XCTAssertTrue(csvContent.contains("5.20"))
        XCTAssertTrue(csvContent.contains("-2.10"))
        XCTAssertTrue(csvContent.contains("1.00"))  // First record has splitMultiple = 1.0
        XCTAssertTrue(csvContent.contains("2.00"))  // Second record has splitMultiple = 2.0
    }
    
    func testFormatTransactionDate() {
        let dateString = "2025-07-13T10:30:45+0000"
        let formattedDate = CSVExporter.formatTransactionDate(dateString)
        
        // Should format as YYYY-MM-DD HH:MM:SS in UTC
        XCTAssertTrue(formattedDate.contains("2025-07-13"))
        XCTAssertTrue(formattedDate.contains("10:30:45"))
        print("Formatted date: \(formattedDate)")
    }
    
    func testFormatTransactionDateWithInvalidInput() {
        let invalidDateString = "invalid-date"
        let formattedDate = CSVExporter.formatTransactionDate(invalidDateString)
        
        // Should return empty string for invalid dates
        XCTAssertEqual(formattedDate, "")
    }
} 
