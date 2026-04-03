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
        let totalDuration: TimeInterval          // current year
        let dailyAverage: TimeInterval           // total / calendar days elapsed in year
        let weeklyAverage: TimeInterval          // total / weeks elapsed in year
        let consistency: Double                  // tracked days / scheduled days (30d, clamped to yearStart)
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
    var periodBarData: [TrendPoint] = []
    var periodBarUsesWeeks = false
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

    /// Peak hours in a single period bar (for chart Y axis).
    var periodBarChartMaxHours: Double {
        periodBarData.map(\.hours).max() ?? 0
    }

    var periodBarChartYAxisTickHours: [Double] {
        StatsChartYAxis.yTickHours(
            maxHours: periodBarChartMaxHours,
            period: .weekly,
            hasData: !periodBarData.isEmpty
        )
    }

    var periodBarChartUseMinuteYAxis: Bool {
        StatsChartYAxis.useMinuteLabels(maxHours: periodBarChartMaxHours, period: .weekly)
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
        let yearStart = cal.date(from: cal.dateComponents([.year], from: today))!

        do {
            // Fetch all entries for this activity in the current year
            let yearEntries = try dataService.fetchTimeEntries(for: activity.id, from: yearStart, to: today)
            let yearNonZero = yearEntries.filter { $0.totalDuration > 0 }

            // Total Time: sum of durations in current year
            let totalDuration = yearNonZero.reduce(0.0) { $0 + $1.totalDuration }

            // Daily Average: total / calendar days elapsed in year so far
            let daysElapsed = max(1, (cal.dateComponents([.day], from: yearStart, to: today).day ?? 0) + 1)
            let dailyAvg = totalDuration / Double(daysElapsed)

            // Weekly Average: total / weeks elapsed in year so far
            let weeksElapsed = max(1.0, Double(daysElapsed) / 7.0)
            let weeklyAvg = totalDuration / weeksElapsed

            // 30-day window for consistency and goal success rate, clamped to yearStart
            let thirtyDaysAgo = max(yearStart, cal.date(byAdding: .day, value: -29, to: today)!)
            let entries30d = yearEntries.filter { $0.date >= thirtyDaysAgo }
            let recentNonZero = entries30d.filter { $0.totalDuration > 0 }
            let trackedDays30d = recentNonZero.count

            // Consistency: tracked days / scheduled days in window
            let scheduledWeekdays = Set(activity.scheduledDayInts)
            let windowDays = (cal.dateComponents([.day], from: thirtyDaysAgo, to: today).day ?? 0) + 1
            var scheduledDaysInWindow = 0
            for offset in 0..<windowDays {
                if let date = cal.date(byAdding: .day, value: offset, to: thirtyDaysAgo) {
                    if scheduledWeekdays.contains(cal.component(.weekday, from: date)) {
                        scheduledDaysInWindow += 1
                    }
                }
            }
            let consistency = scheduledDaysInWindow > 0
                ? Double(trackedDays30d) / Double(scheduledDaysInWindow) : 0

            // Goal success rate: met days / tracked days in window
            let dailyGoal = try dataService.fetchGoal(activityID: activity.id, frequency: .daily)
            var goalSuccessRate: Double? = nil
            if let goal = dailyGoal {
                let target = TimeInterval(goal.targetSeconds)
                let metDays = recentNonZero.filter { $0.totalDuration >= target }.count
                goalSuccessRate = trackedDays30d > 0 ? Double(metDays) / Double(trackedDays30d) : 0
            }

            // Longest Daily Streak (year-scoped, only if daily goal exists)
            var longestDailyCount = 0
            var longestDailyStart: Date? = nil
            var longestDailyEnd: Date? = nil
            if let goal = dailyGoal {
                let target = TimeInterval(goal.targetSeconds)
                let durationByDate = Dictionary(
                    yearNonZero.map { ($0.date, $0.totalDuration) },
                    uniquingKeysWith: { max($0, $1) }
                )
                var streak = 0
                var streakStart: Date? = nil
                var date = yearStart
                while date <= today {
                    let weekday = cal.component(.weekday, from: date)
                    if scheduledWeekdays.contains(weekday) {
                        if (durationByDate[date] ?? 0) >= target {
                            if streak == 0 { streakStart = date }
                            streak += 1
                            if streak > longestDailyCount {
                                longestDailyCount = streak
                                longestDailyStart = streakStart
                                longestDailyEnd = date
                            }
                        } else {
                            streak = 0
                            streakStart = nil
                        }
                    }
                    date = cal.date(byAdding: .day, value: 1, to: date)!
                }
            }

            // Longest Weekly Streak (year-scoped, only if weekly goal exists)
            var longestWeeklyCount = 0
            var longestWeeklyStart: Date? = nil
            var longestWeeklyEnd: Date? = nil
            let weeklyGoal = try dataService.fetchGoal(activityID: activity.id, frequency: .weekly)
            if let wGoal = weeklyGoal {
                let target = TimeInterval(wGoal.targetSeconds)
                var weekTotals: [Date: TimeInterval] = [:]
                for entry in yearNonZero {
                    let ws = StatsHelpers.weekStart(for: entry.date, calendar: cal)
                    weekTotals[ws, default: 0] += entry.totalDuration
                }
                let sortedWeeks = weekTotals.keys.sorted()
                var streak = 0
                var streakStartWeek: Date? = nil
                for (i, ws) in sortedWeeks.enumerated() {
                    let met = (weekTotals[ws] ?? 0) >= target
                    let consecutive: Bool
                    if i > 0 {
                        let expected = cal.date(byAdding: .weekOfYear, value: 1, to: sortedWeeks[i - 1])!
                        consecutive = (ws == expected)
                    } else {
                        consecutive = true
                    }
                    if met && consecutive {
                        if streak == 0 { streakStartWeek = ws }
                        streak += 1
                        if streak > longestWeeklyCount {
                            longestWeeklyCount = streak
                            longestWeeklyStart = streakStartWeek
                            longestWeeklyEnd = ws
                        }
                    } else if met {
                        streak = 1
                        streakStartWeek = ws
                        if 1 > longestWeeklyCount {
                            longestWeeklyCount = 1
                            longestWeeklyStart = ws
                            longestWeeklyEnd = ws
                        }
                    } else {
                        streak = 0
                        streakStartWeek = nil
                    }
                }
            }

            metrics = Metrics(
                totalDuration: totalDuration,
                dailyAverage: dailyAvg,
                weeklyAverage: weeklyAvg,
                consistency: consistency,
                goalSuccessRate: goalSuccessRate,
                longestDailyStreakCount: longestDailyCount,
                longestDailyStreakStartDate: longestDailyStart,
                longestDailyStreakEndDate: longestDailyEnd,
                longestWeeklyStreakCount: longestWeeklyCount,
                longestWeeklyStreakStartDate: longestWeeklyStart,
                longestWeeklyStreakEndDate: longestWeeklyEnd
            )

            // Trend: one point per day for last 30 days (clamped to yearStart)
            let entryByDate = Dictionary(uniqueKeysWithValues: entries30d.map { ($0.date, $0) })
            trendData = (0..<windowDays).compactMap { offset -> TrendPoint? in
                guard let date = cal.date(byAdding: .day, value: offset, to: thirtyDaysAgo) else { return nil }
                let hours = (entryByDate[date]?.totalDuration ?? 0) / 3600
                return TrendPoint(date: date, hours: hours)
            }

            // Period bar chart: monthly (last 12 months) or weekly (last 12 weeks, fallback for < 3 months of data)
            let monthsOfData = cal.dateComponents([.month], from: activity.createdAt, to: today).month ?? 0
            if monthsOfData >= 3 {
                // Monthly mode: last 12 months from today
                periodBarUsesWeeks = false
                let twelveMonthsAgo = cal.date(byAdding: .month, value: -11, to: today)!
                let barStartComps = cal.dateComponents([.year, .month], from: twelveMonthsAgo)
                let barStart = cal.date(from: barStartComps)!

                // Fetch entries before yearStart if the 12-month window extends into last year
                var barEntries = yearNonZero
                if barStart < yearStart {
                    let prevYearEntries = try dataService.fetchTimeEntries(
                        for: activity.id, from: barStart, to: cal.date(byAdding: .day, value: -1, to: yearStart)!
                    ).filter { $0.totalDuration > 0 }
                    barEntries = prevYearEntries + yearNonZero
                }

                var durationByMonth: [Date: TimeInterval] = [:]
                for entry in barEntries {
                    let comps = cal.dateComponents([.year, .month], from: entry.date)
                    let monthStart = cal.date(from: comps)!
                    durationByMonth[monthStart, default: 0] += entry.totalDuration
                }
                var bars: [TrendPoint] = []
                for offset in stride(from: -11, through: 0, by: 1) {
                    guard let monthDate = cal.date(byAdding: .month, value: offset, to: today) else { continue }
                    let comps = cal.dateComponents([.year, .month], from: monthDate)
                    let monthStart = cal.date(from: comps)!
                    let hours = (durationByMonth[monthStart] ?? 0) / 3600
                    bars.append(TrendPoint(date: monthStart, hours: hours))
                }
                periodBarData = bars
            } else {
                // Weekly mode: last 12 weeks from today
                periodBarUsesWeeks = true
                let twelveWeeksAgo = cal.date(byAdding: .weekOfYear, value: -11, to: today)!
                let barStart = StatsHelpers.weekStart(for: twelveWeeksAgo, calendar: cal)

                // Fetch entries before yearStart if the 12-week window extends into last year
                var barEntries = yearNonZero
                if barStart < yearStart {
                    let prevYearEntries = try dataService.fetchTimeEntries(
                        for: activity.id, from: barStart, to: cal.date(byAdding: .day, value: -1, to: yearStart)!
                    ).filter { $0.totalDuration > 0 }
                    barEntries = prevYearEntries + yearNonZero
                }

                var durationByWeek: [Date: TimeInterval] = [:]
                for entry in barEntries {
                    let ws = StatsHelpers.weekStart(for: entry.date, calendar: cal)
                    durationByWeek[ws, default: 0] += entry.totalDuration
                }
                var bars: [TrendPoint] = []
                for offset in stride(from: -11, through: 0, by: 1) {
                    guard let weekDate = cal.date(byAdding: .weekOfYear, value: offset, to: today) else { continue }
                    let ws = StatsHelpers.weekStart(for: weekDate, calendar: cal)
                    let hours = (durationByWeek[ws] ?? 0) / 3600
                    bars.append(TrendPoint(date: ws, hours: hours))
                }
                periodBarData = bars
            }

            // Recent entries: last 10 non-zero from current year, newest first
            recentEntries = yearNonZero
                .sorted { $0.date > $1.date }
                .prefix(10)
                .map { $0 }

        } catch {
            print("ActivityStatsViewModel error: \(error)")
        }
    }

}
