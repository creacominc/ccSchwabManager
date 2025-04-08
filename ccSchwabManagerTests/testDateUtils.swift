//
//  testDateUtils.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import Testing
import Foundation
@testable import ccSchwabManager

struct testDataUtils
{

    @Test func testGetNextTradeDate() async throws
    {
        // Set up the date formatter to match the format used in the holidays array
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        // Current date setup
        let currentDate = Date()
        let calendar = Calendar.current

        // Calculate the expected next trade date
        var expectedDate = currentDate.afterOpen().localDate()
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
        ].compactMap {
            dateFormatter.date(from: $0)
        }
        
        repeat {
            expectedDate = calendar.date(byAdding: .day, value: 1, to: expectedDate) ?? expectedDate
        } while calendar.isDateInWeekend(expectedDate) || holidays.contains { holiday in
            calendar.isDate(holiday, inSameDayAs: expectedDate)
        }

        // Get the actual next trade date
        let nextTradeDate = getNextTradeDate()

        // Assert that the calculated next trade date matches the function's result
        #expect(nextTradeDate == expectedDate, "The next trade date does not match the expected date")
    }
}
