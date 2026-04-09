//
//  EditTimeEntryViewModelTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

@MainActor
final class EditTimeEntryViewModelTests: XCTestCase {

    var container: ModelContainer!
    var dataService: DataService!
    var activity: Activity!
    let cal = Calendar.current

    override func setUp() async throws {
        (container, dataService) = try makeTestDependencies()
        activity = Activity(
            name: "Reading",
            colorHex: "#BFC8FF",
            category: "",
            scheduledDays: [1, 2, 3, 4, 5, 6, 7]
        )
        try dataService.createActivity(activity)
    }

    override func tearDown() async throws {
        container = nil
        dataService = nil
        activity = nil
    }

    // MARK: - Helpers

    private func seedEntry(daysAgo: Int, seconds: TimeInterval) throws {
        let date = cal.date(byAdding: .day, value: -daysAgo, to: cal.startOfDay(for: Date()))!
        try dataService.createOrUpdateTimeEntry(
            activityID: activity.id,
            date: date,
            duration: seconds
        )
    }

    private func makeSut() -> EditTimeEntryViewModel {
        EditTimeEntryViewModel(activity: activity, dataService: dataService)
    }

    // MARK: - loadRecentEntries

    func test_loadRecentEntries_returnsEntriesWithinLast7DaysNewestFirst() throws {
        try seedEntry(daysAgo: 0, seconds: 3600)
        try seedEntry(daysAgo: 3, seconds: 1800)
        try seedEntry(daysAgo: 6, seconds: 1200)
        let sut = makeSut()

        sut.loadRecentEntries()

        XCTAssertEqual(sut.recentEntries.count, 3)
        XCTAssertEqual(sut.recentEntries[0].totalDuration, 3600)
        XCTAssertEqual(sut.recentEntries[1].totalDuration, 1800)
        XCTAssertEqual(sut.recentEntries[2].totalDuration, 1200)
    }

    func test_loadRecentEntries_excludesEntriesOlderThan7Days() throws {
        try seedEntry(daysAgo: 0, seconds: 3600)
        try seedEntry(daysAgo: 7, seconds: 1800)
        try seedEntry(daysAgo: 10, seconds: 600)
        let sut = makeSut()

        sut.loadRecentEntries()

        XCTAssertEqual(sut.recentEntries.count, 1)
        XCTAssertEqual(sut.recentEntries[0].totalDuration, 3600)
    }

    func test_loadRecentEntries_capsResultsAt5() throws {
        for daysAgo in 0...6 {
            try seedEntry(daysAgo: daysAgo, seconds: TimeInterval((daysAgo + 1) * 600))
        }
        let sut = makeSut()

        sut.loadRecentEntries()

        XCTAssertEqual(sut.recentEntries.count, 5)
    }

    func test_loadRecentEntries_excludesZeroDurationEntries() throws {
        try seedEntry(daysAgo: 0, seconds: 0)
        try seedEntry(daysAgo: 1, seconds: 1200)
        let sut = makeSut()

        sut.loadRecentEntries()

        XCTAssertEqual(sut.recentEntries.count, 1)
        XCTAssertEqual(sut.recentEntries[0].totalDuration, 1200)
    }

    // MARK: - selectedEntry sync

    func test_selectingEntry_prefillsHourAndMinutePickers() throws {
        // 2h 30m = 9000 seconds
        try seedEntry(daysAgo: 0, seconds: 9000)
        let sut = makeSut()
        sut.loadRecentEntries()

        sut.selectedEntry = sut.recentEntries.first

        XCTAssertEqual(sut.selectedHour, 2)
        XCTAssertEqual(sut.selectedMinute, 30)
    }

    func test_canSave_isFalseWhenDurationUnchanged() throws {
        try seedEntry(daysAgo: 0, seconds: 9000)
        let sut = makeSut()
        sut.loadRecentEntries()
        sut.selectedEntry = sut.recentEntries.first

        XCTAssertFalse(sut.canSave)
    }

    func test_canSave_isTrueWhenDurationChanged() throws {
        try seedEntry(daysAgo: 0, seconds: 9000)
        let sut = makeSut()
        sut.loadRecentEntries()
        sut.selectedEntry = sut.recentEntries.first
        sut.selectedHour = 1

        XCTAssertTrue(sut.canSave)
    }

    // MARK: - save

    func test_save_overwritesExistingEntryDuration() async throws {
        try seedEntry(daysAgo: 0, seconds: 9000)
        let sut = makeSut()
        sut.loadRecentEntries()
        sut.selectedEntry = sut.recentEntries.first
        sut.selectedHour = 1
        sut.selectedMinute = 15

        let success = await sut.save()

        XCTAssertTrue(success)
        let date = cal.startOfDay(for: Date())
        let entries = try dataService.fetchTimeEntries(for: activity.id, on: date)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].totalDuration, 4500) // 1h15m
    }

    func test_save_failsWhenNothingSelected() async {
        let sut = makeSut()

        let success = await sut.save()

        XCTAssertFalse(success)
        XCTAssertNotNil(sut.errorMessage)
    }

    func test_save_canSetDurationToZero() async throws {
        try seedEntry(daysAgo: 1, seconds: 9000)
        let sut = makeSut()
        sut.loadRecentEntries()
        sut.selectedEntry = sut.recentEntries.first
        sut.selectedHour = 0
        sut.selectedMinute = 0

        let success = await sut.save()

        XCTAssertTrue(success)
        let date = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: Date()))!
        let entries = try dataService.fetchTimeEntries(for: activity.id, on: date)
        XCTAssertEqual(entries[0].totalDuration, 0)
    }
}
