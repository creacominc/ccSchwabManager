//
//  File.swift
//  ccSchwabManager
//
//

import Foundation

func getNextTradeDate() -> Date
{
    let calendar = Calendar.current
    var nextDate : Date = Date().afterOpen().localDate()
    /**
        * @TODO:  Replace this with a dynamic list of holidays.
     */
    // List of holidays (example for US holidays, adjust as needed)
    let holidays = [
        "2025-01-01", // New Year's Day
        "2025-01-20", // Martin Luther King Jr. Day
        "2025-02-17", // Presidents' Day
        "2025-04-18", // Good Friday
        "2025-05-26", // Memorial Day
        "2025-06-19", // Juneteenth
        "2025-07-04", // Independence Day
        "2025-09-01", // Labor Day
        "2025-10-13", // Columbus Day
        "2025-11-11", // Veterans Day
        "2025-11-27", // Thanksgiving Day
        "2025-12-25", // Christmas Day
        // Add more holidays here
    ].compactMap {
        DateFormatter.date.date(from: $0)
    }
    repeat {
        nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
    } while calendar.isDateInWeekend(nextDate) || holidays.contains(nextDate)

    return nextDate
}

func getDateNQuartersAgoStr( quarterDelta : Int ) -> String
{
    // get date one year ago
    var components = DateComponents()
    components.month = -quarterDelta * 3
    components.day = +1
    // format a string with the date one year ago.
    return Calendar.current.date(byAdding: components, to: Date())!.formatted(.iso8601
        .year()
        .month()
        .day()
        .timeZone(separator: .omitted)
        .time(includingFractionalSeconds: true)
        .timeSeparator(.colon)
    )
}

func getDateNQuartersAgoStrForEndDate( quarterDelta : Int ) -> String
{
    // get date for end of quarter (start of next quarter)
    var components = DateComponents()
    components.month = -quarterDelta * 3
    components.day = +1
    // Add 1 second to avoid overlap with next quarter's start date
    let baseDate = Calendar.current.date(byAdding: components, to: Date())!
    let endDate = Calendar.current.date(byAdding: .second, value: -1, to: baseDate)!
    
    return endDate.formatted(.iso8601
        .year()
        .month()
        .day()
        .timeZone(separator: .omitted)
        .time(includingFractionalSeconds: true)
        .timeSeparator(.colon)
    )
}

func getDateNYearsAgoStr( yearDelta : Int ) -> String
{
    // get date one year ago
    var components = DateComponents()
    components.year = -yearDelta
    components.day = +1
    // format a string with the date one year ago.
    return Calendar.current.date(byAdding: components, to: Date())!.formatted(.iso8601
        .year()
        .month()
        .day()
        .timeZone(separator: .omitted)
        .time(includingFractionalSeconds: true)
        .timeSeparator(.colon)
    )
}

extension DateFormatter
{
    static let date: DateFormatter =
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

extension Date
{
    func dateOnly() -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return  dateFormatter.string(from: self)
    }
    func dateString() -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        return  dateFormatter.string(from: self)
    }
    func afterOpen() -> Date
    {
        guard let localDate = Calendar.current.date( bySettingHour: 9, minute: 40, second: 0, of: self ) else {return self}
        return localDate
    }
    func localDate() -> Date
    {
        let timeZoneOffset = Double(TimeZone.current.secondsFromGMT(for: self))
        guard let localDate = Calendar.current.date(byAdding: .second, value: Int(timeZoneOffset), to: self) else {return self}
        return localDate
    }
}


// Function to calculate the difference in days between today and a given date string
// This function was suggested by GitHub Copilot
func daysSinceDateString( dateString: String ) -> Int?
{
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat =  "yyyy-MM-dd HH:mm:ss" // "MM/dd/yyyy" //
    // Convert the date string to a Date object
    guard let date : Date = dateFormatter.date(from: dateString) else {
        print("Invalid date format.  date = \(dateString)")
        return nil
    }
    return( daysSinceDate(date: date))
}

func daysSinceDate( date: Date ) -> Int?
{
    // Get today's date
    let today = Date()
    // Calculate the difference in days
    let calendar = Calendar.current
    let components = calendar.dateComponents([.day], from: date, to: today)
    return components.day
}

//
//func extractExpirationDate(from symbol: String?, description: String?) -> Date? {
//    // Primary method: Extract 6-digit date from option symbol
//    if let symbol = symbol {
//        // Look for 6 consecutive digits after the underlying symbol
//        // Example: "INTC  250516C00025000" -> extract "250516"
//        let pattern = #"(\d{6})"#
//        if let regex = try? NSRegularExpression(pattern: pattern),
//           let match = regex.firstMatch(in: symbol, range: NSRange(symbol.startIndex..., in: symbol)) {
//            let dateString = String(symbol[Range(match.range(at: 1), in: symbol)!])
//
//            // Parse the date (format: YYMMDD)
//            let formatter = DateFormatter()
//            formatter.dateFormat = "yyMMdd"
//            formatter.timeZone = TimeZone.current
//
//            if let date = formatter.date(from: dateString) {
//                return date
//            }
//        }
//    }
//
//    // Secondary method: Extract date from description
//    if let description = description {
//        // Look for date pattern like "05/16/2025" or "2025-01-16"
//        let patterns = [
//            #"(\d{1,2})/(\d{1,2})/(\d{4})"#,  // MM/DD/YYYY
//            #"(\d{4})-(\d{1,2})-(\d{1,2})"#   // YYYY-MM-DD
//        ]
//
//        for pattern in patterns {
//            if let regex = try? NSRegularExpression(pattern: pattern),
//               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
//
//                let formatter = DateFormatter()
//                if pattern.contains("/") {
//                    formatter.dateFormat = "MM/dd/yyyy"
//                } else {
//                    formatter.dateFormat = "yyyy-MM-dd"
//                }
//                formatter.timeZone = TimeZone.current
//
//                let dateString = String(description[Range(match.range, in: description)!])
//                if let date = formatter.date(from: dateString) {
//                    return date
//                }
//            }
//        }
//    }
//
//    return nil
//}


