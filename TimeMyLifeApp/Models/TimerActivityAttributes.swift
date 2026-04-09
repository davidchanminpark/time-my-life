//
//  TimerActivityAttributes.swift
//  TimeMyLifeApp
//

import ActivityKit
import Foundation

/// Defines the data model for the timer Live Activity (Lock Screen + Dynamic Island).
/// Static properties are set once when the activity starts; ContentState is updated dynamically.
public struct TimerActivityAttributes: ActivityAttributes {
    // MARK: - Dynamic Content State

    public struct ContentState: Codable, Hashable {
        /// The time the timer was started (used with Text(.timerInterval:) for live counting)
        public var timerStartDate: Date
    }

    // MARK: - Static Properties (set once at start)

    /// Name of the activity being timed
    public var activityName: String

    /// Emoji icon for the activity
    public var activityEmoji: String

    /// Hex color string for the activity (e.g., "#FFB3BA")
    public var activityColorHex: String
}
