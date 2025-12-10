//
//  Activity.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftData
import SwiftUI

/// Validation errors for Activity model
public enum ActivityValidationError: Error, LocalizedError {
    case nameTooShort
    case nameTooLong
    case invalidHexColor
    case categoryTooLong
    case noScheduledDays
    case invalidWeekday(Int)

    public var errorDescription: String? {
        switch self {
        case .nameTooShort:
            return "Activity name must be at least 1 character"
        case .nameTooLong:
            return "Activity name must not exceed 30 characters"
        case .invalidHexColor:
            return "Invalid hex color format. Must be 6 hex characters (e.g., FF5733 or #FF5733)"
        case .categoryTooLong:
            return "Category must not exceed 20 characters"
        case .noScheduledDays:
            return "At least one day must be scheduled"
        case .invalidWeekday(let day):
            return "Invalid weekday: \(day). Must be between 1 (Sunday) and 7 (Saturday)"
        }
    }
}

/// Represents a trackable activity that can be scheduled on specific days
@Model
public final class Activity {
    // MARK: - Properties

    /// Unique identifier for the activity
    public var id: UUID

    /// Display name of the activity (max ~25 characters for watch display)
    public var name: String

    /// Hex color string for visual identification (e.g., "#FF5733")
    public var colorHex: String

    /// Category/tag for grouping activities (e.g., "music", "social", "reading")
    public var category: String

    /// Array of weekday integers where activity is scheduled (1=Sunday, 2=Monday, ..., 7=Saturday)
    public var scheduledDays: [Int]

    /// Timestamp when the activity was created
    public var createdAt: Date

    // MARK: - Initialization

    /// Standard initializer (required for SwiftData @Model macro)
    /// Note: Validation should be done BEFORE calling this initializer (e.g., in the view layer)
    public init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        category: String,
        scheduledDays: [Int],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.colorHex = Self.normalizeHex(colorHex)
        self.category = category.trimmingCharacters(in: .whitespacesAndNewlines)
        self.scheduledDays = Array(Set(scheduledDays)).sorted() // Remove duplicates
        self.createdAt = createdAt
    }

    /// Validates activity data and returns an Activity if valid
    /// Use this static method when you need validation with error messages
    public static func validated(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        category: String,
        scheduledDays: [Int],
        createdAt: Date = Date()
    ) throws -> Activity {
        // Validate name length
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ActivityValidationError.nameTooShort
        }
        guard trimmedName.count <= 30 else {
            throw ActivityValidationError.nameTooLong
        }

        // Validate and normalize hex color
        let normalizedHex = try Self.validateAndNormalizeHex(colorHex)

        // Validate category length
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCategory.count <= 20 else {
            throw ActivityValidationError.categoryTooLong
        }

        // Validate scheduled days
        guard !scheduledDays.isEmpty else {
            throw ActivityValidationError.noScheduledDays
        }

        // Validate weekday values
        let uniqueDays = Array(Set(scheduledDays)).sorted()
        for day in uniqueDays {
            guard day >= 1 && day <= 7 else {
                throw ActivityValidationError.invalidWeekday(day)
            }
        }

        // Create and return validated activity
        return Activity(
            id: id,
            name: trimmedName,
            colorHex: normalizedHex,
            category: trimmedCategory,
            scheduledDays: uniqueDays,
            createdAt: createdAt
        )
    }

    // MARK: - Validation Helpers

    /// Normalizes a hex color string (assumes it's valid)
    /// - Parameter hex: Hex color string (e.g., "#FF5733" or "FF5733")
    /// - Returns: Normalized hex string with # prefix
    private static func normalizeHex(_ hex: String) -> String {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        return "#\(hexSanitized.uppercased())"
    }

    /// Validates and normalizes a hex color string
    /// - Parameter hex: Hex color string (e.g., "#FF5733" or "FF5733")
    /// - Returns: Normalized hex string with # prefix
    /// - Throws: ActivityValidationError.invalidHexColor if invalid
    private static func validateAndNormalizeHex(_ hex: String) throws -> String {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        // Validate exactly 6 hex characters
        guard hexSanitized.count == 6 else {
            throw ActivityValidationError.invalidHexColor
        }

        // Validate all characters are valid hex
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard hexSanitized.unicodeScalars.allSatisfy({ hexCharacterSet.contains($0) }) else {
            throw ActivityValidationError.invalidHexColor
        }

        return "#\(hexSanitized.uppercased())"
    }

    // MARK: - Helper Methods

    /// Checks if the activity is scheduled for a specific weekday
    /// - Parameter weekday: Integer representing the weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
    /// - Returns: True if the activity is scheduled for the given weekday
    public func isScheduledFor(weekday: Int) -> Bool {
        return scheduledDays.contains(weekday)
    }

    /// Checks if the activity is scheduled for today
    /// - Returns: True if the activity is scheduled for today
    public func isScheduledForToday() -> Bool {
        let today = Calendar.current.component(.weekday, from: Date())
        return isScheduledFor(weekday: today)
    }

    /// Converts the hex color string to a SwiftUI Color
    /// - Returns: SwiftUI Color object, or a default color if conversion fails
    public func color() -> Color {
        return Color(hex: colorHex) ?? .blue
    }

    /// Returns the appropriate text color based on whether it's a pastel color
    /// - Returns: Dark gray for pastel colors, white for vibrant colors
    public func textColor() -> Color {
        // Pastel colors use dark gray text for better contrast
        let lightPastelColors = [
            "#FFDFBA", "#FFFFBA"
        ]
        //"#FFB3E6"
        return .white
        return lightPastelColors.contains(colorHex.uppercased()) ? Color(white: 0.5) : .white
    }
}

// MARK: - Color Extension for Hex Support

public extension Color {
    /// Initializes a Color from a hex string
    /// - Parameter hex: Hex color string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        // Validate exactly 6 hex characters
        guard hexSanitized.count == 6 else {
            return nil
        }

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }

    /// Converts a Color to hex string representation
    /// - Returns: Hex string representation (e.g., "#FF5733")
    func toHex() -> String? {
        #if os(iOS) || os(watchOS)
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }
        #else
        guard let components = NSColor(self).cgColor.components,
              components.count >= 3 else {
            return nil
        }
        #endif

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])

        return String(format: "#%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}
