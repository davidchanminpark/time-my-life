//
//  TimeEntry.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftData

/// Represents accumulated time spent on an activity for a specific day
@Model
public final class TimeEntry {
    // MARK: - Properties

    /// Unique identifier for the time entry
    public var id: UUID

    /// Reference to the associated Activity
    public var activityID: UUID

    /// Date normalized to start of day (midnight)
    public var date: Date

    /// Total accumulated duration in seconds for this activity on this day
    public var totalDuration: TimeInterval

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        activityID: UUID,
        date: Date,
        totalDuration: TimeInterval = 0
    ) {
        self.id = id
        self.activityID = activityID
        // Normalize date to start of day
        self.date = Calendar.current.startOfDay(for: date)
        // Prevent negative durations
        self.totalDuration = max(0, totalDuration)
    }

    // MARK: - Methods

    /// Adds duration to the existing total duration
    /// - Parameter duration: Duration in seconds to add (negative values are ignored)
    public func addDuration(_ duration: TimeInterval) {
        // Only add positive durations
        if duration > 0 {
            self.totalDuration += duration
        }
    }

    /// Formats the total duration as HH:MM:SS
    /// - Returns: Formatted string representation of duration
    public func formattedDuration() -> String {
        return formatDuration(totalDuration)
    }

    /// Formats the total duration as MM:SS (for durations under 1 hour)
    /// - Returns: Formatted string representation of duration
    public func formattedDurationShort() -> String {
        let hours = Int(totalDuration) / 3600
        if hours > 0 {
            return formattedDuration()
        }

        let minutes = Int(totalDuration) / 60 % 60
        let seconds = Int(totalDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Private Helpers

    /// Formats a TimeInterval as HH:MM:SS
    /// - Parameter duration: Duration in seconds
    /// - Returns: Formatted string
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Static Helper Methods

public extension TimeEntry {
    /// Creates a new TimeEntry or updates an existing one for a given activity and date
    /// - Parameters:
    ///   - activityID: UUID of the activity
    ///   - date: Date for the time entry
    ///   - duration: Duration to add in seconds (negative values are clamped to 0)
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The created or updated TimeEntry
    static func createOrUpdate(
        activityID: UUID,
        date: Date,
        duration: TimeInterval,
        in context: ModelContext
    ) throws -> TimeEntry {
        // Ensure non-negative duration
        let validDuration = max(0, duration)
        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Try to find existing entry
        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID && entry.date == normalizedDate
        }

        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        let results = try context.fetch(descriptor)

        if let existingEntry = results.first {
            // Update existing entry
            existingEntry.addDuration(validDuration)
            return existingEntry
        } else {
            // Create new entry
            let newEntry = TimeEntry(
                activityID: activityID,
                date: normalizedDate,
                totalDuration: validDuration
            )
            context.insert(newEntry)
            return newEntry
        }
    }

    /// Retrieves the TimeEntry for a specific activity and date
    /// - Parameters:
    ///   - activityID: UUID of the activity
    ///   - date: Date to query
    ///   - context: ModelContext for SwiftData operations
    /// - Returns: The TimeEntry if found, nil otherwise
    static func fetch(
        activityID: UUID,
        date: Date,
        in context: ModelContext
    ) throws -> TimeEntry? {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID && entry.date == normalizedDate
        }

        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        let results = try context.fetch(descriptor)

        return results.first
    }
}

// MARK: - Codable Conformance for Syncing

extension TimeEntry: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case activityID
        case date
        case totalDuration
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(activityID, forKey: .activityID)
        try container.encode(date, forKey: .date)
        try container.encode(totalDuration, forKey: .totalDuration)
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let activityID = try container.decode(UUID.self, forKey: .activityID)
        let date = try container.decode(Date.self, forKey: .date)
        let totalDuration = try container.decode(TimeInterval.self, forKey: .totalDuration)
        
        // Use the standard initializer which handles date normalization
        self.init(
            id: id,
            activityID: activityID,
            date: date,
            totalDuration: totalDuration
        )
    }
}
