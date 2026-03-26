//
//  TimeMyLifeAppTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

// MARK: - Shared Setup Helper

@MainActor
private func makeTestDependencies() throws -> (ModelContainer, DataService) {
    let schema = Schema([Activity.self, TimeEntry.self, ActiveTimer.self, Goal.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    let dataService = DataService(modelContext: container.mainContext)
    return (container, dataService)
}

// MARK: - DataService CRUD Tests

@MainActor
final class DataServiceTests: XCTestCase {

    var container: ModelContainer!
    var sut: DataService!

    override func setUp() async throws {
        (container, sut) = try makeTestDependencies()
    }

    override func tearDown() async throws {
        container = nil
        sut = nil
    }

    func testCreateAndFetchActivity() throws {
        let activity = Activity(name: "Running", colorHex: "#FF5733", category: "Fitness", scheduledDays: [2, 4, 6])
        try sut.createActivity(activity)

        let fetched = try sut.fetchActivities()
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].name, "Running")
        XCTAssertEqual(fetched[0].category, "Fitness")
    }

    func testFetchActivitiesByWeekday() throws {
        let mon = Activity(name: "Mon", colorHex: "#BFC8FF", category: "", scheduledDays: [2]) // Monday
        let wed = Activity(name: "Wed", colorHex: "#BFC8FF", category: "", scheduledDays: [4]) // Wednesday
        try sut.createActivity(mon)
        try sut.createActivity(wed)

        let monActivities = try sut.fetchActivities(scheduledFor: 2)
        XCTAssertEqual(monActivities.count, 1)
        XCTAssertEqual(monActivities[0].name, "Mon")
    }

    func testDeleteActivity() throws {
        let activity = Activity(name: "Running", colorHex: "#FF5733", category: "", scheduledDays: [1])
        try sut.createActivity(activity)
        XCTAssertEqual(try sut.getActivityCount(), 1)

        try sut.deleteActivity(activity)
        XCTAssertEqual(try sut.getActivityCount(), 0)
    }

    func testDeleteActivityAlsoDeletesGoals() throws {
        let activity = Activity(name: "Running", colorHex: "#FF5733", category: "", scheduledDays: [1])
        try sut.createActivity(activity)
        let goal = Goal(activityID: activity.id, frequency: .daily, targetSeconds: 3600)
        try sut.createGoal(goal)
        XCTAssertEqual(try sut.fetchGoals(frequency: .daily).count, 1)

        try sut.deleteActivity(activity)
        XCTAssertEqual(try sut.fetchGoals(frequency: .daily).count, 0)
    }

    func testCreateOrUpdateTimeEntry_createsNewEntry() throws {
        let id = UUID()
        let date = Calendar.current.startOfDay(for: Date())
        try sut.createOrUpdateTimeEntry(activityID: id, date: date, duration: 3600)

        let entries = try sut.fetchTimeEntries(for: id, on: date)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].totalDuration, 3600)
    }

    func testCreateOrUpdateTimeEntry_accumulatesDuration() throws {
        let id = UUID()
        let date = Date()
        try sut.createOrUpdateTimeEntry(activityID: id, date: date, duration: 3600)
        try sut.createOrUpdateTimeEntry(activityID: id, date: date, duration: 1800)

        let entries = try sut.fetchTimeEntries(for: id, on: date)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].totalDuration, 5400)
    }

    func testCreateOrUpdateTimeEntry_separateEntriesPerDay() throws {
        let id = UUID()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        try sut.createOrUpdateTimeEntry(activityID: id, date: today, duration: 100)
        try sut.createOrUpdateTimeEntry(activityID: id, date: yesterday, duration: 200)

        let todayEntries = try sut.fetchTimeEntries(for: id, on: today)
        let yesterdayEntries = try sut.fetchTimeEntries(for: id, on: yesterday)
        XCTAssertEqual(todayEntries[0].totalDuration, 100)
        XCTAssertEqual(yesterdayEntries[0].totalDuration, 200)
    }

    func testFetchTimeEntriesDateRange() throws {
        let id = UUID()
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!

        try sut.createOrUpdateTimeEntry(activityID: id, date: today, duration: 100)
        try sut.createOrUpdateTimeEntry(activityID: id, date: yesterday, duration: 200)
        try sut.createOrUpdateTimeEntry(activityID: id, date: twoDaysAgo, duration: 300)

        let rangeEntries = try sut.fetchTimeEntries(for: id, from: yesterday, to: today)
        XCTAssertEqual(rangeEntries.count, 2)
    }

    func testGoalCRUD() throws {
        let activityID = UUID()
        let goal = Goal(activityID: activityID, frequency: .daily, targetSeconds: 3600)
        try sut.createGoal(goal)

        let fetched = try sut.fetchGoals(frequency: .daily)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].targetSeconds, 3600)

        goal.targetSeconds = 7200
        try sut.updateGoal(goal)
        XCTAssertEqual(try sut.fetchGoals(frequency: .daily)[0].targetSeconds, 7200)

        try sut.deleteGoal(goal)
        XCTAssertEqual(try sut.fetchGoals(frequency: .daily).count, 0)
    }

    func testGoalFetchByFrequency() throws {
        let id = UUID()
        try sut.createGoal(Goal(activityID: id, frequency: .daily, targetSeconds: 1800))
        try sut.createGoal(Goal(activityID: id, frequency: .weekly, targetSeconds: 10800))

        XCTAssertEqual(try sut.fetchGoals(frequency: .daily).count, 1)
        XCTAssertEqual(try sut.fetchGoals(frequency: .weekly).count, 1)
    }
}

