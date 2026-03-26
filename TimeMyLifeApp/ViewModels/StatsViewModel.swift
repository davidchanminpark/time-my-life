//
//  StatsViewModel.swift
//  TimeMyLifeApp
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class StatsViewModel {

    // MARK: - Types

    enum TimePeriod: Int, CaseIterable, Identifiable {
        case days7  = 7
        case days30 = 30
        case days60 = 60
        case days90 = 90

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .days7:  return "7 Days"
            case .days30: return "30 Days"
            case .days60: return "60 Days"
            case .days90: return "90 Days"
            }
        }

        var useWeeklyBars: Bool { rawValue > 7 }
    }

    struct ActivityStat: Identifiable {
        let id: UUID
        let activity: Activity
        let totalDuration: TimeInterval
        let percentage: Double          // 0.0–1.0

        var color: Color { activity.color() }
        var hours: Double { totalDuration / 3600 }
    }

    /// One segment per (period × activity) for stacked bars; `stackOrder` matches `activityStats` order (0 = bottom of stack).
    struct StackedBarSegment: Identifiable {
        var id: String { "\(periodStart.timeIntervalSince1970)-\(activityID.uuidString)" }
        let periodStart: Date
        let activityID: UUID
        let hours: Double
        let color: Color
        let stackOrder: Int
    }

    // MARK: - State

    var selectedPeriod: TimePeriod = .days7 {
        didSet { Task { await loadStats() } }
    }

    var activityStats: [ActivityStat] = []
    var stackedBarSegments: [StackedBarSegment] = [] {
        didSet { updateMaxStackedBarHours() }
    }
    private(set) var maxStackedBarHours: Double = 0
    var totalHours: Double = 0
    var trackedDays: Int = 0
    var isLoading = false

    /// Daily chart only: use minute labels on the Y axis when the tallest day is under 2 hours.
    var useMinuteAxisForDailyBarChart: Bool {
        StatsChartYAxis.useMinuteLabels(
            maxHours: maxStackedBarHours,
            period: selectedPeriod.useWeeklyBars ? .weekly : .daily
        )
    }

    /// Explicit Y tick positions (hours) for the stacked bar chart.
    var barChartYAxisTickHours: [Double] {
        StatsChartYAxis.yTickHours(
            maxHours: maxStackedBarHours,
            period: selectedPeriod.useWeeklyBars ? .weekly : .daily,
            hasData: !stackedBarSegments.isEmpty
        )
    }

    // MARK: - Init

    private let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Load

    func loadStats() async {
        isLoading = true
        defer { isLoading = false }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let startDate = cal.date(byAdding: .day, value: -(selectedPeriod.rawValue - 1), to: today) else { return }

        do {
            let activities = try dataService.fetchActivities()
            let entries = try dataService.fetchTimeEntries(from: startDate, to: today)

            // --- Activity totals (for pie chart + list) ---
            var activityTotals: [UUID: TimeInterval] = [:]
            var daysWithData = Set<Date>()
            for entry in entries where entry.totalDuration > 0 {
                activityTotals[entry.activityID, default: 0] += entry.totalDuration
                daysWithData.insert(entry.date)
            }

            let grandTotal = activityTotals.values.reduce(0, +)
            totalHours = grandTotal / 3600
            trackedDays = daysWithData.count

            let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

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

            // --- Stacked bar chart (daily or weekly) ---
            let order = activityStats.map(\.id)
            if selectedPeriod.useWeeklyBars {
                buildStackedWeeklySegments(
                    entries: entries,
                    startDate: startDate,
                    today: today,
                    cal: cal,
                    activityOrder: order,
                    activityMap: activityMap
                )
            } else {
                buildStackedDailySegments(
                    entries: entries,
                    startDate: startDate,
                    today: today,
                    cal: cal,
                    activityOrder: order,
                    activityMap: activityMap
                )
            }

        } catch {
            print("StatsViewModel error: \(error)")
        }
    }

    // MARK: - Bar Chart Data

    private func updateMaxStackedBarHours() {
        var sums: [Date: Double] = [:]
        for seg in stackedBarSegments {
            sums[seg.periodStart, default: 0] += seg.hours
        }
        maxStackedBarHours = sums.values.max() ?? 0
    }

    private func weekStart(for date: Date, cal: Calendar) -> Date {
        let weekday = cal.component(.weekday, from: date)   // 1=Sun
        return cal.date(byAdding: .day, value: -(weekday - 1), to: date) ?? date
    }

    private func buildStackedWeeklySegments(
        entries: [TimeEntry],
        startDate: Date,
        today: Date,
        cal: Calendar,
        activityOrder: [UUID],
        activityMap: [UUID: Activity]
    ) {
        guard !activityOrder.isEmpty else {
            stackedBarSegments = []
            return
        }

        var byWeek: [Date: [UUID: Double]] = [:]
        for entry in entries where entry.totalDuration > 0 {
            let weekStart = weekStart(for: entry.date, cal: cal)
            byWeek[weekStart, default: [:]][entry.activityID, default: 0] += entry.totalDuration / 3600
        }

        let firstWeek = weekStart(for: startDate, cal: cal)
        let lastWeek = weekStart(for: today, cal: cal)

        var weeks: [Date] = []
        var w = firstWeek
        while w <= lastWeek {
            weeks.append(w)
            guard let next = cal.date(byAdding: .day, value: 7, to: w) else { break }
            w = next
        }

        var segments: [StackedBarSegment] = []
        for week in weeks {
            let weekMap = byWeek[week] ?? [:]
            for (stackOrder, aid) in activityOrder.enumerated() {
                let h = weekMap[aid] ?? 0
                guard let act = activityMap[aid] else { continue }
                segments.append(
                    StackedBarSegment(
                        periodStart: week,
                        activityID: aid,
                        hours: h,
                        color: act.color(),
                        stackOrder: stackOrder
                    )
                )
            }
        }

        segments.sort {
            if $0.periodStart != $1.periodStart { return $0.periodStart < $1.periodStart }
            return $0.stackOrder < $1.stackOrder
        }
        stackedBarSegments = segments
    }

    private func buildStackedDailySegments(
        entries: [TimeEntry],
        startDate: Date,
        today: Date,
        cal: Calendar,
        activityOrder: [UUID],
        activityMap: [UUID: Activity]
    ) {
        guard !activityOrder.isEmpty else {
            stackedBarSegments = []
            return
        }

        var byDay: [Date: [UUID: Double]] = [:]
        for entry in entries where entry.totalDuration > 0 {
            let day = entry.date
            byDay[day, default: [:]][entry.activityID, default: 0] += entry.totalDuration / 3600
        }

        var days: [Date] = []
        var d = startDate
        while d <= today {
            days.append(d)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }

        var segments: [StackedBarSegment] = []
        for day in days {
            let dayMap = byDay[day] ?? [:]
            for (stackOrder, aid) in activityOrder.enumerated() {
                let h = dayMap[aid] ?? 0
                guard let act = activityMap[aid] else { continue }
                segments.append(
                    StackedBarSegment(
                        periodStart: day,
                        activityID: aid,
                        hours: h,
                        color: act.color(),
                        stackOrder: stackOrder
                    )
                )
            }
        }

        segments.sort {
            if $0.periodStart != $1.periodStart { return $0.periodStart < $1.periodStart }
            return $0.stackOrder < $1.stackOrder
        }
        stackedBarSegments = segments
    }
}