// Helper function to extract expiration date from option symbol or description
func extractExpirationDate(from symbol: String?, description: String?) -> Int? {
    // Primary method: Extract 6-digit date from option symbol
    if let symbol = symbol {
        // Look for 6 consecutive digits after the underlying symbol
        // Example: "INTC  250516C00025000" -> extract "250516"
        let pattern = #"(\d{6})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: symbol, range: NSRange(symbol.startIndex..., in: symbol)) {
            let dateString = String(symbol[Range(match.range(at: 1), in: symbol)!])
            
            // Parse the date (format: YYMMDD)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyMMdd"
            formatter.timeZone = TimeZone.current
            
            if let date = formatter.date(from: dateString) {
                // Set the expiration time to 23:59:59 (end of day) in Eastern Time
                let easternTimeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
                
                // Convert the date to Eastern Time and set to 23:59:59
                var easternCalendar = Calendar.current
                easternCalendar.timeZone = easternTimeZone
                
                guard let expirationDate = easternCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) else {
                    return nil
                }
                
                let today = Date()
                let timeInterval = expirationDate.timeIntervalSince(today)
                let daysDifference = timeInterval / (24 * 60 * 60)
                
                // Round to nearest day, but be more conservative
                // If we're more than halfway through a day, round up
                let fractionalPart = daysDifference - floor(daysDifference)
                let roundedDays = fractionalPart > 0.5 ? Int(ceil(daysDifference)) : Int(floor(daysDifference))
                
                return roundedDays
            }
        }
    }
    
    // Secondary method: Extract date from description
    if let description = description {
        // Look for date pattern like "05/16/2025" or "2025-01-16"
        let patterns = [
            #"(\d{1,2})/(\d{1,2})/(\d{4})"#,  // MM/DD/YYYY
            #"(\d{4})-(\d{1,2})-(\d{1,2})"#   // YYYY-MM-DD
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) {
                
                let formatter = DateFormatter()
                if pattern.contains("/") {
                    formatter.dateFormat = "MM/dd/yyyy"
                } else {
                    formatter.dateFormat = "yyyy-MM-dd"
                }
                formatter.timeZone = TimeZone.current
                
                let dateString = String(description[Range(match.range, in: description)!])
                if let date = formatter.date(from: dateString) {
                    // Set the expiration time to 23:59:59 (end of day) in Eastern Time
                    let easternTimeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
                    
                    // Convert the date to Eastern Time and set to 23:59:59
                    var easternCalendar = Calendar.current
                    easternCalendar.timeZone = easternTimeZone
                    
                    guard let expirationDate = easternCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: date) else {
                        return nil
                    }
                    
                    let today = Date()
                    let timeInterval = expirationDate.timeIntervalSince(today)
                    let daysDifference = timeInterval / (24 * 60 * 60)
                    
                    // Round to nearest day, but be more conservative
                    // If we're more than halfway through a day, round up
                    let fractionalPart = daysDifference - floor(daysDifference)
                    let roundedDays = fractionalPart > 0.5 ? Int(ceil(daysDifference)) : Int(floor(daysDifference))
                    
                    return roundedDays
                }
            }
        }
    }
    
    return nil
}

// Test function to verify DTE calculation behavior
func testDTECalculation() {
    print("=== Testing DTE Calculation ===")
    
    // Test case: Monday evening to Friday expiration
    // Create a test date for Monday evening (e.g., 6 PM)
    let calendar = Calendar.current
    let today = Date()
    
    // Create a test expiration date for Friday
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    
    // Get next Friday
    var fridayDate = today
    while calendar.component(.weekday, from: fridayDate) != 6 { // 6 = Friday
        fridayDate = calendar.date(byAdding: .day, value: 1, to: fridayDate) ?? fridayDate
    }
    
    // Set expiration to 23:59:59 on Friday in Eastern Time
    let easternTimeZone = TimeZone(identifier: "America/New_York") ?? TimeZone.current
    var easternCalendar = Calendar.current
    easternCalendar.timeZone = easternTimeZone
    
    guard let expirationDate = easternCalendar.date(bySettingHour: 23, minute: 59, second: 59, of: fridayDate) else {
        print("Failed to create expiration date")
        return
    }
    
    let timeInterval = expirationDate.timeIntervalSince(today)
    let daysDifference = timeInterval / (24 * 60 * 60)
    
    // Round to nearest day, but be more conservative
    // If we're more than halfway through a day, round up
    let fractionalPart = daysDifference - floor(daysDifference)
    let roundedDays = fractionalPart > 0.5 ? Int(ceil(daysDifference)) : Int(floor(daysDifference))
    
    print("Today: \(today)")
    print("Expiration: \(expirationDate)")
    print("Raw days difference: \(daysDifference)")
    print("Fractional part: \(fractionalPart)")
    print("Rounded days: \(roundedDays)")
    
    // Expected: Should show appropriate days based on actual time difference
    print("Expected behavior: Should show accurate days based on time difference")
    print("Actual result: \(roundedDays) days")
}