// MARK: - Goal Progress & Streak Tests

@MainActor
final class GoalProgressTests: XCTestCase {

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
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 5)
    }

    func testDailyStreak_breaksOnMissedDay() async throws {
        let a = try makeActivity()
        // today + 2 days ago (miss yesterday)
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 2, seconds: 3600)
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 1) // only today
    }

    func testDailyStreak_notCountedWhenBelowTarget() async throws {
        let a = try makeActivity()
        for d in 0...2 { try seedEntry(activityID: a.id, daysAgo: d, seconds: 1800) } // 30 min each
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 0)
    }

    func testDailyStreak_startsFromLastMetDayWhenTodayNotMet() async throws {
        let a = try makeActivity()
        // Only yesterday and 2 days ago meet the target; today has no entry
        try seedEntry(activityID: a.id, daysAgo: 1, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 2, seconds: 3600)
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].streak, 2)
    }

    // MARK: - Daily history

    func testDailyHistory_alwaysSixElements() async throws {
        let a = try makeActivity()
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.dailyGoalsWithProgress[0].history.count, 6)
    }

    func testDailyHistory_reflectsMetDays() async throws {
        let a = try makeActivity()
        // Meet goal today and 5 days ago; miss everything in between
        try seedEntry(activityID: a.id, daysAgo: 0, seconds: 3600)
        try seedEntry(activityID: a.id, daysAgo: 5, seconds: 3600)
        try dataService.createGoal(Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600))

        await sut.loadGoals()

        let h = sut.dailyGoalsWithProgress[0].history
        // [oldest=5d ago, 4d, 3d, 2d, 1d, newest=today]
        XCTAssertTrue(h[0])
        XCTAssertFalse(h[1])
        XCTAssertFalse(h[2])
        XCTAssertFalse(h[3])
        XCTAssertFalse(h[4])
        XCTAssertTrue(h[5])
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

    func testWeeklyHistory_alwaysSixElements() async throws {
        let a = try makeActivity()
        try dataService.createGoal(Goal(activityID: a.id, frequency: .weekly, targetSeconds: 3600))

        await sut.loadGoals()

        XCTAssertEqual(sut.weeklyGoalsWithProgress[0].history.count, 6)
    }
}

// MARK: - Yearly Stats Tests

@MainActor
final class YearlyStatsTests: XCTestCase {

    var container: ModelContainer!
    var dataService: DataService!
    var sut: YearlyStatsViewModel!
    let cal = Calendar.current
    let testYear = 2025 // fixed past year — always safe to seed data into

    override func setUp() async throws {
        (container, dataService) = try makeTestDependencies()
        sut = YearlyStatsViewModel(dataService: dataService)
    }

    override func tearDown() async throws {
        container = nil
        dataService = nil
        sut = nil
    }

    private func date(month: Int, day: Int) -> Date {
        cal.date(from: DateComponents(year: testYear, month: month, day: day))!
    }

