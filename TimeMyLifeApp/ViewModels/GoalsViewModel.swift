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
        var history: [Bool] = []

        // Build last-6-days history (oldest → newest)
        for offset in stride(from: 5, through: 0, by: -1) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let duration = (try? dailyProgress(activityID: activityID, date: date)) ?? 0
            history.append(duration >= target)
        }

        // Calculate streak: consecutive days ending with the most recent met day
        var streak = 0
        let todayDuration = (try? dailyProgress(activityID: activityID, date: today)) ?? 0
        let todayMet = todayDuration >= target
        let startOffset = todayMet ? 0 : 1

        for offset in startOffset..<90 {
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { break }
            let duration = (try? dailyProgress(activityID: activityID, date: date)) ?? 0
            if duration >= target {
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
        var history: [Bool] = []
        let cal = Calendar.current

        // Build last-6-weeks history (oldest → newest)
        for offset in stride(from: 5, through: 0, by: -1) {
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -offset, to: today) else { continue }
            let weekStart = currentWeekStart(for: weekDate)
            let total = (try? weeklyProgress(activityID: activityID, weekStart: weekStart)) ?? 0
            history.append(total >= target)
        }

        // Calculate streak: consecutive weeks ending with the most recent met week
        var streak = 0
        let thisWeekStart = currentWeekStart(for: today)
        let thisWeekTotal = (try? weeklyProgress(activityID: activityID, weekStart: thisWeekStart)) ?? 0
        let thisWeekMet = thisWeekTotal >= target
        let startOffset = thisWeekMet ? 0 : 1

        for offset in startOffset..<52 {
            guard let weekDate = cal.date(byAdding: .weekOfYear, value: -offset, to: today) else { break }
            let weekStart = currentWeekStart(for: weekDate)
            let total = (try? weeklyProgress(activityID: activityID, weekStart: weekStart)) ?? 0
            if total >= target {
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
