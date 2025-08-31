import Foundation

/// Utility functions for sanitizing JSON data to remove sensitive information
struct JSONSanitizer {
    
    /// Sanitizes JSON string by replacing account numbers with a placeholder
    /// - Parameter jsonString: The JSON string to sanitize
    /// - Returns: Sanitized JSON string with account numbers replaced
    static func sanitizeAccountNumbers(in jsonString: String) -> String {
        // Pattern to match "accountNumber" : 123456789, (with optional whitespace)
        let accountNumberPattern = #""accountNumber"\s*:\s*(\d+)"#
        
        // Replace account numbers with "***" while preserving the JSON structure
        let sanitized = jsonString.replacingOccurrences(
            of: accountNumberPattern,
            with: "\"accountNumber\" : \"***\"",
            options: .regularExpression
        )
        
        return sanitized
    }
    
    /// Sanitizes JSON data by converting to string, sanitizing, and returning sanitized data
    /// - Parameter jsonData: The JSON data to sanitize
    /// - Returns: Sanitized JSON data
    static func sanitizeAccountNumbers(in jsonData: Data) -> Data {
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return jsonData
        }
        
        let sanitizedString = sanitizeAccountNumbers(in: jsonString)
        return Data(sanitizedString.utf8)
    }
    
    /// Sanitizes any object by encoding to JSON, sanitizing, and returning the sanitized string
    /// - Parameter object: The object to sanitize
    /// - Returns: Sanitized JSON string, or error message if encoding fails
    static func sanitizeAccountNumbers<T: Encodable>(in object: T) -> String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(object)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            return sanitizeAccountNumbers(in: jsonString)
        } catch {
            return "Error encoding object for sanitization: \(error)"
        }
    }
}
