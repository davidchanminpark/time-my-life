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
        let history: [Bool]                 // last 7 periods (oldest→newest), true = goal met

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
    var alertMessage: String?

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
            alertMessage = "Failed to load goals"
            #if DEBUG
            print("❌ GoalsViewModel: Failed to load goals: \(error)")
            #endif
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

    func moveDailyGoals(from source: IndexSet, to destination: Int) {
        dailyGoalsWithProgress.move(fromOffsets: source, toOffset: destination)
        let goals = dailyGoalsWithProgress.map(\.goal)
        try? dataService.reorderGoals(goals)
    }

    func moveWeeklyGoals(from source: IndexSet, to destination: Int) {
        weeklyGoalsWithProgress.move(fromOffsets: source, toOffset: destination)
        let goals = weeklyGoalsWithProgress.map(\.goal)
        try? dataService.reorderGoals(goals)
    }

    func saveDailyGoalOrder() {
        let goals = dailyGoalsWithProgress.map(\.goal)
        try? dataService.reorderGoals(goals)
    }

    func saveWeeklyGoalOrder() {
        let goals = weeklyGoalsWithProgress.map(\.goal)
        try? dataService.reorderGoals(goals)
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
            try updateDailyStreak(
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

        case .weekly:
            let weekStart = currentWeekStart(for: today)
            currentProgress = try weeklyProgress(activityID: goal.activityID, weekStart: weekStart)
            (streak, history) = try weeklyStreakAndHistory(
                activityID: goal.activityID,
                target: TimeInterval(goal.targetSeconds),
                today: today
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
    private func updateDailyStreak(
        goal: Goal,
        scheduledWeekdays: Set<Int>,
        today: Date
    ) throws {
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

        guard catchUpStart <= yesterday else { return }

        let entries = try dataService.fetchTimeEntries(for: goal.activityID, from: catchUpStart, to: yesterday)
        let durationByDate: [Date: TimeInterval] = Dictionary(
            entries.map { ($0.date, $0.totalDuration) },
            uniquingKeysWith: { max($0, $1) }
        )

        var streak = goal.currentStreak
        var date = catchUpStart
        while date <= yesterday {
            let weekday = cal.component(.weekday, from: date)
            if scheduledWeekdays.contains(weekday) {
                if (durationByDate[date] ?? 0) >= target {
                    streak += 1
                } else {
                    streak = 0
                }
            }
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }

        goal.currentStreak = streak
        goal.lastStreakDate = yesterday
        try dataService.updateGoal(goal)
    }

    /// Returns last 7 scheduled days as [Bool] (oldest → newest) for history display.
    private func dailyHistory(
        activityID: UUID,
        target: TimeInterval,
        today: Date,
        scheduledWeekdays: Set<Int>
    ) throws -> [Bool] {
        let cal = Calendar.current
        var history: [Bool] = []
        var offset = 0
        while history.count < 7 && offset < 90 {
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
    ) throws -> (streak: Int, history: [Bool]) {
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

        // Build last-7-weeks history (oldest → newest)
        var history: [Bool] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -offset, to: today) else { continue }
            let weekStart = currentWeekStart(for: weekDate)
            history.append((weekTotals[weekStart] ?? 0) >= target)
        }

        // Calculate streak: consecutive weeks ending with the most recent met week
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

        return (streak, history)
    }

    // MARK: - Date Helpers

    private func currentWeekStart(for date: Date) -> Date {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date) // 1=Sun
        let daysFromSunday = weekday - 1
        return cal.date(byAdding: .day, value: -daysFromSunday, to: cal.startOfDay(for: date)) ?? date
    }
}
