//
//  YearlyStatsViewModelTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

@MainActor
final class YearlyStatsViewModelTests: XCTestCase {

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
