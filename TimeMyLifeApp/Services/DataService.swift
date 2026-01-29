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
    private var syncService: SyncService?
    
    public init(modelContext: ModelContext, syncService: SyncService? = nil) {
        self.modelContext = modelContext
        self.syncService = syncService
        setupSyncHandlers()
    }
    
    private func setupSyncHandlers() {
        syncService?.onSyncMessageReceived = { [weak self] message in
            Task { @MainActor in
                await self?.handleReceivedSyncMessage(message)
            }
        }

        // Listen for full sync requests
        NotificationCenter.default.addObserver(
            forName: .fullSyncRequested,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleFullSyncRequest()
            }
        }
    }

    private func handleFullSyncRequest() async {
        #if DEBUG
        print("🔄 Handling full sync request - sending all activities")
        #endif

        do {
            // Send all activities
            let activities = try fetchActivities()
            for activity in activities {
                try? await syncService?.syncModel(activity, type: .activity, action: .create)
            }

            #if DEBUG
            print("✅ Sent \(activities.count) activities for full sync")
            #endif
        } catch {
            print("❌ Error during full sync: \(error)")
        }
    }
    
    // MARK: - Activity Operations
    
    /// Fetches all activities, optionally filtered by weekday
    /// - Parameter weekday: Optional weekday filter (1=Sunday, 2=Monday, ..., 7=Saturday)
    /// - Returns: Array of activities matching the criteria
    public func fetchActivities(scheduledFor weekday: Int? = nil) throws -> [Activity] {
        let descriptor: FetchDescriptor<Activity>
        
        if let weekday = weekday {
            // Use relationship-based predicate to avoid SwiftData reflection metadata issues
            let predicate = #Predicate<Activity> { activity in
                activity.scheduledDays.contains { $0.weekday == weekday }
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
        
        // Sync to counterpart device
        Task {
            try? await syncService?.syncModel(activity, type: .activity, action: .create)
        }
    }
    
    /// Updates an existing activity
    /// - Parameter activity: Activity to update (changes are already made to the object)
    /// - Throws: Error if save fails
    public func updateActivity(_ activity: Activity) throws {
        try modelContext.save()
        
        // Sync to counterpart device
        Task {
            try? await syncService?.syncModel(activity, type: .activity, action: .update)
        }
    }
    
    /// Deletes an activity and all associated time entries
    /// - Parameter activity: Activity to delete
    /// - Throws: Error if delete or save fails
    public func deleteActivity(_ activity: Activity) throws {
        let activityID = activity.id
        
        // Cascade delete: Remove all TimeEntries associated with this activity
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
        
        // Sync delete to counterpart device
        Task {
            try? await syncService?.syncDelete(id: activityID, type: .activity)
        }
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
        
        let timeEntry: TimeEntry
        let action: SyncAction
        
        if let existingEntry = results.first {
            // Update existing entry
            existingEntry.addDuration(validDuration)
            timeEntry = existingEntry
            action = .update
        } else {
            // Create new entry
            let newEntry = TimeEntry(
                activityID: activityID,
                date: normalizedDate,
                totalDuration: validDuration
            )
            modelContext.insert(newEntry)
            timeEntry = newEntry
            action = .create
        }
        
        try modelContext.save()
        
        // Sync to counterpart device
        Task {
            try? await syncService?.syncModel(timeEntry, type: .timeEntry, action: action)
        }
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
    
    
    // MARK: - Sync Message Handling
    
    /// Handles sync messages received from counterpart device
    private func handleReceivedSyncMessage(_ message: SyncMessage) async {
        do {
            switch message.modelType {
            case .activity:
                try await handleActivitySync(message)
            case .scheduledDay:
                // ScheduledDay is part of Activity, handled there
                break
            case .timeEntry:
                try await handleTimeEntrySync(message)
            case .activeTimer:
                // ActiveTimer handled by TimerService
                break
            case .goal:
                try await handleGoalSync(message)
            }
        } catch {
            print("❌ Error handling sync message: \(error)")
        }
    }
    
    private func handleActivitySync(_ message: SyncMessage) async throws {
        switch message.action {
        case .create, .update:
            let activity = try JSONDecoder().decode(Activity.self, from: message.data)
            
            // Check if activity already exists
            if let existing = try fetchActivity(id: activity.id) {
                // Update existing activity
                existing.name = activity.name
                existing.colorHex = activity.colorHex
                existing.category = activity.category
                
                // Update scheduled days relationship
                // Delete old scheduled days
                for day in existing.scheduledDays {
                    modelContext.delete(day)
                }
                existing.scheduledDays.removeAll()
                
                // Create new scheduled days from the decoded activity
                let scheduledDayInts = activity.scheduledDayInts
                let newDays = scheduledDayInts.map { weekday in
                    ScheduledDay(weekday: weekday, activity: existing)
                }
                existing.scheduledDays = newDays

                try modelContext.save()
            } else {
                // Insert new activity (scheduledDays relationship already set up by init)
                modelContext.insert(activity)
                try modelContext.save()
            }

            // Notify that activity was synced
            NotificationCenter.default.post(
                name: .activityDidSync,
                object: nil
            )

        case .delete:
            guard let activityId = UUID(uuidString: message.modelId),
                  let activity = try fetchActivity(id: activityId) else {
                return
            }

            // Delete locally (without triggering another sync)
            modelContext.delete(activity)
            try modelContext.save()

            // Notify that activity was synced
            NotificationCenter.default.post(
                name: .activityDidSync,
                object: nil
            )
        }
    }
    
    private func handleTimeEntrySync(_ message: SyncMessage) async throws {
        switch message.action {
        case .create, .update:
            let timeEntry = try JSONDecoder().decode(TimeEntry.self, from: message.data)

            // Check if time entry already exists
            let entries = try fetchTimeEntries(for: timeEntry.activityID, on: timeEntry.date)
            if let existing = entries.first {
                // Update existing entry with synced data
                existing.totalDuration = timeEntry.totalDuration
                try modelContext.save()
            } else {
                // Insert new time entry
                modelContext.insert(timeEntry)
                try modelContext.save()
            }

            // Notify that time entry was synced
            NotificationCenter.default.post(
                name: .timeEntryDidSync,
                object: nil,
                userInfo: ["activityID": timeEntry.activityID]
            )

        case .delete:
            guard let entryId = UUID(uuidString: message.modelId) else { return }
            
            // Find and delete the entry
            let predicate = #Predicate<TimeEntry> { entry in
                entry.id == entryId
            }
            let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
            if let entry = try modelContext.fetch(descriptor).first {
                modelContext.delete(entry)
                try modelContext.save()
            }
        }
    }
    
    private func handleGoalSync(_ message: SyncMessage) async throws {
        // Goal sync implementation (to be added when Goal operations are implemented)
#if DEBUG
        print("⚠️ Goal sync not yet implemented")
#endif
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
