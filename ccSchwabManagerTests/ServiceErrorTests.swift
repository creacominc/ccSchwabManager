import XCTest
@testable import ccSchwabManager

final class ServiceErrorTests: XCTestCase {
    
    func testServiceErrorDecodingWithErrorsArray() throws {
        // Given
        let jsonString = """
        {
            "errors": [
                {
                    "id": "01234abcd-da01-az19-a123-1234asdf",
                    "status": 401,
                    "title": "Unauthorized",
                    "detail": "Client not authorized",
                    "custom_field": "some value",
                    "error_code": 500
                }
            ]
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        
        // When
        let serviceError = try JSONDecoder().decode(ServiceError.self, from: jsonData)
        
        // Then
        XCTAssertNotNil(serviceError.errors)
        XCTAssertEqual(serviceError.errors?.count, 1)
        let errorDetail = serviceError.errors![0].details
        
        // Test string values
        if case .string(let id) = errorDetail["id"] {
            XCTAssertEqual(id, "01234abcd-da01-az19-a123-1234asdf")
        } else {
            XCTFail("Expected string value for 'id'")
        }
        
        if case .string(let title) = errorDetail["title"] {
            XCTAssertEqual(title, "Unauthorized")
        } else {
            XCTFail("Expected string value for 'title'")
        }
        
        // Test integer values
        if case .integer(let status) = errorDetail["status"] {
            XCTAssertEqual(status, 401)
        } else {
            XCTFail("Expected integer value for 'status'")
        }
        
        if case .integer(let errorCode) = errorDetail["error_code"] {
            XCTAssertEqual(errorCode, 500)
        } else {
            XCTFail("Expected integer value for 'error_code'")
        }
        
        // Test custom field
        if case .string(let customValue) = errorDetail["custom_field"] {
            XCTAssertEqual(customValue, "some value")
        } else {
            XCTFail("Expected string value for 'custom_field'")
        }
    }
    
    func testServiceErrorDecodingWithSimpleError() throws {
        // Given
        let jsonString = """
        {
            "error": "invalid_grant",
            "error_description": "Invalid refresh token: null"
        }
        """
        
        let jsonData = jsonString.data(using: .utf8)!
        
        // When
        let serviceError = try JSONDecoder().decode(ServiceError.self, from: jsonData)
        
        // Then
        XCTAssertEqual(serviceError.error, "invalid_grant")
        XCTAssertEqual(serviceError.errorDescription, "Invalid refresh token: null")
        XCTAssertNil(serviceError.errors)
    }
    
    func testServiceErrorEncodingWithErrorsArray() throws {
        // Given
        var details: [String: ServiceError.ErrorDetail.StringOrInt] = [:]
        details["id"] = .string("01234abcd-da01-az19-a123-1234asdf")
        details["status"] = .integer(401)
        details["title"] = .string("Unauthorized")
        details["detail"] = .string("Client not authorized")
        details["custom_field"] = .string("some value")
        details["error_code"] = .integer(500)
        
        let errorDetail = ServiceError.ErrorDetail(details: details)
        let serviceError = ServiceError(errors: [errorDetail])
        
        // When
        let jsonData = try JSONEncoder().encode(serviceError)
        let decodedError = try JSONDecoder().decode(ServiceError.self, from: jsonData)
        
        // Then
        XCTAssertNotNil(decodedError.errors)
        XCTAssertEqual(decodedError.errors?.count, 1)
        let decodedDetails = decodedError.errors![0].details
        
        // Verify all values are preserved
        XCTAssertEqual(decodedDetails["id"], details["id"])
        XCTAssertEqual(decodedDetails["status"], details["status"])
        XCTAssertEqual(decodedDetails["title"], details["title"])
        XCTAssertEqual(decodedDetails["detail"], details["detail"])
        XCTAssertEqual(decodedDetails["custom_field"], details["custom_field"])
        XCTAssertEqual(decodedDetails["error_code"], details["error_code"])
    }
    
    func testServiceErrorEncodingWithSimpleError() throws {
        // Given
        let serviceError = ServiceError(
            error: "invalid_grant",
            errorDescription: "Invalid refresh token: null"
        )
        
        // When
        let jsonData = try JSONEncoder().encode(serviceError)
        let decodedError = try JSONDecoder().decode(ServiceError.self, from: jsonData)
        
        // Then
        XCTAssertEqual(decodedError.error, "invalid_grant")
        XCTAssertEqual(decodedError.errorDescription, "Invalid refresh token: null")
        XCTAssertNil(decodedError.errors)
    }
} 
