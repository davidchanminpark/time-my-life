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

    struct WeekdayBarSegment: Identifiable {
        var id: String { "\(weekday)-\(activityID.uuidString)" }
        let weekday: Int          // 1=Sun…7=Sat
        let activityID: UUID
        let averageHours: Double
        let color: Color
        let stackOrder: Int
    }

    // MARK: - State

    var selectedYear: Int
    var totalHours: Double = 0
    var activitiesCount: Int = 0
    var activityStats: [ActivityStat] = []
    var topActivities: [TopActivity] = []
    var activityStreaks: [ActivityStreak] = []
    var weekdayBarSegments: [WeekdayBarSegment] = []
    var maxWeekdayBarHours: Double = 0
    var isLoading = false

    var weekdayBarYAxisTickHours: [Double] {
        StatsChartYAxis.yTickHours(
            maxHours: maxWeekdayBarHours,
            period: .daily,
            hasData: !weekdayBarSegments.isEmpty
        )
    }

    var weekdayBarUseMinuteYAxis: Bool {
        StatsChartYAxis.useMinuteLabels(maxHours: maxWeekdayBarHours, period: .daily)
    }

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

            // Longest streak per activity this year
            var streaks: [ActivityStreak] = []
            for act in activities where activityTotals[act.id] != nil {
                let actEntries = entriesByActivity[act.id] ?? []
                let s = longestStreak(from: actEntries, yearStart: yearStart, yearEnd: yearEnd)
                if s > 0 { streaks.append(ActivityStreak(activity: act, longestStreak: s)) }
            }
            activityStreaks = Array(streaks.sorted { $0.longestStreak > $1.longestStreak }.prefix(5))

            // Weekday breakdown bar chart
            buildWeekdayBreakdown(entries: entries, yearStart: yearStart, yearEnd: yearEnd, activityMap: activityMap)

        } catch {
            print("YearlyStatsViewModel error: \(error)")
        }
    }

    // MARK: - Weekday Breakdown

    private func buildWeekdayBreakdown(
        entries: [TimeEntry],
        yearStart: Date,
        yearEnd: Date,
        activityMap: [UUID: Activity]
    ) {
        // Count how many times each weekday occurs in the year
        var weekdayCounts: [Int: Int] = [:]  // weekday -> count
        var d = yearStart
        let today = cal.startOfDay(for: Date())
        let endBound = min(yearEnd, today)
        while d <= endBound {
            let wd = cal.component(.weekday, from: d)
            weekdayCounts[wd, default: 0] += 1
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }

        // Group total hours by (weekday, activityID)
        var byWeekdayActivity: [Int: [UUID: Double]] = [:]
        for entry in entries where entry.totalDuration > 0 {
            let wd = cal.component(.weekday, from: entry.date)
            byWeekdayActivity[wd, default: [:]][entry.activityID, default: 0] += entry.totalDuration / 3600
        }

        let order = activityStats.map(\.id)
        guard !order.isEmpty else {
            weekdayBarSegments = []
            maxWeekdayBarHours = 0
            return
        }

        var segments: [WeekdayBarSegment] = []
        var maxStacked: Double = 0

        for wd in 1...7 {
            let count = Double(weekdayCounts[wd] ?? 1)
            let actMap = byWeekdayActivity[wd] ?? [:]
            var dayTotal: Double = 0
            for (stackOrder, aid) in order.enumerated() {
                let avg = (actMap[aid] ?? 0) / count
                guard let act = activityMap[aid] else { continue }
                segments.append(WeekdayBarSegment(
                    weekday: wd,
                    activityID: aid,
                    averageHours: avg,
                    color: act.color(),
                    stackOrder: stackOrder
                ))
                dayTotal += avg
            }
            maxStacked = max(maxStacked, dayTotal)
        }

        segments.sort {
            if $0.weekday != $1.weekday { return $0.weekday < $1.weekday }
            return $0.stackOrder < $1.stackOrder
        }
        weekdayBarSegments = segments
        maxWeekdayBarHours = maxStacked
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
