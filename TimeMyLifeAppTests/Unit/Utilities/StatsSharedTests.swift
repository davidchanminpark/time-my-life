//
//  StatsSharedTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

@MainActor
final class StatsSharedTests: XCTestCase {

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

    // MARK: - weekStart

    func test_weekStart_returnsSundayForMidweekDate() {
        // 2025-04-02 is a Wednesday (weekday 4)
        let wed = cal.date(from: DateComponents(year: 2025, month: 4, day: 2))!
        let result = StatsHelpers.weekStart(for: wed, calendar: cal)
        let expected = cal.date(from: DateComponents(year: 2025, month: 3, day: 30))! // Sunday
        XCTAssertEqual(result, expected)
    }

    func test_weekStart_returnsSameDateForSunday() {
        let sun = cal.date(from: DateComponents(year: 2025, month: 3, day: 30))!
        let result = StatsHelpers.weekStart(for: sun, calendar: cal)
        XCTAssertEqual(result, sun)
    }

    func test_weekStart_returnsSundayForSaturday() {
        // 2025-04-05 is a Saturday (weekday 7)
        let sat = cal.date(from: DateComponents(year: 2025, month: 4, day: 5))!
        let result = StatsHelpers.weekStart(for: sat, calendar: cal)
        let expected = cal.date(from: DateComponents(year: 2025, month: 3, day: 30))!
        XCTAssertEqual(result, expected)
    }

    // MARK: - buildActivityStats

    func test_buildActivityStats_aggregatesTotalsAndPercentages() throws {
        let a1 = Activity(name: "A", colorHex: "#BFC8FF", category: "", scheduledDays: [1])
        let a2 = Activity(name: "B", colorHex: "#D4BAFF", category: "", scheduledDays: [1])
        try dataService.createActivity(a1)
        try dataService.createActivity(a2)

        let today = cal.startOfDay(for: Date())
        try dataService.createOrUpdateTimeEntry(activityID: a1.id, date: today, duration: 3600)
        try dataService.createOrUpdateTimeEntry(activityID: a2.id, date: today, duration: 7200)

        let entries = try dataService.fetchTimeEntries(from: today, to: today)
        let activities = try dataService.fetchActivities()
        let result = StatsHelpers.buildActivityStats(from: entries, activities: activities)

        XCTAssertEqual(result.stats.count, 2)
        XCTAssertEqual(result.totalHours, 3.0, accuracy: 0.01) // 10800s / 3600
        XCTAssertEqual(result.trackedDays, 1)

        // Sorted descending: B (7200) first, A (3600) second
        XCTAssertEqual(result.stats.first?.activity.name, "B")
        XCTAssertEqual(result.stats.last?.activity.name, "A")

        // Percentages sum to 1
        let totalPct = result.stats.reduce(0) { $0 + $1.percentage }
        XCTAssertEqual(totalPct, 1.0, accuracy: 0.001)
    }

    func test_buildActivityStats_emptyEntries() throws {
        let a = Activity(name: "A", colorHex: "#BFC8FF", category: "", scheduledDays: [1])
        try dataService.createActivity(a)

        let result = StatsHelpers.buildActivityStats(from: [], activities: [a])

        XCTAssertTrue(result.stats.isEmpty)
        XCTAssertEqual(result.totalHours, 0)
        XCTAssertEqual(result.trackedDays, 0)
    }

    func test_buildActivityStats_excludesZeroDurationEntries() throws {
        let a = Activity(name: "A", colorHex: "#BFC8FF", category: "", scheduledDays: [1])
        try dataService.createActivity(a)

        let today = cal.startOfDay(for: Date())
        try dataService.createOrUpdateTimeEntry(activityID: a.id, date: today, duration: 0)

        let entries = try dataService.fetchTimeEntries(from: today, to: today)
        let result = StatsHelpers.buildActivityStats(from: entries, activities: [a])

        XCTAssertTrue(result.stats.isEmpty)
        XCTAssertEqual(result.totalHours, 0)
        XCTAssertEqual(result.trackedDays, 0)
    }

    func test_buildActivityStats_countsUniqueDays() throws {
        let a1 = Activity(name: "A", colorHex: "#BFC8FF", category: "", scheduledDays: [1])
        let a2 = Activity(name: "B", colorHex: "#D4BAFF", category: "", scheduledDays: [1])
        try dataService.createActivity(a1)
        try dataService.createActivity(a2)

        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        // Both activities on same day + one on yesterday
        try dataService.createOrUpdateTimeEntry(activityID: a1.id, date: today, duration: 3600)
        try dataService.createOrUpdateTimeEntry(activityID: a2.id, date: today, duration: 3600)
        try dataService.createOrUpdateTimeEntry(activityID: a1.id, date: yesterday, duration: 1800)

        let entries = try dataService.fetchTimeEntries(from: yesterday, to: today)
        let result = StatsHelpers.buildActivityStats(from: entries, activities: [a1, a2])

        XCTAssertEqual(result.trackedDays, 2)
    }
}
