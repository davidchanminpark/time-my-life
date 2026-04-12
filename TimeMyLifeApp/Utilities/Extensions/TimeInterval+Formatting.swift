//
//  TimeInterval+Formatting.swift
//  TimeMyLifeCore
//

import Foundation

/// Style options for duration formatting
public enum DurationStyle {
    /// Timer display: "02:30:05" or "30:05" (auto omits hours when zero)
    case timer
    /// Timer display: always "00:30:05" (includes hours even when zero)
    case timerLong
    /// Compact: "2h 30m", "45m", "30s" (omits zero components)
    case compact
    /// Compact without seconds: "2h 30m", "45m", "0m"
    case compactNoSeconds
    /// Verbose: "2 hours 30 minutes", "1 minute" (singular/plural aware)
    case verbose
}

public extension TimeInterval {
    /// Formats the time interval as a duration string
    /// - Parameter style: The formatting style to use (default: .timer)
    /// - Returns: Formatted string representation of the duration
    func formattedDuration(style: DurationStyle) -> String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        switch style {
        case .timer:
            return h > 0
                ? String(format: "%02d:%02d:%02d", h, m, s)
                : String(format: "%02d:%02d", m, s)
        case .timerLong:
            return String(format: "%02d:%02d:%02d", h, m, s)
        case .compact:
            if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
            if m > 0 { return s > 0 ? "\(m)m \(s)s" : "\(m)m" }
            return "\(s)s"
        case .compactNoSeconds:
            if h > 0 && m > 0 { return "\(h)h \(m)m" }
            if h > 0 { return "\(h)h" }
            return "\(m)m"
        case .verbose:
            if h > 0 && m > 0 { return "\(h) \(h == 1 ? "hour" : "hours") \(m) \(m == 1 ? "minute" : "minutes")" }
            if h > 0 { return h == 1 ? "1 hour" : "\(h) hours" }
            return m == 1 ? "1 minute" : "\(m) minutes"
        }
    }
}
