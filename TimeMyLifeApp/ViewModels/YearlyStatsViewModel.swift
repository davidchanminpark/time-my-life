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

    // MARK: - State

    var selectedYear: Int
    var totalHours: Double = 0
    var mostActiveDay: (date: Date, hours: Double)? = nil
    var activitiesCount: Int = 0
    var topActivities: [TopActivity] = []
    var activityStreaks: [ActivityStreak] = []
    /// Index 0 = January, 11 = December
    var monthlyTotals: [Double] = Array(repeating: 0, count: 12)
    var isLoading = false

    var maxMonthlyHours: Double { monthlyTotals.max() ?? 1 }

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
            var activityTotals: [UUID: Double] = [:]
            var dailyTotals: [Date: Double] = [:]
            var monthly: [Double] = Array(repeating: 0, count: 12)

            for entry in entries where entry.totalDuration > 0 {
                let h = entry.totalDuration / 3600
                activityTotals[entry.activityID, default: 0] += h
                dailyTotals[entry.date, default: 0] += h
                let month = cal.component(.month, from: entry.date) - 1   // 0-based
                monthly[month] += h
            }

            totalHours = activityTotals.values.reduce(0, +)
            monthlyTotals = monthly
            activitiesCount = activityTotals.count
            mostActiveDay = dailyTotals.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) }

            let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

            topActivities = activityTotals
                .compactMap { id, h -> TopActivity? in
                    guard let act = activityMap[id] else { return nil }
                    return TopActivity(id: id, activity: act, hours: h)
                }
                .sorted { $0.hours > $1.hours }
                .prefix(5)
                .map { $0 }

            // Longest streak per activity this year
            var streaks: [ActivityStreak] = []
            for act in activities where activityTotals[act.id] != nil {
                let s = try longestStreak(activityID: act.id, yearStart: yearStart, yearEnd: yearEnd)
                if s > 0 { streaks.append(ActivityStreak(activity: act, longestStreak: s)) }
            }
            activityStreaks = Array(streaks.sorted { $0.longestStreak > $1.longestStreak }.prefix(5))

        } catch {
            print("YearlyStatsViewModel error: \(error)")
        }
    }

    // MARK: - Streak Calculation

    private func longestStreak(activityID: UUID, yearStart: Date, yearEnd: Date) throws -> Int {
        let entries = try dataService.fetchTimeEntries(for: activityID, from: yearStart, to: yearEnd)
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
