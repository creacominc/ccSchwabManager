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
