//
//  ActivityStatsViewModelTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

@MainActor
final class ActivityStatsViewModelTests: XCTestCase {

    var container: ModelContainer!
    var dataService: DataService!
    let cal = Calendar.current

    override func setUp() async throws {
        (container, dataService) = try makeTestDependencies()
    }

    override func tearDown() async throws {
        container = nil
        dataService = nil
    }

    // MARK: - Helpers

    private func makeActivity(
        name: String = "Test",
        scheduledDays: [Int] = [1, 2, 3, 4, 5, 6, 7]
    ) throws -> Activity {
        let a = Activity(name: name, colorHex: "#BFC8FF", category: "", scheduledDays: scheduledDays)
        try dataService.createActivity(a)
        return a
    }

    private func seedEntry(activityID: UUID, daysAgo: Int, seconds: TimeInterval) throws {
        let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
        try dataService.createOrUpdateTimeEntry(activityID: activityID, date: date, duration: seconds)
    }

    private func makeSut(activity: Activity) -> ActivityStatsViewModel {
        ActivityStatsViewModel(activity: activity, dataService: dataService)
    }

    // MARK: - Total Time (year-scoped)

    func test_totalDuration_sumsCurrentYearEntries() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 5, seconds: 7200)
        try seedEntry(activityID: a.id, daysAgo: 60, seconds: 1800)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.totalDuration, 12600, accuracy: 1) // 3600+7200+1800
    }

    func test_totalDuration_excludesPreviousYearEntries() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)

        // Seed an entry in the previous year
        let today = cal.startOfDay(for: Date())
        let yearStart = cal.date(from: cal.dateComponents([.year], from: today))!
        let lastYearDate = cal.date(byAdding: .day, value: -1, to: yearStart)!
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: lastYearDate, duration: 9999)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        // Only current year entry should count
        XCTAssertEqual(metrics.totalDuration, 3600, accuracy: 1)
    }

    // MARK: - Daily Average (year-scoped, ÷ calendar days)

    func test_dailyAverage_dividesTotalByCalendarDaysElapsed() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 7200)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        // Total = 10800. Calendar days = days from Jan 1 to today (inclusive).
        let today = cal.startOfDay(for: Date())
        let yearStart = cal.date(from: cal.dateComponents([.year], from: today))!
        let daysElapsed = max(1, (cal.dateComponents([.day], from: yearStart, to: today).day ?? 0) + 1)
        let expected = 10800.0 / Double(daysElapsed)
        XCTAssertEqual(metrics.dailyAverage, expected, accuracy: 1)
    }

    func test_dailyAverage_zeroWhenNoEntries() async throws {
        let a = try makeActivity()

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.dailyAverage, 0)
    }

    // MARK: - Weekly Average (year-scoped)

    func test_weeklyAverage_dividesTotalByWeeksElapsed() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 14, seconds: 3600)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        // Total = 7200. Weeks = daysElapsed / 7.0
        let today = cal.startOfDay(for: Date())
        let yearStart = cal.date(from: cal.dateComponents([.year], from: today))!
        let daysElapsed = max(1, (cal.dateComponents([.day], from: yearStart, to: today).day ?? 0) + 1)
        let weeksElapsed = max(1.0, Double(daysElapsed) / 7.0)
        let expected = 7200.0 / weeksElapsed
        XCTAssertEqual(metrics.weeklyAverage, expected, accuracy: 1)
    }

    // MARK: - Consistency (30d)

    func test_consistency_trackedDaysOverScheduledDays() async throws {
        // Activity scheduled only on weekdays Mon-Fri (2-6)
        let a = try makeActivity(scheduledDays: [2, 3, 4, 5, 6])

        // Count how many scheduled days are in the last 30 days
        let today = cal.startOfDay(for: Date())
        let scheduledWeekdays: Set<Int> = [2, 3, 4, 5, 6]
        var scheduledDaysCount = 0
        for offset in 0..<30 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            if scheduledWeekdays.contains(cal.component(.weekday, from: date)) {
                scheduledDaysCount += 1
            }
        }

        // Seed on 5 days that are definitely scheduled
        var seeded = 0
        for offset in 0..<30 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            if scheduledWeekdays.contains(cal.component(.weekday, from: date)) && seeded < 5 {
                try seedEntry(activityID: a.id, daysAgo: offset, seconds: 3600)
                seeded += 1
            }
        }

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        let expected = Double(5) / Double(scheduledDaysCount)
        XCTAssertEqual(metrics.consistency, expected, accuracy: 0.01)
    }

    func test_consistency_oneHundredPercentWhenAllScheduledDaysTracked() async throws {
        let a = try makeActivity()

        for offset in 0..<30 {
            try seedEntry(activityID: a.id, daysAgo: offset, seconds: 3600)
        }

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.consistency, 1.0, accuracy: 0.01)
    }

    // MARK: - Goal Success Rate (30d)

    func test_goalSuccessRate_nilWhenNoDailyGoal() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertNil(metrics.goalSuccessRate)
    }

    func test_goalSuccessRate_metDaysOverTrackedDays() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)  // met
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 3600)  // met
        try seedEntry(activityID: a.id, daysAgo: 2, seconds: 1800)  // not met
        try seedEntry(activityID: a.id, daysAgo: 3, seconds: 1800)  // not met

        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(try XCTUnwrap(metrics.goalSuccessRate), 0.5, accuracy: 0.01)
    }

    // MARK: - Longest Daily Streak (year-scoped, computed on the fly)

    func test_longestDailyStreak_computedFromYearEntries() async throws {
        let a = try makeActivity()
        // 5 consecutive days meeting the goal
        for d in 0...4 { try seedEntry(activityID: a.id, daysAgo: d, seconds: 3600) }
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.longestDailyStreakCount, 5)
        XCTAssertNotNil(metrics.longestDailyStreakStartDate)
        XCTAssertNotNil(metrics.longestDailyStreakEndDate)
    }

    func test_longestDailyStreak_zeroWhenNoDailyGoal() async throws {
        let a = try makeActivity()
        for d in 0...4 { try seedEntry(activityID: a.id, daysAgo: d, seconds: 3600) }
        // No daily goal created

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.longestDailyStreakCount, 0)
        XCTAssertNil(metrics.longestDailyStreakStartDate)
    }

    func test_longestDailyStreak_findsHistoricalBest() async throws {
        let a = try makeActivity()
        let today = cal.startOfDay(for: Date())

        // Historical 5-day streak: 15–19 days ago
        for d in 15...19 { try seedEntry(activityID: a.id, daysAgo: d, seconds: 3600) }
        // Gap at day 14 (missed)
        // Current 2-day streak: today + yesterday
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 3600)

        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        // Longest should be the historical 5, not the current 2
        XCTAssertEqual(metrics.longestDailyStreakCount, 5)
        // End date should be 15 days ago (most recent day of the best streak)
        let expectedEnd = cal.date(byAdding: .day, value: -15, to: today)!
        XCTAssertEqual(metrics.longestDailyStreakEndDate, expectedEnd)
        // Start date should be 19 days ago
        let expectedStart = cal.date(byAdding: .day, value: -19, to: today)!
        XCTAssertEqual(metrics.longestDailyStreakStartDate, expectedStart)
    }

    // MARK: - Longest Weekly Streak (year-scoped, computed on the fly)

    func test_longestWeeklyStreak_computedFromYearEntries() async throws {
        let a = try makeActivity()
        for weeksAgo in 0...2 {
            try seedEntry(activityID: a.id, daysAgo: weeksAgo * 7, seconds: 7200)
        }
        try dataService.createGoal(Goal(activityID: a.id, frequency: .weekly, targetSeconds: 3600))

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.longestWeeklyStreakCount, 3)
        XCTAssertNotNil(metrics.longestWeeklyStreakStartDate)
        XCTAssertNotNil(metrics.longestWeeklyStreakEndDate)
    }

    // MARK: - Period Bar Data

    func test_periodBarData_groupsByMonth() async throws {
        let a = try makeActivity()
        // Seed entries in current month and last month
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)   // this month
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 1800)   // this month
        try seedEntry(activityID: a.id, daysAgo: 35, seconds: 7200)  // ~last month

        let sut = makeSut(activity: a)
        await sut.loadStats()

        // Should be in monthly mode (we're in March = month 3 >= 3)
        let today = cal.startOfDay(for: Date())
        let monthsInYear = cal.component(.month, from: today)
        if monthsInYear >= 3 {
            XCTAssertFalse(sut.periodBarUsesWeeks)
            XCTAssertEqual(sut.periodBarData.count, 12) // last 12 months

            // Last bar (current month) should include today's entries
            let lastBar = sut.periodBarData.last!
            XCTAssertGreaterThan(lastBar.hours, 0)
        }
    }

    func test_periodBarData_emptyWhenNoEntries() async throws {
        let a = try makeActivity()

        let sut = makeSut(activity: a)
        await sut.loadStats()

        // Bars exist (12 periods) but all zero
        let nonZeroBars = sut.periodBarData.filter { $0.hours > 0 }
        XCTAssertTrue(nonZeroBars.isEmpty)
    }

    func test_periodBarData_fallsBackToWeeksWhenLessThan3Months() async throws {
        // This test only validates behavior in Jan/Feb; skip otherwise
        let today = cal.startOfDay(for: Date())
        let monthsInYear = cal.component(.month, from: today)
        guard monthsInYear < 3 else { return } // only runs in Jan/Feb

        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        XCTAssertTrue(sut.periodBarUsesWeeks)
        XCTAssertEqual(sut.periodBarData.count, 12) // last 12 weeks
    }

    func test_longestWeeklyStreak_zeroWhenNoWeeklyGoal() async throws {
        let a = try makeActivity()
        for weeksAgo in 0...2 {
            try seedEntry(activityID: a.id, daysAgo: weeksAgo * 7, seconds: 7200)
        }
        // No weekly goal

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.longestWeeklyStreakCount, 0)
        XCTAssertNil(metrics.longestWeeklyStreakStartDate)
    }
}
