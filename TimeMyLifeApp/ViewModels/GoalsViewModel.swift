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
            (streak, history) = try dailyStreakAndHistory(
                activityID: goal.activityID,
                target: TimeInterval(goal.targetSeconds),
                today: today
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

    private func dailyStreakAndHistory(
        activityID: UUID,
        target: TimeInterval,
        today: Date
    ) throws -> (streak: Int, history: [Bool]) {
        let cal = Calendar.current

        // Batch fetch 90 days of entries (1 query instead of up to 96 per goal)
        let lookbackStart = cal.date(byAdding: .day, value: -90, to: today) ?? today
        let entries = try dataService.fetchTimeEntries(for: activityID, from: lookbackStart, to: today)
        let durationByDate: [Date: TimeInterval] = Dictionary(
            entries.map { ($0.date, $0.totalDuration) },
            uniquingKeysWith: { max($0, $1) }
        )

        // Build last-6-days history (oldest → newest)
        var history: [Bool] = []
        for offset in stride(from: 5, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            history.append((durationByDate[date] ?? 0) >= target)
        }

        // Calculate streak: consecutive days ending with the most recent met day
        var streak = 0
        let todayMet = (durationByDate[today] ?? 0) >= target
        let startOffset = todayMet ? 0 : 1

        for offset in startOffset..<90 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { break }
            if (durationByDate[date] ?? 0) >= target {
                streak += 1
            } else {
                break
            }
        }

        return (streak, history)
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

        // Build last-6-weeks history (oldest → newest)
        var history: [Bool] = []
        for offset in stride(from: 5, through: 0, by: -1) {
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
