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
        let totalDuration: TimeInterval          // all-time
        let dailyAverage: TimeInterval           // all-time: total / tracked days
        let weeklyAverage: TimeInterval          // all-time: total / weeks since first entry
        let consistency: Double                  // tracked days / scheduled days (30d)
        let goalSuccessRate: Double?             // met days / tracked days (30d), nil = no daily goal
        let longestDailyStreakCount: Int
        let longestDailyStreakStartDate: Date?
        let longestDailyStreakEndDate: Date?
        let longestWeeklyStreakCount: Int
        let longestWeeklyStreakStartDate: Date?
        let longestWeeklyStreakEndDate: Date?
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
        guard let thirtyDaysAgo = cal.date(byAdding: .day, value: -29, to: today) else { return }

        do {
            // All-time data
            let allEntries = try dataService.fetchAllTimeEntries(for: activity.id)
            let allNonZero = allEntries.filter { $0.totalDuration > 0 }

            let totalDuration = activity.allTimeTotalSeconds > 0
                ? activity.allTimeTotalSeconds
                : allNonZero.reduce(0.0) { $0 + $1.totalDuration }

            let allTimeTrackedDays = allNonZero.count
            let dailyAvg = allTimeTrackedDays > 0 ? totalDuration / Double(allTimeTrackedDays) : 0

            // Weekly average: total / weeks since first entry (at least 1)
            let weeklyAvg: TimeInterval
            if let firstEntry = allNonZero.min(by: { $0.date < $1.date }) {
                let daysSinceFirst = max(1, cal.dateComponents([.day], from: firstEntry.date, to: today).day ?? 1)
                let weeks = max(1.0, Double(daysSinceFirst) / 7.0)
                weeklyAvg = totalDuration / weeks
            } else {
                weeklyAvg = 0
            }

            // 30-day data for consistency and goal success rate
            let recentEntries30d = try dataService.fetchTimeEntries(for: activity.id, from: thirtyDaysAgo, to: today)
            let recentNonZero = recentEntries30d.filter { $0.totalDuration > 0 }
            let trackedDays30d = recentNonZero.count

            // Consistency: tracked days / scheduled days in last 30 days
            let scheduledWeekdays = Set(activity.scheduledDayInts)
            var scheduledDays30d = 0
            for offset in 0..<30 {
                if let date = cal.date(byAdding: .day, value: -offset, to: today) {
                    let weekday = cal.component(.weekday, from: date)
                    if scheduledWeekdays.contains(weekday) {
                        scheduledDays30d += 1
                    }
                }
            }
            let consistency = scheduledDays30d > 0 ? Double(trackedDays30d) / Double(scheduledDays30d) : 0

            // Goal success rate: met days / tracked days (30d), only if daily goal exists
            let activityGoal = try dataService.fetchGoal(activityID: activity.id, frequency: .daily)
            var goalSuccessRate: Double? = nil
            if let goal = activityGoal {
                let target = TimeInterval(goal.targetSeconds)
                let metDays = recentNonZero.filter { $0.totalDuration >= target }.count
                goalSuccessRate = trackedDays30d > 0 ? Double(metDays) / Double(trackedDays30d) : 0
            }

            metrics = Metrics(
                totalDuration: totalDuration,
                dailyAverage: dailyAvg,
                weeklyAverage: weeklyAvg,
                consistency: consistency,
                goalSuccessRate: goalSuccessRate,
                longestDailyStreakCount: activity.longestDailyStreakCount,
                longestDailyStreakStartDate: activity.longestDailyStreakStartDate,
                longestDailyStreakEndDate: activity.longestDailyStreakEndDate,
                longestWeeklyStreakCount: activity.longestWeeklyStreakCount,
                longestWeeklyStreakStartDate: activity.longestWeeklyStreakStartDate,
                longestWeeklyStreakEndDate: activity.longestWeeklyStreakEndDate
            )

            // Trend: one point per day for last 30 days (oldest → newest)
            let entryByDate = Dictionary(uniqueKeysWithValues: recentEntries30d.map { ($0.date, $0) })
            trendData = (0..<30).compactMap { offset -> TrendPoint? in
                guard let date = cal.date(byAdding: .day, value: -(29 - offset), to: today) else { return nil }
                let hours = (entryByDate[date]?.totalDuration ?? 0) / 3600
                return TrendPoint(date: date, hours: hours)
            }

            // Recent entries: last 10 non-zero, newest first
            recentEntries = allNonZero
                .sorted { $0.date > $1.date }
                .prefix(10)
                .map { $0 }

        } catch {
            print("ActivityStatsViewModel error: \(error)")
        }
    }
}
