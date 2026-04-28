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
    var syncService: SyncService?
    
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
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
            )
        } else {
            descriptor = FetchDescriptor<Activity>(
                sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
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
    
    /// Reorders activities by updating their sortOrder values
    /// - Parameter activities: Activities in their new order
    /// - Throws: Error if save fails
    public func reorderActivities(_ activities: [Activity]) throws {
        for (index, activity) in activities.enumerated() {
            activity.sortOrder = index
        }
        try modelContext.save()
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
    
    /// Deletes an activity, its goals, and all associated time entries
    /// - Parameter activity: Activity to delete
    /// - Throws: Error if delete or save fails
    public func deleteActivity(_ activity: Activity) throws {
        let activityID = activity.id
        
        // Goals reference activities by `activityID` only (no SwiftData relationship) — remove them explicitly
        let goalPredicate = #Predicate<Goal> { goal in
            goal.activityID == activityID
        }
        let goalDescriptor = FetchDescriptor<Goal>(predicate: goalPredicate)
        let goals = try modelContext.fetch(goalDescriptor)
        let goalIDs = goals.map(\.id)
        for goal in goals {
            modelContext.delete(goal)
        }
        
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
        
        // Sync deletes to counterpart device
        Task {
            for goalID in goalIDs {
                try? await syncService?.syncDelete(id: goalID, type: .goal)
            }
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

        // Adding time to a *past* day can push it across the goal target and
        // change a streak that the GoalsViewModel cache has already frozen
        // (see `setTimeEntryDuration` for the full explanation). Today is
        // computed live in `loadGoals`, so we only need to invalidate when
        // the entry is for a previous day.
        if normalizedDate < Calendar.current.startOfDay(for: Date()) {
            try invalidateDailyStreakCache(activityID: activityID)
        }

        try modelContext.save()

        // Sync to counterpart device
        Task {
            try? await syncService?.syncModel(timeEntry, type: .timeEntry, action: action)
        }
    }

    /// Overwrites the duration of an existing time entry, or creates one if none exists.
    /// Unlike `createOrUpdateTimeEntry`, this *replaces* the duration rather than accumulating.
    /// Used by the Edit Time Entry flow when the user manually corrects a value.
    /// - Parameters:
    ///   - activityID: UUID of the activity
    ///   - date: Date for the entry (will be normalized to start of day)
    ///   - duration: New total duration in seconds (negative values clamped to 0)
    /// - Throws: Error if fetch or save fails
    public func setTimeEntryDuration(
        activityID: UUID,
        date: Date,
        duration: TimeInterval
    ) throws {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let validDuration = max(0, duration)

        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID && entry.date == normalizedDate
        }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)

        let timeEntry: TimeEntry
        let action: SyncAction

        if let existing = results.first {
            existing.totalDuration = validDuration
            timeEntry = existing
            action = .update
        } else {
            let newEntry = TimeEntry(
                activityID: activityID,
                date: normalizedDate,
                totalDuration: validDuration
            )
            modelContext.insert(newEntry)
            timeEntry = newEntry
            action = .create
        }

        // Editing a past day can repair OR break a previously-computed streak.
        // `GoalsViewModel.updateDailyStreak` is incremental and only walks
        // forward from `goal.lastStreakDate`, so without this reset the streak
        // would never recompute the edited day. Clearing the cached streak
        // state forces the next `loadGoals()` to rebuild from `goal.createdDate`.
        try invalidateDailyStreakCache(activityID: activityID)

        try modelContext.save()

        Task {
            try? await syncService?.syncModel(timeEntry, type: .timeEntry, action: action)
        }
    }

    /// Resets cached daily-streak state on every daily goal for the given activity
    /// so the next `GoalsViewModel.loadGoals()` recomputes from scratch.
    /// Caller is responsible for `modelContext.save()`.
    /// (SwiftData cannot filter on enum properties in `#Predicate`, so the
    /// frequency check happens in-memory — same pattern as `fetchGoals`.)
    private func invalidateDailyStreakCache(activityID: UUID) throws {
        let predicate = #Predicate<Goal> { goal in
            goal.activityID == activityID
        }
        let descriptor = FetchDescriptor<Goal>(predicate: predicate)
        let goals = try modelContext.fetch(descriptor).filter { $0.frequency == .daily }
        for goal in goals {
            goal.currentStreak = 0
            goal.lastStreakDate = nil
        }
    }

    /// Deletes a time entry
    /// - Parameter entry: TimeEntry to delete
    /// - Throws: Error if save fails
    public func deleteTimeEntry(_ entry: TimeEntry) throws {
        let entryId = entry.id
        let activityID = entry.activityID
        try invalidateDailyStreakCache(activityID: activityID)
        modelContext.delete(entry)
        try modelContext.save()
        Task {
            try? await syncService?.syncDelete(id: entryId, type: .timeEntry)
        }
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
    
    /// Years to show in Year in Review: from earliest time entry or activity creation through the current calendar year (never future years).
    public func yearsWithTrackingHistory() throws -> [Int] {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        var startYear = currentYear

        var entryDescriptor = FetchDescriptor<TimeEntry>(sortBy: [SortDescriptor(\.date, order: .forward)])
        entryDescriptor.fetchLimit = 1
        if let firstEntry = try modelContext.fetch(entryDescriptor).first {
            startYear = min(startYear, cal.component(.year, from: firstEntry.date))
        }

        var activityDescriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        activityDescriptor.fetchLimit = 1
        if let firstActivity = try modelContext.fetch(activityDescriptor).first {
            startYear = min(startYear, cal.component(.year, from: firstActivity.createdAt))
        }

        if startYear > currentYear { startYear = currentYear }
        return Array(startYear...currentYear)
    }
    
    /// Start of the earliest month the calendar may show: not before the first activity’s calendar month,
    /// and within a rolling window of 12 calendar months including the current month (so at most 11 months back from the current month start).
    public func earliestCalendarDisplayMonthStart() throws -> Date {
        let cal = Calendar.current
        let now = Date()
        guard let startOfCurrentMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return cal.startOfDay(for: now)
        }
        guard let twelveMonthWindowStart = cal.date(byAdding: .month, value: -11, to: startOfCurrentMonth) else {
            return startOfCurrentMonth
        }
        
        let activityDescriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        guard let firstActivity = try modelContext.fetch(activityDescriptor).first else {
            return startOfCurrentMonth
        }
        let parts = cal.dateComponents([.year, .month], from: firstActivity.createdAt)
        guard let firstActivityMonthStart = cal.date(from: parts) else {
            return max(twelveMonthWindowStart, startOfCurrentMonth)
        }
        return max(firstActivityMonthStart, twelveMonthWindowStart)
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
    
    /// Handles sync messages received from counterpart device.
    /// Goal sync (`handleGoalSync`) lives in `DataServiceGoalExtensions.swift` so it can use `fetchGoal` there.
    /// The Watch app target must include that file (see Xcode target membership / synchronized folder exceptions).
    func handleReceivedSyncMessage(_ message: SyncMessage) async {
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

            // Validate synced data — same rules the UI enforces
            let trimmedName = activity.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, trimmedName.count <= AppConstants.maxNameLength else {
                print("❌ Sync rejected: activity name invalid (empty or >\(AppConstants.maxNameLength) chars)")
                return
            }
            let trimmedCategory = activity.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedCategory.count <= AppConstants.maxCategoryLength else {
                print("❌ Sync rejected: category too long (>\(AppConstants.maxCategoryLength) chars)")
                return
            }
            let validDays = activity.scheduledDayInts.filter { $0 >= 1 && $0 <= 7 }
            guard !validDays.isEmpty else {
                print("❌ Sync rejected: no valid scheduled days")
                return
            }
            // Enforce max activity count for new activities
            if try fetchActivity(id: activity.id) == nil {
                let count = try getActivityCount()
                guard count < AppConstants.maxActivities else {
                    print("❌ Sync rejected: activity limit (\(AppConstants.maxActivities)) reached")
                    return
                }
            }

            // Check if activity already exists
            if let existing = try fetchActivity(id: activity.id) {
                // Update existing activity
                existing.name = trimmedName
                existing.colorHex = activity.colorHex
                existing.category = trimmedCategory

                // Update scheduled days relationship
                // Delete old scheduled days
                for day in existing.scheduledDays {
                    modelContext.delete(day)
                }
                existing.scheduledDays.removeAll()

                // Create new scheduled days from validated weekdays
                let newDays = validDays.map { weekday in
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

            // Validate synced data
            guard timeEntry.totalDuration.isFinite, timeEntry.totalDuration >= 0 else {
                print("❌ Sync rejected: invalid duration (\(timeEntry.totalDuration))")
                return
            }
            // Cap at 24 hours per entry — no single day can exceed this
            let maxDailySeconds: TimeInterval = 86_400
            guard timeEntry.totalDuration <= maxDailySeconds else {
                print("❌ Sync rejected: duration exceeds 24h (\(timeEntry.totalDuration)s)")
                return
            }
            // Reject entries with dates far in the future (allow 1 day buffer for timezone differences)
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
            guard timeEntry.date <= tomorrow else {
                print("❌ Sync rejected: time entry date is in the future (\(timeEntry.date))")
                return
            }
            // Verify the referenced activity exists
            guard try fetchActivity(id: timeEntry.activityID) != nil else {
                print("❌ Sync rejected: no activity found for ID \(timeEntry.activityID)")
                return
            }

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
}



extension DataService {
    @MainActor
    static var preview: DataService {
        IOSViewPreviewSupport.dependencies().1
    }
}
