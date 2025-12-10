//
//  ActivityFormHelpers.swift
//  TimeMyLifeCore
//

import Foundation

/// Shared helper functions for activity form validation and formatting
public enum ActivityFormHelpers {
    public static let availableColors: [(hex: String, name: String)] = [
        // Pastel colors
        ("#BFC8FF", "Blue"),
        ("#D4BAFF", "Lavender"),
        ("#FFCCE1", "Pink"),
        ("#BAE1FF", "Sky Blue"),
        ("#FFB3BA", "Coral"),
        ("#C9E4CA", "Sage"),
        ("#FFD6A5", "Peach")
    ]

    public static func colorName(for hex: String) -> String {
        availableColors.first(where: { $0.hex == hex })?.name ?? "Blue"
    }

    public static func validateName(_ name: String) -> String? {
        if name.isEmpty {
            return "Name is required"
        } else if name.count > 30 {
            return "Name must not exceed 30 characters"
        }
        return nil
    }

    public static func validateCategory(_ category: String) -> String? {
        if category.count > 20 {
            return "Category must not exceed 20 characters"
        }
        return nil
    }

    public static func formatSelectedDays(_ days: Set<Int>) -> String {
        let weekdaySymbols = Calendar.current.shortWeekdaySymbols
        guard !weekdaySymbols.isEmpty else { return "" }

        let sortedDays = days.sorted()
        let labels = sortedDays.map { day -> String in
            let rawIndex = day - 1
            let index = min(max(rawIndex, 0), weekdaySymbols.count - 1)
            return weekdaySymbols[index]
        }
        return labels.joined(separator: ", ")
    }
}

