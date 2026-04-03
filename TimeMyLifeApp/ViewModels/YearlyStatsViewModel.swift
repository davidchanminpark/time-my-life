//
//  YearlyStatsViewModel.swift
//  TimeMyLifeApp
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class YearlyStatsViewModel {

    // MARK: - Types

    struct ActivityStat: Identifiable {
        let id: UUID
        let activity: Activity
        let totalDuration: TimeInterval
        let percentage: Double

        var color: Color { activity.color() }
        var hours: Double { totalDuration / 3600 }
    }

    struct TopActivity: Identifiable {
        let id: UUID
        let activity: Activity
        let hours: Double
    }

    struct ActivityStreak: Identifiable {
        var id: UUID { activity.id }
        let activity: Activity
        let longestStreak: Int
    }

    struct CumulativePoint: Identifiable {
        var id: String { "\(date.timeIntervalSince1970)-\(activityID.uuidString)" }
        let date: Date
        let activityID: UUID
        let hours: Double
        let color: Color
        let activityName: String
    }

    // MARK: - State

    var selectedYear: Int
    var totalHours: Double = 0
    var activitiesCount: Int = 0
    var activityStats: [ActivityStat] = []
    var topActivities: [TopActivity] = []
    var activityStreaks: [ActivityStreak] = []
    var cumulativeData: [CumulativePoint] = []
    var isLoading = false

    /// Populated from `DataService.yearsWithTrackingHistory()` (earliest tracking through current year).
    var availableYears: [Int] = []

    private let dataService: DataService
    private let cal = Calendar.current

    // MARK: - Init

    init(dataService: DataService) {
        self.dataService = dataService
        let cy = Calendar.current.component(.year, from: Date())
        self.selectedYear = cy
        self.availableYears = (try? dataService.yearsWithTrackingHistory()) ?? [cy]
    }

    // MARK: - Load

    func loadYear(_ year: Int) async {
        isLoading = true
        defer { isLoading = false }

        let yearToLoad: Int
        do {
            var years = try dataService.yearsWithTrackingHistory()
            if years.isEmpty {
                let cy = cal.component(.year, from: Date())
                years = [cy]
            }
            availableYears = years
            if years.contains(year) {
                yearToLoad = year
            } else {
                yearToLoad = years.last ?? year
            }
            selectedYear = yearToLoad
        } catch {
            print("YearlyStatsViewModel error: \(error)")
            return
        }

        guard
            let yearStart = cal.date(from: DateComponents(year: yearToLoad, month: 1, day: 1)),
            let yearEnd   = cal.date(from: DateComponents(year: yearToLoad, month: 12, day: 31))
        else { return }

        do {
            let activities = try dataService.fetchActivities()
            let entries = try dataService.fetchTimeEntries(from: yearStart, to: yearEnd)

            // Aggregate
            var activityTotals: [UUID: TimeInterval] = [:]
            var entriesByActivity: [UUID: [TimeEntry]] = [:]

            for entry in entries where entry.totalDuration > 0 {
                activityTotals[entry.activityID, default: 0] += entry.totalDuration
                entriesByActivity[entry.activityID, default: []].append(entry)
            }

            let grandTotal = activityTotals.values.reduce(0, +)
            totalHours = grandTotal / 3600
            activitiesCount = activityTotals.count

            let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

            // Activity stats for pie chart
            activityStats = activityTotals.compactMap { (id, duration) -> ActivityStat? in
                guard let activity = activityMap[id], duration > 0 else { return nil }
                return ActivityStat(
                    id: id,
                    activity: activity,
                    totalDuration: duration,
                    percentage: grandTotal > 0 ? duration / grandTotal : 0
                )
            }
            .sorted { $0.totalDuration > $1.totalDuration }

            // Top activities (for share card)
            topActivities = activityStats.prefix(5).map {
                TopActivity(id: $0.id, activity: $0.activity, hours: $0.hours)
            }

            // Cumulative hours line chart data
            buildCumulativeData(
                entries: entries,
                yearStart: yearStart,
                yearEnd: yearEnd,
                activityMap: activityMap
            )

            // Longest streak per activity this year
            var streaks: [ActivityStreak] = []
            for act in activities where activityTotals[act.id] != nil {
                let actEntries = entriesByActivity[act.id] ?? []
                let s = longestStreak(from: actEntries, yearStart: yearStart, yearEnd: yearEnd)
                if s > 0 { streaks.append(ActivityStreak(activity: act, longestStreak: s)) }
            }
            activityStreaks = Array(streaks.sorted { $0.longestStreak > $1.longestStreak }.prefix(5))

        } catch {
            print("YearlyStatsViewModel error: \(error)")
        }
    }

    // MARK: - Cumulative Data

    private func buildCumulativeData(
        entries: [TimeEntry],
        yearStart: Date,
        yearEnd: Date,
        activityMap: [UUID: Activity]
    ) {
        // Group entries by activity, then by date
        var byActivityDate: [UUID: [Date: Double]] = [:]
        for entry in entries where entry.totalDuration > 0 {
            byActivityDate[entry.activityID, default: [:]][entry.date, default: 0] += entry.totalDuration / 3600
        }

        // Only include top activities (by total hours) to keep chart readable
        let topIDs = activityStats.prefix(5).map(\.id)

        // Build sorted list of all unique dates in the year that have data
        let allDates = Set(entries.map(\.date)).sorted()
        guard !allDates.isEmpty else {
            cumulativeData = []
            return
        }

        var points: [CumulativePoint] = []
        for activityID in topIDs {
            guard let act = activityMap[activityID] else { continue }
            let dateMap = byActivityDate[activityID] ?? [:]
            var cumulative: Double = 0
            for date in allDates {
                cumulative += dateMap[date] ?? 0
                points.append(CumulativePoint(
                    date: date,
                    activityID: activityID,
                    hours: cumulative,
                    color: act.color(),
                    activityName: act.name
                ))
            }
        }

        cumulativeData = points
    }

    // MARK: - Streak Calculation

    /// Computes the longest consecutive-day streak from a pre-fetched slice of entries.
    /// No DB access — caller passes the already-filtered entries for this activity.
    private func longestStreak(from entries: [TimeEntry], yearStart: Date, yearEnd: Date) -> Int {
        let trackedSet = Set(entries.filter { $0.totalDuration > 0 }.map { $0.date })

        let daysInYear = cal.dateComponents([.day], from: yearStart, to: yearEnd).day ?? 365
        var longest = 0
        var current = 0

        for d in 0...daysInYear {
            guard let date = cal.date(byAdding: .day, value: d, to: yearStart) else { break }
            if trackedSet.contains(date) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 0
            }
        }
        return longest
    }
}
