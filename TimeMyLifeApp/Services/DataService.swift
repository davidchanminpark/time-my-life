//
//  DataService.swift
//  TimeMyLife Watch App
//

import Foundation
import SwiftData
import Observation

/// Centralized service for all SwiftData operations
/// Provides a single source of truth for data operations across the app
@Observable
@MainActor
public class DataService {
    internal let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Activity Operations

    /// Fetches all activities, optionally filtered by weekday
    /// - Parameter weekday: Optional weekday filter (1=Sunday, 2=Monday, ..., 7=Saturday)
    /// - Returns: Array of activities matching the criteria
    public func fetchActivities(scheduledFor weekday: Int? = nil) throws -> [Activity] {
        let descriptor: FetchDescriptor<Activity>

        if let weekday = weekday {
            let predicate = #Predicate<Activity> { activity in
                activity.scheduledDays.contains(weekday)
            }
            descriptor = FetchDescriptor<Activity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.name)]
            )
        } else {
            descriptor = FetchDescriptor<Activity>(
                sortBy: [SortDescriptor(\.name)]
            )
        }

        return try modelContext.fetch(descriptor)
    }

    /// Fetches a single activity by ID
    /// - Parameter id: UUID of the activity
    /// - Returns: Activity if found, nil otherwise
    /// - Throws: Error if fetch fails
    public func fetchActivity(id: UUID) throws -> Activity? {
        let predicate = #Predicate<Activity> { activity in
            activity.id == id
        }
        let descriptor = FetchDescriptor<Activity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    /// Gets the count of all activities
    /// - Returns: Total number of activities
    /// - Throws: Error if fetch fails
    public func getActivityCount() throws -> Int {
        let descriptor = FetchDescriptor<Activity>()
        return try modelContext.fetchCount(descriptor)
    }

    /// Creates a new activity
    /// - Parameter activity: Activity to create
    /// - Throws: Error if save fails
    public func createActivity(_ activity: Activity) throws {
        modelContext.insert(activity)
        try modelContext.save()
    }

    /// Updates an existing activity
    /// - Parameter activity: Activity to update (changes are already made to the object)
    /// - Throws: Error if save fails
    public func updateActivity(_ activity: Activity) throws {
        try modelContext.save()
    }

    /// Deletes an activity and all associated time entries
    /// - Parameter activity: Activity to delete
    /// - Throws: Error if delete or save fails
    public func deleteActivity(_ activity: Activity) throws {
        // Cascade delete: Remove all TimeEntries associated with this activity
        let activityID = activity.id
        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID
        }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        let entries = try modelContext.fetch(descriptor)

        for entry in entries {
            modelContext.delete(entry)
        }

        // Delete the activity itself
        modelContext.delete(activity)
        try modelContext.save()
    }

    // MARK: - TimeEntry Operations

    /// Fetches time entries for a specific activity and date
    /// - Parameters:
    ///   - activityID: UUID of the activity
    ///   - date: Date to query (will be normalized to start of day)
    /// - Returns: Array of matching time entries (typically 0 or 1)
    public func fetchTimeEntries(for activityID: UUID, on date: Date) throws -> [TimeEntry] {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID && entry.date == normalizedDate
        }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        return try modelContext.fetch(descriptor)
    }

    /// Fetches all time entries for a specific activity
    /// - Parameter activityID: UUID of the activity
    /// - Returns: Array of all time entries for the activity
    public func fetchAllTimeEntries(for activityID: UUID) throws -> [TimeEntry] {
        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID
        }
        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Creates a new time entry or updates an existing one
    /// - Parameters:
    ///   - activityID: UUID of the activity
    ///   - date: Date for the entry (will be normalized to start of day)
    ///   - duration: Duration to add in seconds
    /// - Throws: Error if fetch or save fails
    public func createOrUpdateTimeEntry(
        activityID: UUID,
        date: Date,
        duration: TimeInterval
    ) throws {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let validDuration = max(0, duration)

        // Try to find existing entry
        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID && entry.date == normalizedDate
        }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)

        if let existingEntry = results.first {
            // Update existing entry
            existingEntry.addDuration(validDuration)
        } else {
            // Create new entry
            let newEntry = TimeEntry(
                activityID: activityID,
                date: normalizedDate,
                totalDuration: validDuration
            )
            modelContext.insert(newEntry)
        }

        try modelContext.save()
    }

    /// Deletes a time entry
    /// - Parameter entry: TimeEntry to delete
    /// - Throws: Error if save fails
    public func deleteTimeEntry(_ entry: TimeEntry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }

    // MARK: - Batch Operations

    /// Deletes all time entries for a specific activity
    /// - Parameter activityID: UUID of the activity
    /// - Returns: Number of entries deleted
    /// - Throws: Error if fetch or delete fails
    @discardableResult
    public func deleteAllTimeEntries(for activityID: UUID) throws -> Int {
        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID
        }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        let entries = try modelContext.fetch(descriptor)

        for entry in entries {
            modelContext.delete(entry)
        }

        try modelContext.save()
        return entries.count
    }

    /// Fetches all time entries within a date range
    /// - Parameters:
    ///   - activityID: Optional activity ID filter
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    /// - Returns: Array of time entries
    /// - Throws: Error if fetch fails
    public func fetchTimeEntries(
        for activityID: UUID? = nil,
        from startDate: Date,
        to endDate: Date
    ) throws -> [TimeEntry] {
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.startOfDay(for: endDate)

        let predicate: Predicate<TimeEntry>
        if let activityID = activityID {
            predicate = #Predicate<TimeEntry> { entry in
                entry.activityID == activityID &&
                entry.date >= normalizedStart &&
                entry.date <= normalizedEnd
            }
        } else {
            predicate = #Predicate<TimeEntry> { entry in
                entry.date >= normalizedStart &&
                entry.date <= normalizedEnd
            }
        }

        let descriptor = FetchDescriptor<TimeEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Gets the total duration for an activity across all time
    /// - Parameter activityID: UUID of the activity
    /// - Returns: Total duration in seconds
    /// - Throws: Error if fetch fails
    public func getTotalDuration(for activityID: UUID) throws -> TimeInterval {
        let entries = try fetchAllTimeEntries(for: activityID)
        return entries.reduce(0) { $0 + $1.totalDuration }
    }

    /// Gets the total duration for an activity within a date range
    /// - Parameters:
    ///   - activityID: UUID of the activity
    ///   - startDate: Start date (inclusive)
    ///   - endDate: End date (inclusive)
    /// - Returns: Total duration in seconds
    /// - Throws: Error if fetch fails
    public func getTotalDuration(
        for activityID: UUID,
        from startDate: Date,
        to endDate: Date
    ) throws -> TimeInterval {
        let entries = try fetchTimeEntries(for: activityID, from: startDate, to: endDate)
        return entries.reduce(0) { $0 + $1.totalDuration }
    }

    // MARK: - Utility Methods

    /// Clears all data from the database (useful for testing)
    /// NOTE: Does not reset ActiveTimer - use TimerService.reset() for that
    /// - Throws: Error if delete or save fails
    public func clearAllData() throws {
        // Delete all activities
        let activityDescriptor = FetchDescriptor<Activity>()
        let activities = try modelContext.fetch(activityDescriptor)
        for activity in activities {
            modelContext.delete(activity)
        }

        // Delete all time entries
        let timeEntryDescriptor = FetchDescriptor<TimeEntry>()
        let timeEntries = try modelContext.fetch(timeEntryDescriptor)
        for entry in timeEntries {
            modelContext.delete(entry)
        }

        try modelContext.save()
    }

    /// Checks if an activity with the given name already exists
    /// - Parameter name: Activity name to check
    /// - Returns: True if activity exists
    /// - Throws: Error if fetch fails
    public func activityExists(withName name: String) throws -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate = #Predicate<Activity> { activity in
            activity.name == trimmedName
        }
        let descriptor = FetchDescriptor<Activity>(predicate: predicate)
        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }
}

extension DataService {
    static var preview: DataService {
        let schema = Schema([Activity.self, TimeEntry.self, ActiveTimer.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return DataService(modelContext: container.mainContext)
    }
}
