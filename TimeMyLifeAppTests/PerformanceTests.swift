//
//  PerformanceTests.swift
//  TimeMyLifeAppTests
//
//  Validates that ViewModels remain fast under large datasets.
//

import XCTest
import SwiftData
@testable import TimeMyLifeApp

@MainActor
final class PerformanceTests: XCTestCase {

    var container: ModelContainer!
    var dataService: DataService!
    let cal = Calendar.current

    override func setUp() async throws {
        let schema = Schema([Activity.self, TimeEntry.self, ActiveTimer.self, Goal.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        dataService = DataService(modelContext: container.mainContext)
    }

    override func tearDown() async throws {
        container = nil
        dataService = nil
    }

    // MARK: - Large Dataset Seeding

    /// Seeds 20 activities × 365 daily entries = 7,300 time entries.
    private func seedLargeDataset(year: Int) throws -> [Activity] {
        guard
            let yearStart = cal.date(from: DateComponents(year: year, month: 1, day: 1))
        else { return [] }

        var activities: [Activity] = []
        let colors = ["#BFC8FF", "#D4BAFF", "#FFCCE1", "#BAE1FF", "#FFB3BA",
                      "#C9E4CA", "#FFD6A5", "#CAFFBF", "#AED6F7", "#FDFFB6"]

        for i in 0..<20 {
            let a = Activity(
                name: "Activity \(i + 1)",
                colorHex: colors[i % colors.count],
                category: "Category \(i % 5)",
                scheduledDays: [1, 2, 3, 4, 5, 6, 7]
            )
            try dataService.createActivity(a)
            activities.append(a)

            // 365 entries — one per day of the year with varying durations
            for d in 0..<365 {
                guard let date = cal.date(byAdding: .day, value: d, to: yearStart) else { continue }
                let duration = TimeInterval((d % 4 + 1) * 900) // 15–60 min cycles
                try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date, duration: duration)
            }
        }
        return activities
    }

    // MARK: - YearlyStats Performance

    /// YearlyStatsViewModel.loadYear() should complete in < 3 s with 7,300 entries.
    func testYearlyStatsLoadYear_largeDataset() async throws {
        let year = 2024
        _ = try seedLargeDataset(year: year)
        let vm = YearlyStatsViewModel(dataService: dataService)

        let start = Date()
        await vm.loadYear(year)
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 3.0, "loadYear() took \(String(format: "%.2f", elapsed))s — expected < 3s")
        XCTAssertEqual(vm.activitiesCount, 20)
        XCTAssertFalse(vm.topActivities.isEmpty)
        XCTAssertFalse(vm.activityStreaks.isEmpty)
    }

    // MARK: - GoalsViewModel Performance

    /// GoalsViewModel.loadGoals() with 10 daily goals and batch fetching should complete in < 2 s.
    func testGoalsLoadGoals_largeDataset() async throws {
        // Create 10 activities with 90 days of entries each
        guard let lookback = cal.date(byAdding: .day, value: -90, to: cal.startOfDay(for: Date())) else { return }

        var activities: [Activity] = []
        for i in 0..<10 {
            let a = Activity(name: "Goal Act \(i)", colorHex: "#BFC8FF", category: "", scheduledDays: [1,2,3,4,5,6,7])
            try dataService.createActivity(a)
            activities.append(a)

            for d in 0..<90 {
                guard let date = cal.date(byAdding: .day, value: d, to: lookback) else { continue }
                try dataService.createOrUpdateTimeEntry(activityID: a.id, date: date, duration: 3600)
            }

            let goal = Goal(activityID: a.id, frequency: .daily, targetSeconds: 3600)
            try dataService.createGoal(goal)
        }

        let vm = GoalsViewModel(dataService: dataService)
        let start = Date()
        await vm.loadGoals()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThan(elapsed, 2.0, "loadGoals() took \(String(format: "%.2f", elapsed))s — expected < 2s")
        XCTAssertEqual(vm.dailyGoalsWithProgress.count, 10)
        // All goals should have a 90-day streak
        for goalWithProgress in vm.dailyGoalsWithProgress {
            XCTAssertGreaterThanOrEqual(goalWithProgress.streak, 1)
        }
    }

    // MARK: - DataService Range Fetch

    /// Fetching time entries for a date range across 10,000+ entries should be fast.
    func testFetchTimeEntriesRange_largeDataset() async throws {
        _ = try seedLargeDataset(year: 2024)

        let start = cal.date(from: DateComponents(year: 2024, month: 6, day: 1))!
        let end = cal.date(from: DateComponents(year: 2024, month: 6, day: 30))!

        let fetchStart = Date()
        let entries = try dataService.fetchTimeEntries(from: start, to: end)
        let elapsed = Date().timeIntervalSince(fetchStart)

        XCTAssertLessThan(elapsed, 1.0, "Range fetch took \(String(format: "%.2f", elapsed))s")
        XCTAssertFalse(entries.isEmpty)
    }
}
