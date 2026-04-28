//
//  WatchTimerSharedState.swift
//  TimeMyLifeWatchWidgets
//
//  Shared data layer between the watchOS app and its complication widget.
//  Both targets must belong to the same App Group.
//

import Foundation

/// Keys and helpers for reading/writing timer state via App Group UserDefaults.
enum WatchTimerSharedState {
    static let appGroupID = "group.chanmin.TimeMyLifeApp.watch"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Keys

    private enum Keys {
        static let isRunning = "timer_isRunning"
        static let activityName = "timer_activityName"
        static let activityEmoji = "timer_activityEmoji"
        static let activityColorHex = "timer_activityColorHex"
        static let startDate = "timer_startDate"
    }

    // MARK: - Write (called from watch app)

    static func writeRunning(
        activityName: String,
        activityEmoji: String,
        activityColorHex: String,
        startDate: Date
    ) {
        guard let defaults else { return }
        defaults.set(true, forKey: Keys.isRunning)
        defaults.set(activityName, forKey: Keys.activityName)
        defaults.set(activityEmoji, forKey: Keys.activityEmoji)
        defaults.set(activityColorHex, forKey: Keys.activityColorHex)
        defaults.set(startDate.timeIntervalSince1970, forKey: Keys.startDate)
    }

    static func writeStopped() {
        guard let defaults else { return }
        defaults.set(false, forKey: Keys.isRunning)
        defaults.removeObject(forKey: Keys.activityName)
        defaults.removeObject(forKey: Keys.activityEmoji)
        defaults.removeObject(forKey: Keys.activityColorHex)
        defaults.removeObject(forKey: Keys.startDate)
    }

    // MARK: - Read (called from widget)

    struct TimerSnapshot {
        let isRunning: Bool
        let activityName: String
        let activityEmoji: String
        let activityColorHex: String
        let startDate: Date
    }

    static func read() -> TimerSnapshot? {
        guard let defaults,
              defaults.bool(forKey: Keys.isRunning),
              let name = defaults.string(forKey: Keys.activityName),
              let colorHex = defaults.string(forKey: Keys.activityColorHex) else {
            return nil
        }

        let emoji = defaults.string(forKey: Keys.activityEmoji) ?? ""
        let startInterval = defaults.double(forKey: Keys.startDate)
        let startDate = Date(timeIntervalSince1970: startInterval)

        return TimerSnapshot(
            isRunning: true,
            activityName: name,
            activityEmoji: emoji,
            activityColorHex: colorHex,
            startDate: startDate
        )
    }
}
