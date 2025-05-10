//
//  ServiceError.swift
//

import Foundation

/**
 * represents a ServiceError response from Schwab
 *
 *ServiceError{
    message    string
    errors    [string]
    }
 */

class ServiceError:  Codable, Identifiable
{
    public var message: String?
    public var errors: [String]?
    
    enum CodingKeys : String, CodingKey {
        case message = "message"
        case errors  = "errors"
    }
    
    public init(message: String? = nil, errors: [String]? = nil)
    {
        self.message = message
        self.errors = errors
    }
    
}
