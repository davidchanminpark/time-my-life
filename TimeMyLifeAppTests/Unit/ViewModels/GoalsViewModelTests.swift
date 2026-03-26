//
//  GoalsViewModelTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

@MainActor
final class GoalsViewModelTests: XCTestCase {

    var container: ModelContainer!
    var dataService: DataService!
    var sut: GoalsViewModel!
    let cal = Calendar.current

    override func setUp() async throws {
        (container, dataService) = try makeTestDependencies()
        sut = GoalsViewModel(dataService: dataService)
    }

    override func tearDown() async throws {
        container = nil
        dataService = nil
        sut = nil
    }

    // MARK: - Seed helpers

    private func makeActivity(name: String = "Test") throws -> Activity {
        let a = Activity(name: name, colorHex: "#BFC8FF", category: "", scheduledDays: [1,2,3,4,5,6,7])
        try dataService.createActivity(a)
        return a
    }

    private func seedEntry(activityID: UUID, daysAgo: Int, seconds: TimeInterval) throws {
        let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
        try dataService.createOrUpdateTimeEntry(activityID: activityID, date: date, duration: seconds)
    }

    private func makeGoal(activityID: UUID, targetSeconds: Int = 3600, createdDaysAgo: Int = 0) throws {
        let createdDate = cal.date(byAdding: .day, value: -createdDaysAgo, to: cal.startOfDay(for: Date()))!
        try dataService.createGoal(Goal(activityID: activityID, frequency: .daily, targetSeconds: targetSeconds, createdDate: createdDate))
    }

    // MARK: - Daily streak

    func testDailyStreak_zeroWhenNoData() async throws {
        let a = try makeActivity()
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 0)
    }

    func testDailyStreak_countsTodayAlone() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 1)
    }

    func testDailyStreak_countsConsecutiveDays() async throws {
        let a = try makeActivity()
        for d in 0...4 { try seedEntry(activityID: a.id, daysAgo: d, seconds: 3600) }
        try makeGoal(activityID: a.id, createdDaysAgo: 5)

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 5)
    }

    func testDailyStreak_breaksOnMissedDay() async throws {
        let a = try makeActivity()
        // today + 2 days ago (miss yesterday)
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 2, seconds: 3600)
        try makeGoal(activityID: a.id, createdDaysAgo: 3)

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 1) // only today
    }

    func testDailyStreak_notCountedWhenBelowTarget() async throws {
        let a = try makeActivity()
        for d in 0...2 { try seedEntry(activityID: a.id, daysAgo: d, seconds: 1800) } // 30 min each
        try makeGoal(activityID: a.id, createdDaysAgo: 3)

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 0)
    }

    func testDailyStreak_startsFromLastMetDayWhenTodayNotMet() async throws {
        let a = try makeActivity()
        // Only yesterday and 2 days ago meet the target; today has no entry
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 2, seconds: 3600)
        try makeGoal(activityID: a.id, createdDaysAgo: 3)

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 2)
    }

    func testDailyStreak_skipsUnscheduledDays() async throws {
        let today = cal.startOfDay(for: Date())

        // Compute weekdays for today, 2 days ago, and 4 days ago
        let day0 = cal.component(.weekday, from: today)
        let day2 = cal.component(.weekday, from: cal.date(byAdding: .day, value: -2, to: today)!)
        let day4 = cal.component(.weekday, from: cal.date(byAdding: .day, value: -4, to: today)!)

        // Schedule activity only on those 3 weekdays
        let scheduledDays = Array(Set([day0, day2, day4]))
        let a = Activity(name: "Scheduled", colorHex: "#BFC8FF", category: "", scheduledDays: scheduledDays)
        try dataService.createActivity(a)

        // Meet goal on all 3 scheduled days (daysAgo 0, 2, 4)
        // daysAgo 1 and 3 are NOT scheduled, so they should be skipped
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 2, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 4, seconds: 3600)
        try makeGoal(activityID: a.id, createdDaysAgo: 5)

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 3)
    }

    func testDailyStreak_breaksOnMissedScheduledDay() async throws {
        let today = cal.startOfDay(for: Date())

        let day0 = cal.component(.weekday, from: today)
        let day2 = cal.component(.weekday, from: cal.date(byAdding: .day, value: -2, to: today)!)
        let day4 = cal.component(.weekday, from: cal.date(byAdding: .day, value: -4, to: today)!)

        let scheduledDays = Array(Set([day0, day2, day4]))
        let a = Activity(name: "Scheduled", colorHex: "#BFC8FF", category: "", scheduledDays: scheduledDays)
        try dataService.createActivity(a)

        // Meet goal today and 4 days ago, but MISS the scheduled day 2 days ago
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 4, seconds: 3600)
        try makeGoal(activityID: a.id, createdDaysAgo: 5)

        await sut.loadGoals()

        // Streak should be 1 (only today) because 2 days ago (a scheduled day) was missed
        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 1)
    }

    // MARK: - Daily history

    func testDailyHistory_alwaysSevenElements() async throws {
        let a = try makeActivity()
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].history.count, 7)
    }

    func testDailyHistory_reflectsMetDays() async throws {
        let a = try makeActivity()
        // Meet goal today and 6 days ago; miss everything in between
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 6, seconds: 3600)
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        let h = sut.dailyGoalsWithProgress[0].history
        // [oldest=6d ago, 5d, 4d, 3d, 2d, 1d, newest=today]
        XCTAssertTrue(h[0])
        XCTAssertFalse(h[1])
        XCTAssertFalse(h[2])
        XCTAssertFalse(h[3])
        XCTAssertFalse(h[4])
        XCTAssertFalse(h[5])
        XCTAssertTrue(h[6])
    }

    // MARK: - Progress fraction

    func testProgressFraction_halfFilled() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 1800) // 30 min out of 60 min
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].progressFraction, 0.5, accuracy: 0.001)
    }

    func testProgressFraction_overOneHundredPercent() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 7200) // 120% of 1h goal
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertGreaterThan(sut.dailyGoalsWithProgress[0].progressFraction, 1.0)
    }

    // MARK: - Weekly streak

    func testWeeklyStreak_zeroWithNoData() async throws {
        let a = try makeActivity()
        try dataService.createGoal(Goal(activityID: a.id, frequency: .weekly, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.weeklyGoalsWithProgress[0].streak, 0)
    }

    func testWeeklyStreak_countsCurrentWeek() async throws {
        let a = try makeActivity()
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 7200) // this week
        try dataService.createGoal(Goal(activityID: a.id, frequency: .weekly, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.weeklyGoalsWithProgress[0].streak, 1)
    }

    func testWeeklyStreak_countsConsecutiveWeeks() async throws {
        let a = try makeActivity()
        // Seed entries in each of the last 3 weeks
        for weeksAgo in 0...2 {
            try seedEntry(activityID: a.id, daysAgo: weeksAgo * 7, seconds: 7200)
        }
        try dataService.createGoal(Goal(activityID: a.id, frequency: .weekly, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.weeklyGoalsWithProgress[0].streak, 3)
    }

    func testWeeklyHistory_alwaysSevenElements() async throws {
        let a = try makeActivity()
        try dataService.createGoal(Goal(activityID: a.id, frequency: .weekly, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.weeklyGoalsWithProgress[0].history.count, 7)
    }
}
