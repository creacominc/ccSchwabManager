//
//  File.swift
//  ccSchwabManager
//
//

import Foundation



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

/// Start of the month-sized slice counting back from today (`monthDelta` 1 = most recent month).
func getDateNMonthsAgoStr(monthDelta: Int) -> String
{
    var components = DateComponents()
    components.month = -monthDelta
    components.day = +1
    return Calendar.current.date(byAdding: components, to: Date())!.formatted(.iso8601
        .year()
        .month()
        .day()
        .timeZone(separator: .omitted)
        .time(includingFractionalSeconds: true)
        .timeSeparator(.colon)
    )
}

/// Inclusive end of the slice that starts at `getDateNMonthsAgoStr(monthDelta: monthDelta)`.
func getDateNMonthsAgoStrForEndDate(monthDelta: Int) -> String
{
    var components = DateComponents()
    components.month = -monthDelta
    components.day = +1
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
    dateFormatter.dateFormat =  "yyyy-MM-dd HH:mm:ss"
    // Convert the date string to a Date object
    guard let date : Date = dateFormatter.date(from: dateString) else {
        dateFormatter.dateFormat = "yyyy-MM-dd"
        guard let date : Date = dateFormatter.date(from: dateString) else {
            print("Invalid date format.  date = \(dateString)")
            return nil
        }
        return( daysSinceDate( date: date ) )
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
