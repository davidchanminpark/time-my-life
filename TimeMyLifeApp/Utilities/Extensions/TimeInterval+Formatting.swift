//
//  TimeInterval+Formatting.swift
//  TimeMyLifeCore
//

import Foundation

/// Style options for duration formatting
public enum DurationStyle {
    case automatic  // Automatically chooses format based on duration
    case short      // Always MM:SS format
    case long       // Always HH:MM:SS format
}

public extension TimeInterval {
    /// Formats the time interval as a duration string
    /// - Parameter style: The formatting style to use (default: .automatic)
    /// - Returns: Formatted string representation of the duration
    func formatted(style: DurationStyle = .automatic) -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        switch style {
        case .automatic:
            return hours > 0
                ? String(format: "%02d:%02d:%02d", hours, minutes, seconds)
                : String(format: "%02d:%02d", minutes, seconds)
        case .short:
            return String(format: "%02d:%02d", minutes, seconds)
        case .long:
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
    }
}

