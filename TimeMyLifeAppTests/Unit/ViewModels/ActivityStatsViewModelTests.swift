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

    // MARK: - Total Time (all-time)

    func test_totalDuration_sumsAllEntries() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 5, seconds: 7200)
        try seedEntry(activityID: a.id, daysAgo: 60, seconds: 1800) // outside 30d window

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.totalDuration, 12600, accuracy: 1) // 3600+7200+1800
    }

    func test_totalDuration_usesAllTimeTotalSecondsFromActivity() async throws {
        let a = try makeActivity()
        // Seed entries — createOrUpdateTimeEntry increments allTimeTotalSeconds
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 7200)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.totalDuration, 10800, accuracy: 1)
        // allTimeTotalSeconds on activity should match
        XCTAssertEqual(a.allTimeTotalSeconds, 10800, accuracy: 1)
    }

    // MARK: - Daily Average (all-time)

    func test_dailyAverage_dividesTotalByTrackedDays() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 7200)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        // (3600 + 7200) / 2 = 5400
        XCTAssertEqual(metrics.dailyAverage, 5400, accuracy: 1)
    }

    func test_dailyAverage_zeroWhenNoEntries() async throws {
        let a = try makeActivity()

        let sut = makeSut(activity: a)
        await sut.loadStats()

        // No data → metrics should be nil (ContentUnavailableView shown)
        // Actually, with all-time fetch, 0 entries → allNonZero is empty → metrics still set
        let metrics = try XCTUnwrap(sut.metrics)
        XCTAssertEqual(metrics.dailyAverage, 0)
    }

    // MARK: - Weekly Average (all-time)

    func test_weeklyAverage_dividesTotalByWeeksSinceFirst() async throws {
        let a = try makeActivity()
        // Seed entries 14 days apart (2 weeks)
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 14, seconds: 3600)

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        // 7200 total / 2 weeks = 3600
        XCTAssertEqual(metrics.weeklyAverage, 3600, accuracy: 1)
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

        // Seed entries on all 30 days (but only scheduled days count for denominator)
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
        // Schedule all 7 days
        let a = try makeActivity()

        // Seed all 30 days
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
        // 4 tracked days, 2 meet the 1h goal
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)  // met
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 3600)  // met
        try seedEntry(activityID: a.id, daysAgo: 2, seconds: 1800)  // not met
        try seedEntry(activityID: a.id, daysAgo: 3, seconds: 1800)  // not met

        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        let sut = makeSut(activity: a)
        await sut.loadStats()

        let metrics = try XCTUnwrap(sut.metrics)
        // 2 met / 4 tracked = 0.5
        XCTAssertEqual(try XCTUnwrap(metrics.goalSuccessRate), 0.5, accuracy: 0.01)
    }

    // MARK: - allTimeTotalSeconds Incremental Update

    func test_allTimeTotalSeconds_incrementsOnNewEntry() async throws {
        let a = try makeActivity()
        XCTAssertEqual(a.allTimeTotalSeconds, 0)

        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        XCTAssertEqual(a.allTimeTotalSeconds, 3600, accuracy: 1)

        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 1800)
        XCTAssertEqual(a.allTimeTotalSeconds, 5400, accuracy: 1)
    }

    func test_allTimeTotalSeconds_incrementsOnExistingEntry() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 1800) // same day, adds to existing

        XCTAssertEqual(a.allTimeTotalSeconds, 5400, accuracy: 1)
    }

    // MARK: - Longest Streak on Activity

    func test_longestDailyStreak_updatedByGoalsViewModel() async throws {
        let a = try makeActivity()
        for d in 0...4 { try seedEntry(activityID: a.id, daysAgo: d, seconds: 3600) }
        let createdDate = cal.date(byAdding: .day, value: -5, to: cal.startOfDay(for: Date()))!
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600, createdDate: createdDate))

        let goalsVM = GoalsViewModel(dataService: dataService)
        await goalsVM.loadGoals()

        XCTAssertEqual(a.longestDailyStreakCount, 5)
        XCTAssertNotNil(a.longestDailyStreakStartDate)
        XCTAssertNotNil(a.longestDailyStreakEndDate)
    }

    func test_longestWeeklyStreak_updatedByGoalsViewModel() async throws {
        let a = try makeActivity()
        for weeksAgo in 0...2 {
            try seedEntry(activityID: a.id, daysAgo: weeksAgo * 7, seconds: 7200)
        }
        try dataService.createGoal(Goal(activityID: a.id, frequency: .weekly, targetSeconds: 3600))

        let goalsVM = GoalsViewModel(dataService: dataService)
        await goalsVM.loadGoals()

        XCTAssertEqual(a.longestWeeklyStreakCount, 3)
        XCTAssertNotNil(a.longestWeeklyStreakStartDate)
        XCTAssertNotNil(a.longestWeeklyStreakEndDate)
    }

    // MARK: - Backfill

    func test_backfillActivityStats_recalculatesTotalSeconds() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 7200)

        // Manually corrupt the cached value
        a.allTimeTotalSeconds = 0
        try dataService.updateActivity(a)

        // Backfill should recalculate
        try dataService.backfillAllActivityStats()
        XCTAssertEqual(a.allTimeTotalSeconds, 10800, accuracy: 1)
    }
}
