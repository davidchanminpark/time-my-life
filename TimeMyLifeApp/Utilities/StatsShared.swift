//
//  StatsShared.swift
//  TimeMyLifeApp
//

import Foundation
import SwiftUI

// MARK: - Shared Types

struct ActivityStat: Identifiable {
    let id: UUID
    let activity: Activity
    let totalDuration: TimeInterval
    let percentage: Double          // 0.0–1.0

    var color: Color { activity.color() }
    var hours: Double { totalDuration / 3600 }
}

// MARK: - Shared Helpers

enum StatsHelpers {

    /// Returns the Sunday-based week start for a given date.
    static func weekStart(for date: Date, calendar: Calendar) -> Date {
        let weekday = calendar.component(.weekday, from: date)   // 1=Sun
        return calendar.date(byAdding: .day, value: -(weekday - 1), to: calendar.startOfDay(for: date)) ?? date
    }

    /// Aggregates time entries into per-activity stats sorted by duration descending.
    /// Returns the stats array, total hours, and count of unique tracked days.
    static func buildActivityStats(
        from entries: [TimeEntry],
        activities: [Activity]
    ) -> (stats: [ActivityStat], totalHours: Double, trackedDays: Int) {
        var activityTotals: [UUID: TimeInterval] = [:]
        var daysWithData = Set<Date>()
        for entry in entries where entry.totalDuration > 0 {
            activityTotals[entry.activityID, default: 0] += entry.totalDuration
            daysWithData.insert(entry.date)
        }

        let grandTotal = activityTotals.values.reduce(0, +)
        let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })

        let stats = activityTotals.compactMap { (id, duration) -> ActivityStat? in
            guard let activity = activityMap[id], duration > 0 else { return nil }
            return ActivityStat(
                id: id,
                activity: activity,
                totalDuration: duration,
                percentage: grandTotal > 0 ? duration / grandTotal : 0
            )
        }
        .sorted { $0.totalDuration > $1.totalDuration }

        return (stats, grandTotal / 3600, daysWithData.count)
    }
}
