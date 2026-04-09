//
//  DataServiceTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

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

    func testSetTimeEntryDuration_overwritesExistingEntry() throws {
        let id = UUID()
        let date = Date()
        try sut.createOrUpdateTimeEntry(activityID: id, date: date, duration: 3600)

        try sut.setTimeEntryDuration(activityID: id, date: date, duration: 1800)

        let entries = try sut.fetchTimeEntries(for: id, on: date)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].totalDuration, 1800)
    }

    func testSetTimeEntryDuration_createsEntryWhenNoneExists() throws {
        let id = UUID()
        let date = Date()

        try sut.setTimeEntryDuration(activityID: id, date: date, duration: 2400)

        let entries = try sut.fetchTimeEntries(for: id, on: date)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].totalDuration, 2400)
    }

    func testSetTimeEntryDuration_clampsNegativeToZero() throws {
        let id = UUID()
        let date = Date()
        try sut.createOrUpdateTimeEntry(activityID: id, date: date, duration: 3600)

        try sut.setTimeEntryDuration(activityID: id, date: date, duration: -500)

        let entries = try sut.fetchTimeEntries(for: id, on: date)
        XCTAssertEqual(entries[0].totalDuration, 0)
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
