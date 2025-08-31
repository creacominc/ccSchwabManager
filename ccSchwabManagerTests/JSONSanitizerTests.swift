import XCTest
@testable import ccSchwabManager

final class JSONSanitizerTests: XCTestCase {
    
    func testSanitizeAccountNumbersInJSONString() {
        // Test JSON with account number
        let testJSON = """
        {
            "orderId": "12345",
            "accountNumber": 987654321,
            "symbol": "AAPL",
            "quantity": 100
        }
        """
        
        let sanitized = JSONSanitizer.sanitizeAccountNumbers(in: testJSON)
        
        // Should contain the placeholder
        XCTAssertTrue(sanitized.contains("\"accountNumber\" : \"***\""))
        
        // Should not contain the original account number
        XCTAssertFalse(sanitized.contains("987654321"))
        
        // Should preserve other fields
        XCTAssertTrue(sanitized.contains("\"orderId\": \"12345\""))
        XCTAssertTrue(sanitized.contains("\"symbol\": \"AAPL\""))
        XCTAssertTrue(sanitized.contains("\"quantity\": 100"))
    }
    
    func testSanitizeAccountNumbersWithDifferentWhitespace() {
        // Test JSON with different whitespace patterns
        let testJSON = """
        {
            "accountNumber":123456789,
            "symbol": "TSLA"
        }
        """
        
        let sanitized = JSONSanitizer.sanitizeAccountNumbers(in: testJSON)
        
        // Should sanitize regardless of whitespace
        XCTAssertTrue(sanitized.contains("\"accountNumber\" : \"***\""))
        XCTAssertFalse(sanitized.contains("123456789"))
    }
    
    func testSanitizeAccountNumbersWithMultipleAccountNumbers() {
        // Test JSON with multiple account numbers
        let testJSON = """
        {
            "primaryAccount": {
                "accountNumber": 111111111
            },
            "secondaryAccount": {
                "accountNumber": 222222222
            }
        }
        """
        
        let sanitized = JSONSanitizer.sanitizeAccountNumbers(in: testJSON)
        
        // Should sanitize all account numbers
        XCTAssertTrue(sanitized.contains("\"accountNumber\" : \"***\""))
        XCTAssertFalse(sanitized.contains("111111111"))
        XCTAssertFalse(sanitized.contains("222222222"))
        
        // Should preserve structure
        XCTAssertTrue(sanitized.contains("\"primaryAccount\""))
        XCTAssertTrue(sanitized.contains("\"secondaryAccount\""))
    }
    
    func testSanitizeAccountNumbersWithNoAccountNumbers() {
        // Test JSON without account numbers
        let testJSON = """
        {
            "orderId": "12345",
            "symbol": "AAPL",
            "quantity": 100
        }
        """
        
        let sanitized = JSONSanitizer.sanitizeAccountNumbers(in: testJSON)
        
        // Should remain unchanged
        XCTAssertEqual(sanitized, testJSON)
    }
    
    func testSanitizeAccountNumbersWithEmptyString() {
        let sanitized = JSONSanitizer.sanitizeAccountNumbers(in: "")
        XCTAssertEqual(sanitized, "")
    }
    
    func testSanitizeAccountNumbersWithComplexJSON() {
        // Test with more complex JSON structure
        let testJSON = """
        {
            "order": {
                "id": "ORD-001",
                "accountNumber": 123456789,
                "details": {
                    "symbol": "AAPL",
                    "quantity": 100,
                    "price": 150.50
                }
            },
            "metadata": {
                "timestamp": "2024-01-01T00:00:00Z",
                "source": "mobile"
            }
        }
        """
        
        let sanitized = JSONSanitizer.sanitizeAccountNumbers(in: testJSON)
        
        // Should sanitize the account number
        XCTAssertTrue(sanitized.contains("\"accountNumber\" : \"***\""))
        XCTAssertFalse(sanitized.contains("123456789"))
        
        // Should preserve all other structure and data
        XCTAssertTrue(sanitized.contains("\"order\""))
        XCTAssertTrue(sanitized.contains("\"id\": \"ORD-001\""))
        XCTAssertTrue(sanitized.contains("\"symbol\": \"AAPL\""))
        XCTAssertTrue(sanitized.contains("\"quantity\": 100"))
        XCTAssertTrue(sanitized.contains("\"price\": 150.50"))
        XCTAssertTrue(sanitized.contains("\"timestamp\": \"2024-01-01T00:00:00Z\""))
        XCTAssertTrue(sanitized.contains("\"source\": \"mobile\""))
    }
}