    func testTotalHours_aggregatesCorrectly() async throws {
        let a = Activity(name: "Test", colorHex: "#BFC8FF", category: "", scheduledDays: [1,2,3,4,5,6,7])
        try dataService.createActivity(a)
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date(month: 1, day: 10), duration: 3600)  // 1h
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date(month: 3, day: 15), duration: 7200)  // 2h

        await sut.loadYear(testYear)

        XCTAssertEqual(sut.totalHours, 3.0, accuracy: 0.01)
    }

    func testMonthlyTotals_bucketsCorrectly() async throws {
        let a = Activity(name: "Test", colorHex: "#BFC8FF", category: "", scheduledDays: [1,2,3,4,5,6,7])
        try dataService.createActivity(a)
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date(month: 1, day: 5), duration: 3600)
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date(month: 6, day: 20), duration: 7200)

        await sut.loadYear(testYear)

        XCTAssertEqual(sut.monthlyTotals[0], 1.0, accuracy: 0.001)  // January
        XCTAssertEqual(sut.monthlyTotals[5], 2.0, accuracy: 0.001)  // June
        XCTAssertEqual(sut.monthlyTotals[2], 0.0, accuracy: 0.001)  // March (empty)
    }

    func testActivitiesCount_onlyCountsActivitiesWithData() async throws {
        let a1 = Activity(name: "Act1", colorHex: "#BFC8FF", category: "", scheduledDays: [1])
        let a2 = Activity(name: "Act2", colorHex: "#D4BAFF", category: "", scheduledDays: [1])
        try dataService.createActivity(a1)
        try dataService.createActivity(a2)
        try dataService.createOrUpdateTimeEntry(activityID: a1.id, date: date(month: 2, day: 1), duration: 3600)
        // a2 has no entries

        await sut.loadYear(testYear)

        XCTAssertEqual(sut.activitiesCount, 1)
    }

    func testLongestStreak_singleConsecutiveRun() async throws {
        let a = Activity(name: "Test", colorHex: "#BFC8FF", category: "", scheduledDays: [1,2,3,4,5,6,7])
        try dataService.createActivity(a)
        for d in 1...5 {
            try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date(month: 4, day: d), duration: 3600)
        }

        await sut.loadYear(testYear)

        XCTAssertEqual(sut.activityStreaks.first?.longestStreak, 5)
    }

    func testLongestStreak_picksLongestRun() async throws {
        let a = Activity(name: "Test", colorHex: "#BFC8FF", category: "", scheduledDays: [1,2,3,4,5,6,7])
        try dataService.createActivity(a)
        // 3-day run in January
        for d in 1...3 {
            try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date(month: 1, day: d), duration: 3600)
        }
        // 7-day run in May
        for d in 5...11 {
            try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date(month: 5, day: d), duration: 3600)
        }

        await sut.loadYear(testYear)

        XCTAssertEqual(sut.activityStreaks.first?.longestStreak, 7)
    }

    func testTopActivities_rankedByHours() async throws {
        let a1 = Activity(name: "High", colorHex: "#BFC8FF", category: "", scheduledDays: [1])
        let a2 = Activity(name: "Low", colorHex: "#D4BAFF", category: "", scheduledDays: [1])
        try dataService.createActivity(a1)
        try dataService.createActivity(a2)
        try dataService.createOrUpdateTimeEntry(activityID: a1.id, date: date(month: 2, day: 1), duration: 7200) // 2h
        try dataService.createOrUpdateTimeEntry(activityID: a2.id, date: date(month: 2, day: 1), duration: 3600) // 1h

        await sut.loadYear(testYear)

        XCTAssertEqual(sut.topActivities.first?.activity.name, "High")
    }

    func testMostActiveDay_identifiedCorrectly() async throws {
        let a = Activity(name: "Test", colorHex: "#BFC8FF", category: "", scheduledDays: [1,2,3,4,5,6,7])
        try dataService.createActivity(a)
        let bigDay = date(month: 7, day: 4)
        let smallDay = date(month: 7, day: 5)
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: bigDay, duration: 10800) // 3h
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: smallDay, duration: 1800) // 0.5h

        await sut.loadYear(testYear)

        XCTAssertEqual(sut.mostActiveDay?.date, bigDay)
        XCTAssertEqual(sut.mostActiveDay?.hours ?? 0, 3.0, accuracy: 0.001)
    }

    func testEmptyYear_showsZeros() async throws {
        await sut.loadYear(testYear)

        XCTAssertEqual(sut.totalHours, 0)
        XCTAssertEqual(sut.activitiesCount, 0)
        XCTAssertTrue(sut.topActivities.isEmpty)
        XCTAssertTrue(sut.activityStreaks.isEmpty)
    }
}
