//
//  ActivityStatsViewModel.swift
//  TimeMyLifeApp
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class ActivityStatsViewModel {

    // MARK: - Types

    struct Metrics {
        let totalDuration: TimeInterval
        let dailyAverage: TimeInterval      // per tracked day
        let weeklyAverage: TimeInterval     // total / 4.3 weeks
        let longestSession: TimeInterval
        let shortestSession: TimeInterval   // among non-zero days only
        let trackedDays: Int
        let goalCompletionPct: Double?      // nil = no active daily goal
    }

    struct TrendPoint: Identifiable {
        var id: Date { date }
        let date: Date
        let hours: Double
    }

    // MARK: - State

    var metrics: Metrics?
    var trendData: [TrendPoint] = []
    var recentEntries: [TimeEntry] = []
    var isLoading = false

    /// Peak hours in a single day over the 30-day trend (for chart Y axis).
    var trendChartMaxHours: Double {
        trendData.map(\.hours).max() ?? 0
    }

    var trendChartYAxisTickHours: [Double] {
        StatsChartYAxis.yTickHours(
            maxHours: trendChartMaxHours,
            period: .daily,
            hasData: !trendData.isEmpty
        )
    }

    var trendChartUseMinuteYAxis: Bool {
        StatsChartYAxis.useMinuteLabels(maxHours: trendChartMaxHours, period: .daily)
    }

    let activity: Activity
    private let dataService: DataService

    init(activity: Activity, dataService: DataService) {
        self.activity = activity
        self.dataService = dataService
    }

    // MARK: - Load

    func loadStats() async {
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let start = cal.date(byAdding: .day, value: -29, to: today) else { return }

        do {
            let entries = try dataService.fetchTimeEntries(for: activity.id, from: start, to: today)

            let nonZero = entries.filter { $0.totalDuration > 0 }
            let totalDuration = nonZero.reduce(0.0) { $0 + $1.totalDuration }
            let trackedDays = nonZero.count
            let dailyAvg = trackedDays > 0 ? totalDuration / Double(trackedDays) : 0
            let weeklyAvg = totalDuration / 4.3
            let longest = nonZero.map { $0.totalDuration }.max() ?? 0
            let shortest = nonZero.map { $0.totalDuration }.min() ?? 0

            // Goal completion: % of last-30 days where daily goal was met
            let activityGoal = try dataService.fetchGoal(activityID: activity.id, frequency: .daily)
            var goalPct: Double? = nil
            if let goal = activityGoal {
                let target = TimeInterval(goal.targetSeconds)
                let metDays = nonZero.filter { $0.totalDuration >= target }.count
                goalPct = Double(metDays) / 30.0
            }

            metrics = Metrics(
                totalDuration: totalDuration,
                dailyAverage: dailyAvg,
                weeklyAverage: weeklyAvg,
                longestSession: longest,
                shortestSession: shortest,
                trackedDays: trackedDays,
                goalCompletionPct: goalPct
            )

            // Trend: one point per day for last 30 days (oldest → newest)
            let entryByDate = Dictionary(uniqueKeysWithValues: entries.map { ($0.date, $0) })
            trendData = (0..<30).compactMap { offset -> TrendPoint? in
                guard let date = cal.date(byAdding: .day, value: -(29 - offset), to: today) else { return nil }
                let hours = (entryByDate[date]?.totalDuration ?? 0) / 3600
                return TrendPoint(date: date, hours: hours)
            }

            // Recent entries: last 10 non-zero, newest first
            recentEntries = nonZero
                .sorted { $0.date > $1.date }
                .prefix(10)
                .map { $0 }

        } catch {
            print("ActivityStatsViewModel error: \(error)")
        }
    }
}
