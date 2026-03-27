//
//  GoalsViewModel.swift
//  TimeMyLifeApp
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class GoalsViewModel {

    // MARK: - Data Structure

    struct GoalWithProgress: Identifiable {
        let goal: Goal
        let activity: Activity?
        let currentProgress: TimeInterval   // seconds tracked in current period
        let targetSeconds: TimeInterval
        let streak: Int
        let history: [Bool]                 // last 6 periods (oldest→newest), true = goal met

        var id: UUID { goal.id }

        var progressFraction: Double {
            guard targetSeconds > 0 else { return 0 }
            return currentProgress / targetSeconds
        }

        var activityColor: Color {
            activity?.color() ?? .blue
        }
    }

    // MARK: - Observable State

    var dailyGoalsWithProgress: [GoalWithProgress] = []
    var weeklyGoalsWithProgress: [GoalWithProgress] = []
    var isLoading = false
    var error: Error?

    // MARK: - Dependencies

    private let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Load

    func loadGoals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let daily = try dataService.fetchGoals(frequency: .daily)
            let weekly = try dataService.fetchGoals(frequency: .weekly)

            dailyGoalsWithProgress = try daily.compactMap { try buildGoalWithProgress($0) }
            weeklyGoalsWithProgress = try weekly.compactMap { try buildGoalWithProgress($0) }
        } catch {
            self.error = error
        }
    }

    // MARK: - CRUD

    func createGoal(activityID: UUID, frequency: GoalFrequency, targetSeconds: Int) throws {
        let goal = Goal(activityID: activityID, frequency: frequency, targetSeconds: targetSeconds)
        try dataService.createGoal(goal)
    }

    func updateGoal(_ goal: Goal, targetSeconds: Int, isActive: Bool) throws {
        goal.targetSeconds = targetSeconds
        goal.isActive = isActive
        try dataService.updateGoal(goal)
    }

    func deleteGoal(_ goal: Goal) throws {
        try dataService.deleteGoal(goal)
    }

    // MARK: - Progress Calculation

    private func buildGoalWithProgress(_ goal: Goal) throws -> GoalWithProgress? {
        let activity = try dataService.fetchActivity(id: goal.activityID)
        let today = Calendar.current.startOfDay(for: Date())

        let currentProgress: TimeInterval
        let streak: Int
        let history: [Bool]

        switch goal.frequency {
        case .daily:
            currentProgress = try dailyProgress(activityID: goal.activityID, date: today)
            let scheduledWeekdays = Set(activity?.scheduledDayInts ?? [1,2,3,4,5,6,7])
            let catchUpPeak = try updateDailyStreak(
                goal: goal,
                scheduledWeekdays: scheduledWeekdays,
                today: today
            )
            // Stored streak counts up to yesterday; add today if it's a scheduled day and met
            let todayWeekday = Calendar.current.component(.weekday, from: today)
            let todayMet = scheduledWeekdays.contains(todayWeekday) && currentProgress >= TimeInterval(goal.targetSeconds)
            streak = goal.currentStreak + (todayMet ? 1 : 0)
            history = try dailyHistory(
                activityID: goal.activityID,
                target: TimeInterval(goal.targetSeconds),
                today: today,
                scheduledWeekdays: scheduledWeekdays
            )

            // Best streak is the max of the catch-up peak and the current streak (including today)
            let bestCount: Int
            let bestStart: Date?
            let bestEnd: Date?
            if streak > catchUpPeak.peakCount {
                let endDate = todayMet ? today : Calendar.current.date(byAdding: .day, value: -1, to: today)!
                bestCount = streak
                bestStart = walkBackScheduledDays(from: endDate, count: streak - 1, scheduledWeekdays: scheduledWeekdays)
                bestEnd = endDate
            } else {
                bestCount = catchUpPeak.peakCount
                bestStart = catchUpPeak.runStart ?? catchUpPeak.peakEnd.flatMap {
                    walkBackScheduledDays(from: $0, count: catchUpPeak.peakCount - 1, scheduledWeekdays: scheduledWeekdays)
                }
                bestEnd = catchUpPeak.peakEnd
            }
            try updateLongestDailyStreak(on: activity, count: bestCount, start: bestStart, end: bestEnd)

        case .weekly:
            let weekStart = currentWeekStart(for: today)
            currentProgress = try weeklyProgress(activityID: goal.activityID, weekStart: weekStart)
            let weeklyResult = try weeklyStreakAndHistory(
                activityID: goal.activityID,
                target: TimeInterval(goal.targetSeconds),
                today: today
            )
            streak = weeklyResult.streak
            history = weeklyResult.history
            try updateLongestWeeklyStreak(
                on: activity,
                count: weeklyResult.peakStreak,
                start: weeklyResult.peakStartWeek,
                end: weeklyResult.peakEndWeek
            )
        }

        return GoalWithProgress(
            goal: goal,
            activity: activity,
            currentProgress: currentProgress,
            targetSeconds: TimeInterval(goal.targetSeconds),
            streak: streak,
            history: history
        )
    }

    // MARK: - Daily Helpers

    private func dailyProgress(activityID: UUID, date: Date) throws -> TimeInterval {
        let entries = try dataService.fetchTimeEntries(for: activityID, on: date)
        return entries.first?.totalDuration ?? 0
    }

    /// Updates goal.currentStreak and goal.lastStreakDate by catching up from
    /// the last evaluated date (or goal creation) to yesterday.
    /// Today is excluded because it's still in progress — added at display time.
    /// Also tracks the peak streak during catch-up and updates the activity's
    /// longest daily streak if a new all-time best is found.
    /// Updates goal.currentStreak and goal.lastStreakDate by catching up from
    /// the last evaluated date (or goal creation) to yesterday.
    /// Returns the peak streak seen during the catch-up walk (count + end date + run start).
    private func updateDailyStreak(
        goal: Goal,
        scheduledWeekdays: Set<Int>,
        today: Date
    ) throws -> (peakCount: Int, peakEnd: Date?, runStart: Date?) {
        let cal = Calendar.current
        let target = TimeInterval(goal.targetSeconds)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        // Determine catch-up start: day after last evaluated, or goal creation date
        let catchUpStart: Date
        if let last = goal.lastStreakDate {
            catchUpStart = cal.date(byAdding: .day, value: 1, to: last)!
        } else {
            catchUpStart = cal.startOfDay(for: goal.createdDate)
        }

        guard catchUpStart <= yesterday else { return (goal.currentStreak, nil, nil) }

        let entries = try dataService.fetchTimeEntries(for: goal.activityID, from: catchUpStart, to: yesterday)
        let durationByDate: [Date: TimeInterval] = Dictionary(
            entries.map { ($0.date, $0.totalDuration) },
            uniquingKeysWith: { max($0, $1) }
        )

        var streak = goal.currentStreak
        var peakStreak = streak
        var peakEnd: Date? = nil
        var streakStart: Date? = nil

        var date = catchUpStart
        while date <= yesterday {
            let weekday = cal.component(.weekday, from: date)
            if scheduledWeekdays.contains(weekday) {
                if (durationByDate[date] ?? 0) >= target {
                    if streak == 0 { streakStart = date }
                    streak += 1
                    if streak > peakStreak {
                        peakStreak = streak
                        peakEnd = date
                    }
                } else {
                    streak = 0
                    streakStart = nil
                }
            }
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }

        goal.currentStreak = streak
        goal.lastStreakDate = yesterday
        try dataService.updateGoal(goal)

        return (peakStreak, peakEnd, streakStart)
    }

    /// Returns last 6 scheduled days as [Bool] (oldest → newest) for history display.
    private func dailyHistory(
        activityID: UUID,
        target: TimeInterval,
        today: Date,
        scheduledWeekdays: Set<Int>
    ) throws -> [Bool] {
        let cal = Calendar.current
        var history: [Bool] = []
        var offset = 0
        while history.count < 6 && offset < 90 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { break }
            let weekday = cal.component(.weekday, from: date)
            if scheduledWeekdays.contains(weekday) {
                let entries = try dataService.fetchTimeEntries(for: activityID, on: date)
                let duration = entries.first?.totalDuration ?? 0
                history.insert(duration >= target, at: 0)
            }
            offset += 1
        }
        return history
    }

    // MARK: - Weekly Helpers

    private func weeklyProgress(activityID: UUID, weekStart: Date) throws -> TimeInterval {
        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let entries = try dataService.fetchTimeEntries(for: activityID, from: weekStart, to: weekEnd)
        return entries.reduce(0) { $0 + $1.totalDuration }
    }

    private func weeklyStreakAndHistory(
        activityID: UUID,
        target: TimeInterval,
        today: Date
    ) throws -> (streak: Int, history: [Bool], streakEndWeekStart: Date?, peakStreak: Int, peakStartWeek: Date?, peakEndWeek: Date?) {
        let cal = Calendar.current

        // Batch fetch 52 weeks of entries (1 query instead of up to 58 per goal)
        let lookbackStart = cal.date(byAdding: .weekOfYear, value: -52, to: today) ?? today
        let entries = try dataService.fetchTimeEntries(for: activityID, from: lookbackStart, to: today)

        // Pre-build [weekStart: total] dictionary — O(N) once instead of O(N) × 58
        var weekTotals: [Date: TimeInterval] = [:]
        for entry in entries {
            let ws = currentWeekStart(for: entry.date)
            weekTotals[ws, default: 0] += entry.totalDuration
        }

        // Build last-6-weeks history (oldest → newest)
        var history: [Bool] = []
        for offset in stride(from: 5, through: 0, by: -1) {
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -offset, to: today) else { continue }
            let weekStart = currentWeekStart(for: weekDate)
            history.append((weekTotals[weekStart] ?? 0) >= target)
        }

        // Calculate current streak: consecutive weeks ending with the most recent met week
        var streak = 0
        let thisWeekStart = currentWeekStart(for: today)
        let thisWeekMet = (weekTotals[thisWeekStart] ?? 0) >= target
        let startOffset = thisWeekMet ? 0 : 1

        for offset in startOffset..<52 {
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -offset, to: today) else { break }
            let weekStart = currentWeekStart(for: weekDate)
            if (weekTotals[weekStart] ?? 0) >= target {
                streak += 1
            } else {
                break
            }
        }

        // Determine the week start where the current streak ends
        var streakEndWeekStart: Date? = nil
        if streak > 0 {
            let endOffset = thisWeekMet ? 0 : 1
            if let weekDate = cal.date(byAdding: .weekOfYear, value: -endOffset, to: today) {
                streakEndWeekStart = currentWeekStart(for: weekDate)
            }
        }

        // Find all-time longest weekly streak by scanning chronologically
        let sortedWeeks = weekTotals.keys.sorted()
        var peakStreak = streak
        var peakStartWeek: Date? = streakEndWeekStart.flatMap { cal.date(byAdding: .weekOfYear, value: -(streak - 1), to: $0) }
        var peakEndWeek: Date? = streakEndWeekStart
        var runStreak = 0
        var runStart: Date? = nil

        for (index, ws) in sortedWeeks.enumerated() {
            let met = (weekTotals[ws] ?? 0) >= target
            let isConsecutive: Bool
            if index > 0 {
                let expected = cal.date(byAdding: .weekOfYear, value: 1, to: sortedWeeks[index - 1])!
                isConsecutive = (ws == expected)
            } else {
                isConsecutive = true
            }

            if met && isConsecutive {
                if runStreak == 0 { runStart = ws }
                runStreak += 1
                if runStreak > peakStreak {
                    peakStreak = runStreak
                    peakStartWeek = runStart
                    peakEndWeek = ws
                }
            } else if met {
                runStreak = 1
                runStart = ws
                if runStreak > peakStreak {
                    peakStreak = runStreak
                    peakStartWeek = runStart
                    peakEndWeek = ws
                }
            } else {
                runStreak = 0
                runStart = nil
            }
        }

        return (streak, history, streakEndWeekStart, peakStreak, peakStartWeek, peakEndWeek)
    }

    // MARK: - Date Helpers

    private func currentWeekStart(for date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date) // 1=Sun
        let daysFromSunday = weekday - 1
        return cal.date(byAdding: .day, value: -daysFromSunday, to: cal.startOfDay(for: date)) ?? date
    }

    /// Walk back through scheduled days to find the start of a streak.
    /// From `endDate`, walks backwards `count` scheduled days.
    private func walkBackScheduledDays(from endDate: Date, count: Int, scheduledWeekdays: Set<Int>) -> Date {
        let cal = Calendar.current
        var result = endDate
        var remaining = count
        var offset = 1
        while remaining > 0 && offset < 365 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: endDate) else { break }
            let weekday = cal.component(.weekday, from: date)
            if scheduledWeekdays.contains(weekday) {
                result = date
                remaining -= 1
            }
            offset += 1
        }
        return result
    }

    // MARK: - Longest Streak Updates

    /// Updates activity's longest daily streak if the given count exceeds the cached value.
    private func updateLongestDailyStreak(on activity: Activity?, count: Int, start: Date?, end: Date?) throws {
        guard let activity, count > activity.longestDailyStreakCount else { return }
        activity.longestDailyStreakCount = count
        activity.longestDailyStreakStartDate = start
        activity.longestDailyStreakEndDate = end
        try dataService.updateActivity(activity)
    }

    /// Updates activity's longest weekly streak if the given count exceeds the cached value.
    private func updateLongestWeeklyStreak(on activity: Activity?, count: Int, start: Date?, end: Date?) throws {
        guard let activity, count > activity.longestWeeklyStreakCount else { return }
        activity.longestWeeklyStreakCount = count
        activity.longestWeeklyStreakStartDate = start
        activity.longestWeeklyStreakEndDate = end
        try dataService.updateActivity(activity)
    }
}
