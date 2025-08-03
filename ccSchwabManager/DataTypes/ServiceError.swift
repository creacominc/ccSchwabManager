//
//  ServiceError.swift
//

import Foundation

/**
 * represents a ServiceError response from Schwab
 *
 *ServiceError{
    message    string
    errors    [string:Any]
    }
 *
 *
 *  Example error json objects:
 *        {"error":"invalid_grant","error_description":"Invalid refresh token: null"}
 *        { "errors": [ { "id":"01234abcd-da01-az19-a123-1234asdf", "status":401, "title": "Unauthorized",    "detail": "Client not authorized" } ] }
 */

class ServiceError: Codable, Identifiable
{
    struct ErrorDetail: Codable, Equatable {
        let details: [String: StringOrInt]
        
        init(details: [String: StringOrInt]) {
            self.details = details
        }
        
        enum StringOrInt: Codable, Equatable {
            case string(String)
            case integer(Int)
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let stringValue = try? container.decode(String.self) {
                    self = .string(stringValue)
                } else if let intValue = try? container.decode(Int.self) {
                    self = .integer(intValue)
                } else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Value must be either String or Int")
                }
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                switch self {
                case .string(let value):
                    try container.encode(value)
                case .integer(let value):
                    try container.encode(value)
                }
            }
            
            static func == (lhs: StringOrInt, rhs: StringOrInt) -> Bool {
                switch (lhs, rhs) {
                case (.string(let l), .string(let r)):
                    return l == r
                case (.integer(let l), .integer(let r)):
                    return l == r
                default:
                    return false
                }
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
            var details: [String: StringOrInt] = [:]
            
            for key in container.allKeys {
                if let stringValue = try? container.decode(String.self, forKey: key) {
                    details[key.stringValue] = .string(stringValue)
                } else if let intValue = try? container.decode(Int.self, forKey: key) {
                    details[key.stringValue] = .integer(intValue)
                }
            }
            
            self.details = details
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKeys.self)
            for (key, value) in details {
                let codingKey = DynamicCodingKeys(stringValue: key)!
                switch value {
                case .string(let stringValue):
                    try container.encode(stringValue, forKey: codingKey)
                case .integer(let intValue):
                    try container.encode(intValue, forKey: codingKey)
                }
            }
        }



    } // ErrorDetail
    
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
    
    let errors: [ErrorDetail]?
    let error: String?
    let errorDescription: String?
    
    init(errors: [ErrorDetail]? = nil, error: String? = nil, errorDescription: String? = nil) {
        self.errors = errors
        self.error = error
        self.errorDescription = errorDescription
    }
    
    var id: String {
        return UUID().uuidString
    }
    
    enum CodingKeys: String, CodingKey {
        case errors
        case error
        case errorDescription = "error_description"
    }
    
    public func printErrors( prefix: String = "" )
    {
        AppLogger.shared.error( "\(prefix) --- ServiceError:" )
        if let errors: [ServiceError.ErrorDetail] = errors {
            AppLogger.shared.error( "\t\terrors:" )
            // swiftlint:disable:next type_name
            for (index, error) in errors.enumerated() {
                AppLogger.shared.error( "\t\t[\(index)]:" )
                for (key, value) in error.details {
                    switch value {
                    case .string(let str):
                        AppLogger.shared.error( "\t\t\t\(key): \(str)" )
                    case .integer(let num):
                        AppLogger.shared.error( "\t\t\t\(key): \(num)" )
                    }
                }
            }
        }
        if let error: String = error {
            AppLogger.shared.error( "\t\terror: \(error)" )
        }
        if let errorDescription: String = errorDescription {
            AppLogger.shared.error( "\t\terrorDescription: \(errorDescription)" )
        }
    }
    
}
