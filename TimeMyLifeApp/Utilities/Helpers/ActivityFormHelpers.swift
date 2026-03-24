//
//  ActivityFormHelpers.swift
//  TimeMyLifeCore
//

import Foundation

/// Shared helper functions for activity form validation and formatting
public enum ActivityFormHelpers {
    #if os(iOS)
    public static let availableColors: [(hex: String, name: String)] = [
        // Rainbow-ordered pastel palette (iOS expanded)
        ("#FFADAD", "Red"),
        ("#FFB3BA", "Coral"),
        ("#FFB38A", "Salmon"),
        ("#FFC8A2", "Light Salmon"),
        ("#FFD6A5", "Peach"),
        ("#FFE8A1", "Butter"),
        ("#FDFFB6", "Yellow"),
        ("#E8F5AD", "Lime"),
        ("#CAFFBF", "Mint"),
        ("#C9E4CA", "Sage"),
        ("#B5EAD7", "Seafoam"),
        ("#9BE7D5", "Teal"),
        ("#BAE1FF", "Sky Blue"),
        ("#AED6F7", "Light Blue"),
        ("#BFC8FF", "Periwinkle"),
        ("#C3B4F7", "Blue Violet"),
        ("#D4BAFF", "Lavender"),
        ("#E8B8FF", "Light Purple"),
        ("#FFBCEE", "Pink Purple"),
        ("#FFCCE1", "Pink"),
    ]
    #else
    public static let availableColors: [(hex: String, name: String)] = [
        // Compact pastel set (watchOS — readable at small sizes)
        ("#BFC8FF", "Blue"),
        ("#D4BAFF", "Lavender"),
        ("#FFCCE1", "Pink"),
        ("#BAE1FF", "Sky Blue"),
        ("#FFB3BA", "Coral"),
        ("#C9E4CA", "Sage"),
        ("#FFD6A5", "Peach"),
    ]
    #endif

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

