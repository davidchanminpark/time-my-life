//
//  NotificationServiceTests.swift
//  TimeMyLifeAppTests
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

@MainActor
final class NotificationServiceTests: XCTestCase {

    var container: ModelContainer!
    var dataService: DataService!
    var sut: NotificationService!

    override func setUp() async throws {
        (container, dataService) = try makeTestDependencies()
        sut = NotificationService()
    }

    override func tearDown() async throws {
        container = nil
        dataService = nil
        sut = nil
    }

    // MARK: - Goal Summary Content

    func test_noGoals_returnsSetupMessage() {
        let summary = sut.buildGoalSummary(dataService: dataService)

        XCTAssertEqual(summary.title, "Time My Life")
        XCTAssertEqual(summary.body, "Set up daily goals to track your progress!")
        XCTAssertFalse(summary.allGoalsMet)
    }

    func test_allGoalsMet_flagsAllMetAndSkipsNotification() throws {
        let activity = Activity(name: "Reading", colorHex: "#BFC8FF", category: "Learning", scheduledDays: [1, 2, 3, 4, 5, 6, 7])
        try dataService.createActivity(activity)

        let goal = Goal(activityID: activity.id, frequency: .daily, targetSeconds: 1800)
        try dataService.createGoal(goal)

        // Log 30 minutes (meets the 1800s target)
        let today = Calendar.current.startOfDay(for: Date())
        try dataService.createOrUpdateTimeEntry(activityID: activity.id, date: today, duration: 1800)

        let summary = sut.buildGoalSummary(dataService: dataService)

        // allGoalsMet = true means scheduleProgressNotifications will skip scheduling
        XCTAssertTrue(summary.allGoalsMet)
    }

    func test_someGoalsMet_sendsNotificationWithProgress() throws {
        let activity1 = Activity(name: "Reading", colorHex: "#BFC8FF", category: "Learning", scheduledDays: [1, 2, 3, 4, 5, 6, 7])
        let activity2 = Activity(name: "Exercise", colorHex: "#FFB8B8", category: "Health", scheduledDays: [1, 2, 3, 4, 5, 6, 7])
        try dataService.createActivity(activity1)
        try dataService.createActivity(activity2)

        let goal1 = Goal(activityID: activity1.id, frequency: .daily, targetSeconds: 1800)
        let goal2 = Goal(activityID: activity2.id, frequency: .daily, targetSeconds: 3600)
        try dataService.createGoal(goal1)
        try dataService.createGoal(goal2)

        // Only meet goal1
        let today = Calendar.current.startOfDay(for: Date())
        try dataService.createOrUpdateTimeEntry(activityID: activity1.id, date: today, duration: 1800)
        try dataService.createOrUpdateTimeEntry(activityID: activity2.id, date: today, duration: 600)

        let summary = sut.buildGoalSummary(dataService: dataService)

        // Notification should be sent (not all goals met)
        XCTAssertFalse(summary.allGoalsMet)
        XCTAssertEqual(summary.title, "Daily Goals: 1/2")
        XCTAssert(summary.body.contains("1 goal remaining"))
    }

    func test_noGoalsMet_sendsNotificationWithZeroProgress() throws {
        let activity = Activity(name: "Reading", colorHex: "#BFC8FF", category: "Learning", scheduledDays: [1, 2, 3, 4, 5, 6, 7])
        try dataService.createActivity(activity)

        let goal = Goal(activityID: activity.id, frequency: .daily, targetSeconds: 3600)
        try dataService.createGoal(goal)

        let summary = sut.buildGoalSummary(dataService: dataService)

        // Notification should be sent (no goals met yet)
        XCTAssertFalse(summary.allGoalsMet)
        XCTAssertEqual(summary.title, "Daily Goals: 0/1")
        XCTAssert(summary.body.contains("1 goal remaining"))
    }

    // MARK: - Settings Helpers

    func test_selectedHours_parsesStoredString() {
        let hours = NotificationService.selectedHours(from: "9,15,21")
        XCTAssertEqual(hours, [9, 15, 21])
    }

    func test_selectedHours_nilReturnsDefaults() {
        let hours = NotificationService.selectedHours(from: nil)
        XCTAssertEqual(hours, [12, 18])
    }

    func test_selectedHours_emptyReturnsDefaults() {
        let hours = NotificationService.selectedHours(from: "")
        XCTAssertEqual(hours, [12, 18])
    }

    func test_storeHours_sortedCommaString() {
        let result = NotificationService.storeHours([18, 9, 12])
        XCTAssertEqual(result, "9,12,18")
    }

    func test_formatHour_displaysCorrectly() {
        XCTAssertEqual(NotificationService.formatHour(0), "12 AM")
        XCTAssertEqual(NotificationService.formatHour(9), "9 AM")
        XCTAssertEqual(NotificationService.formatHour(12), "12 PM")
        XCTAssertEqual(NotificationService.formatHour(15), "3 PM")
        XCTAssertEqual(NotificationService.formatHour(21), "9 PM")
    }
}
