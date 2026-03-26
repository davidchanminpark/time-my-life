//
//  SampleData.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftData

/// Provides sample data and CRUD testing utilities for development and testing
public enum SampleData {

    // MARK: - Sample Activity Factories

    /// Creates a sample "Guitar Practice" activity
    public static func sampleActivityGuitar() throws -> Activity {
        return try Activity.validated(
            name: "Guitar Practice",
            colorHex: "#FF5733",
            category: "Music",
            scheduledDays: [2, 4, 6] // Monday, Wednesday, Friday
        )
    }

    /// Creates a sample "Reading" activity
    public static func sampleActivityReading() throws -> Activity {
        return try Activity.validated(
            name: "Reading",
            colorHex: "#33C3FF",
            category: "Learning",
            scheduledDays: [1, 2, 3, 4, 5, 6, 7] // Every day
        )
    }

    /// Creates a sample "Gym Workout" activity
    public static func sampleActivityGym() throws -> Activity {
        return try Activity.validated(
            name: "Gym Workout",
            colorHex: "#75FF33",
            category: "Fitness",
            scheduledDays: [2, 4, 6] // Monday, Wednesday, Friday
        )
    }

    /// Creates a sample "Meditation" activity
    public static func sampleActivityMeditation() throws -> Activity {
        return try Activity.validated(
            name: "Meditation",
            colorHex: "#FF33F5",
            category: "Wellness",
            scheduledDays: [1, 7] // Sunday, Saturday
        )
    }

    /// Creates a sample "Coding" activity
    public static func sampleActivityCoding() throws -> Activity {
        return try Activity.validated(
            name: "Coding",
            colorHex: "#FFC300",
            category: "Work",
            scheduledDays: [2, 3, 4, 5, 6] // Weekdays
        )
    }

    /// Creates a collection of sample activities
    public static func sampleActivities() throws -> [Activity] {
        return try [
            sampleActivityGuitar(),
            sampleActivityReading(),
            sampleActivityGym(),
            sampleActivityMeditation(),
            sampleActivityCoding()
        ]
    }

    // MARK: - Sample TimeEntry Factories

    /// Creates a sample time entry for a given activity
    /// - Parameters:
    ///   - activityID: The UUID of the associated activity
    ///   - daysAgo: Number of days ago for the entry (0 = today)
    ///   - durationMinutes: Duration in minutes
    /// - Returns: A TimeEntry instance
    public static func sampleTimeEntry(
        activityID: UUID,
        daysAgo: Int = 0,
        durationMinutes: Int = 30
    ) -> TimeEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return TimeEntry(
            activityID: activityID,
            date: date,
            totalDuration: TimeInterval(durationMinutes * 60)
        )
    }

    /// Creates multiple sample time entries for an activity over several days
    /// - Parameters:
    ///   - activityID: The UUID of the associated activity
    ///   - dayCount: Number of days of entries to create
    /// - Returns: Array of TimeEntry instances
    public static func sampleTimeEntries(activityID: UUID, dayCount: Int = 7) -> [TimeEntry] {
        var entries: [TimeEntry] = []
        for day in 0..<dayCount {
            let randomDuration = Int.random(in: 15...120) // 15-120 minutes
            entries.append(sampleTimeEntry(
                activityID: activityID,
                daysAgo: day,
                durationMinutes: randomDuration
            ))
        }
        return entries
    }

    // MARK: - Sample ActiveTimer Factory

    /// Creates a sample active timer
    /// - Parameter isRunning: Whether the timer should be in running state
    /// - Returns: An ActiveTimer instance
    public static func sampleActiveTimer(isRunning: Bool = false) -> ActiveTimer {
        if isRunning {
            let timer = ActiveTimer()
            // Create a fake activity ID for testing
            timer.start(for: UUID())
            return timer
        } else {
            return ActiveTimer()
        }
    }

    // MARK: - CRUD Testing Utilities

    /// Populates the ModelContext with sample data for testing
    /// - Parameter context: The ModelContext to populate
    /// - Throws: Any errors during data creation
    public static func populateSampleData(in context: ModelContext) throws {
        // Create sample activities
        let activities = try sampleActivities()

        // Insert activities into context
        for activity in activities {
            context.insert(activity)
        }

        // Create sample time entries for each activity
        for activity in activities {
            let entries = sampleTimeEntries(activityID: activity.id, dayCount: 7)
            for entry in entries {
                context.insert(entry)
            }
        }

        // Save the context
        try context.save()
    }

    /// Clears all data from the ModelContext
    /// - Parameter context: The ModelContext to clear
    /// - Throws: Any errors during deletion
    @MainActor
    public static func clearAllData(in context: ModelContext) throws {
        // Delete all activities
        let activityDescriptor = FetchDescriptor<Activity>()
        let activities = try context.fetch(activityDescriptor)
        for activity in activities {
            context.delete(activity)
        }

        // Delete all time entries
        let entryDescriptor = FetchDescriptor<TimeEntry>()
        let entries = try context.fetch(entryDescriptor)
        for entry in entries {
            context.delete(entry)
        }

        // Reset active timer (don't delete, just reset)
        if let timer = try? ActiveTimer.shared(in: context) {
            timer.reset()
        }

        // Save the context
        try context.save()
    }

    // MARK: - CRUD Operation Testing

    /// Tests CREATE operation for Activity
    /// - Parameter context: The ModelContext to use
    /// - Returns: The created Activity
    /// - Throws: Any errors during creation
    @discardableResult
    public static func testCreateActivity(in context: ModelContext) throws -> Activity {
        let activity = try Activity.validated(
            name: "Test Activity",
            colorHex: "#FF0000",
            category: "Test",
            scheduledDays: [1, 2, 3, 4, 5, 6, 7]
        )
        context.insert(activity)
        try context.save()
        return activity
    }

    /// Tests READ operation for Activity
    /// - Parameters:
    ///   - id: The UUID of the activity to read
    ///   - context: The ModelContext to use
    /// - Returns: The found Activity or nil
    /// - Throws: Any errors during fetch
    public static func testReadActivity(id: UUID, in context: ModelContext) throws -> Activity? {
        let predicate = #Predicate<Activity> { activity in
            activity.id == id
        }
        let descriptor = FetchDescriptor<Activity>(predicate: predicate)
        let results = try context.fetch(descriptor)
        return results.first
    }

    /// Tests UPDATE operation for Activity
    /// - Parameters:
    ///   - activity: The activity to update
    ///   - newName: The new name to set
    ///   - context: The ModelContext to use
    /// - Throws: Any errors during update
    public static func testUpdateActivity(
        _ activity: Activity,
        newName: String,
        in context: ModelContext
    ) throws {
        // Validate the new name before updating
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ActivityValidationError.nameTooShort
        }
        guard trimmedName.count <= 30 else {
            throw ActivityValidationError.nameTooLong
        }

        activity.name = trimmedName
        try context.save()
    }

    /// Tests DELETE operation for Activity
    /// - Parameters:
    ///   - activity: The activity to delete
    ///   - context: The ModelContext to use
    /// - Throws: Any errors during deletion
    public static func testDeleteActivity(_ activity: Activity, in context: ModelContext) throws {
        // Delete associated time entries
        let activityID = activity.id
        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID
        }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        let entries = try context.fetch(descriptor)
        for entry in entries {
            context.delete(entry)
        }

        // Delete the activity
        context.delete(activity)
        try context.save()
    }

    /// Tests CREATE operation for TimeEntry
    /// - Parameters:
    ///   - activityID: The activity ID for the entry
    ///   - context: The ModelContext to use
    /// - Returns: The created TimeEntry
    /// - Throws: Any errors during creation
    @discardableResult
    public static func testCreateTimeEntry(
        activityID: UUID,
        in context: ModelContext
    ) throws -> TimeEntry {
        let entry = TimeEntry(
            activityID: activityID,
            date: Date(),
            totalDuration: 1800 // 30 minutes
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    /// Tests READ operation for TimeEntry
    /// - Parameters:
    ///   - activityID: The activity ID to search for
    ///   - date: The date to search for
    ///   - context: The ModelContext to use
    /// - Returns: The found TimeEntry or nil
    /// - Throws: Any errors during fetch
    public static func testReadTimeEntry(
        activityID: UUID,
        date: Date,
        in context: ModelContext
    ) throws -> TimeEntry? {
        return try TimeEntry.fetch(activityID: activityID, date: date, in: context)
    }

    /// Tests UPDATE operation for TimeEntry (accumulation)
    /// - Parameters:
    ///   - entry: The time entry to update
    ///   - additionalDuration: Duration to add in seconds
    ///   - context: The ModelContext to use
    /// - Throws: Any errors during update
    public static func testUpdateTimeEntry(
        _ entry: TimeEntry,
        additionalDuration: TimeInterval,
        in context: ModelContext
    ) throws {
        entry.addDuration(additionalDuration)
        try context.save()
    }

    /// Tests DELETE operation for TimeEntry
    /// - Parameters:
    ///   - entry: The time entry to delete
    ///   - context: The ModelContext to use
    /// - Throws: Any errors during deletion
    public static func testDeleteTimeEntry(_ entry: TimeEntry, in context: ModelContext) throws {
        context.delete(entry)
        try context.save()
    }

    /// Tests ActiveTimer start/stop operations
    /// - Parameter context: The ModelContext to use
    /// - Returns: Tuple of (timer, elapsed duration)
    /// - Throws: Any errors during timer operations
    @discardableResult
    @MainActor
    public static func testTimerOperations(in context: ModelContext) throws -> (ActiveTimer, TimeInterval) {
        let timer = try ActiveTimer.shared(in: context)
        let testActivityID = UUID()

        // Start timer
        timer.start(for: testActivityID)

        // Simulate some elapsed time (for testing purposes)
        Thread.sleep(forTimeInterval: 0.1) // Sleep for 100ms

        // Stop timer and get duration
        let duration = timer.stop()

        try context.save()

        return (timer, duration)
    }

    // MARK: - Hard-Coded Data with Large Time Values

    /// Populates the ModelContext with hard-coded activities and large time values for testing
    /// - Parameter context: The ModelContext to populate
    /// - Throws: Any errors during data creation
    @MainActor
    public static func populateHardCodedLargeTimeData(in context: ModelContext) throws {
        // Clear existing data first
        try clearAllData(in: context)

        // Create activities with various large time scenarios
        let activities = try [
            // Activity with many hours today
            try Activity.validated(
                name: "Deep Work",
                colorHex: "#BFC8FF",
                category: "Work",
                scheduledDays: [2, 3, 4, 5, 6]
            ),
            // Activity with days worth of time
            try Activity.validated(
                name: "Coding Marathon",
                colorHex: "#D4BAFF",
                category: "Development",
                scheduledDays: [1, 2, 3, 4, 5, 6, 7]
            ),
            // Activity with very large accumulated time
            try Activity.validated(
                name: "Learning",
                colorHex: "#FFCCE1",
                category: "Education",
                scheduledDays: [1, 2, 3, 4, 5, 6, 7]
            ),
            // Activity with moderate but still large time
            try Activity.validated(
                name: "Exercise",
                colorHex: "#BAE1FF",
                category: "Fitness",
                scheduledDays: [2, 4, 6]
            ),
            // Activity with extreme time values
            try Activity.validated(
                name: "Project X",
                colorHex: "#FFB3BA",
                category: "Work",
                scheduledDays: [2, 3, 4, 5, 6]
            )
        ]

        // Insert activities
        for activity in activities {
            context.insert(activity)
        }

        // Create time entries with large values
        let calendar = Calendar.current
        let today = Date()
        
        // Activity 0: "Deep Work" - 8.5 hours today
        try TimeEntry.createOrUpdate(
            activityID: activities[0].id,
            date: today,
            duration: 8.5 * 3600, // 8.5 hours in seconds
            in: context
        )

        // Activity 1: "Coding Marathon" - Multiple days with large values
        // Today: 12 hours
        try TimeEntry.createOrUpdate(
            activityID: activities[1].id,
            date: today,
            duration: 12 * 3600, // 12 hours
            in: context
        )
        // Yesterday: 10 hours
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            try TimeEntry.createOrUpdate(
                activityID: activities[1].id,
                date: yesterday,
                duration: 10 * 3600, // 10 hours
                in: context
            )
        }
        // 2 days ago: 14 hours
        if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) {
            try TimeEntry.createOrUpdate(
                activityID: activities[1].id,
                date: twoDaysAgo,
                duration: 14 * 3600, // 14 hours
                in: context
            )
        }

        // Activity 2: "Learning" - Very large accumulated time (over 100 hours total)
        // Today: 6 hours
        try TimeEntry.createOrUpdate(
            activityID: activities[2].id,
            date: today,
            duration: 6 * 3600,
            in: context
        )
        // Last 7 days with varying large amounts
        for dayOffset in 1...7 {
            if let pastDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                let hours = Double.random(in: 3...8) // 3-8 hours per day
                try TimeEntry.createOrUpdate(
                    activityID: activities[2].id,
                    date: pastDate,
                    duration: hours * 3600,
                    in: context
                )
            }
        }

        // Activity 3: "Exercise" - Moderate but still large (2.5 hours today)
        try TimeEntry.createOrUpdate(
            activityID: activities[3].id,
            date: today,
            duration: 2.5 * 3600, // 2.5 hours
            in: context
        )
        // Last 3 workout days
        for dayOffset in [2, 4, 6] {
            if let pastDate = calendar.date(byAdding: .day, value: -dayOffset, to: today) {
                try TimeEntry.createOrUpdate(
                    activityID: activities[3].id,
                    date: pastDate,
                    duration: 1.5 * 3600, // 1.5 hours
                    in: context
                )
            }
        }

        // Activity 4: "Project X" - Extreme values (24+ hours in a day)
        // Today: 16 hours (extreme work day)
        try TimeEntry.createOrUpdate(
            activityID: activities[4].id,
            date: today,
            duration: 16 * 3600, // 16 hours
            in: context
        )
        // Yesterday: 18 hours (even more extreme)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            try TimeEntry.createOrUpdate(
                activityID: activities[4].id,
                date: yesterday,
                duration: 18 * 3600, // 18 hours
                in: context
            )
        }
        // 3 days ago: 20 hours (maximum reasonable)
        if let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today) {
            try TimeEntry.createOrUpdate(
                activityID: activities[4].id,
                date: threeDaysAgo,
                duration: 20 * 3600, // 20 hours
                in: context
            )
        }

        // Save all changes
        try context.save()
    }

    /// Creates a single activity with a very large time entry for today
    /// - Parameters:
    ///   - name: Activity name
    ///   - hours: Number of hours to set for today
    ///   - context: The ModelContext to use
    /// - Returns: The created Activity
    /// - Throws: Any errors during creation
    @discardableResult
    public static func createActivityWithLargeTime(
        name: String,
        hours: Double,
        in context: ModelContext
    ) throws -> Activity {
        let activity = try Activity.validated(
            name: name,
            colorHex: "#BFC8FF",
            category: "Test",
            scheduledDays: [1, 2, 3, 4, 5, 6, 7]
        )
        context.insert(activity)

        // Add large time entry for today
        try TimeEntry.createOrUpdate(
            activityID: activity.id,
            date: Date(),
            duration: hours * 3600, // Convert hours to seconds
            in: context
        )

        try context.save()
        return activity
    }

    /// Adds a large time entry to an existing activity
    /// - Parameters:
    ///   - activity: The activity to add time to
    ///   - hours: Number of hours to add
    ///   - daysAgo: How many days ago (0 = today)
    ///   - context: The ModelContext to use
    /// - Throws: Any errors during update
    public static func addLargeTimeToActivity(
        _ activity: Activity,
        hours: Double,
        daysAgo: Int = 0,
        in context: ModelContext
    ) throws {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        try TimeEntry.createOrUpdate(
            activityID: activity.id,
            date: date,
            duration: hours * 3600, // Convert hours to seconds
            in: context
        )
        try context.save()
    }

    // MARK: - Year-Long Dataset for Simulator Testing

    /// Activity definitions used by `seedYearOfData`.
    private static let yearActivities: [(name: String, colorHex: String, category: String, emoji: String, days: [Int])] = [
        ("Guitar Practice", "#D4BAFF", "Music",      "🎸", [2, 4, 6]),          // Mon, Wed, Fri
        ("Reading",         "#BAE1FF", "Learning",    "📚", [1, 2, 3, 4, 5, 6, 7]),
        ("Gym Workout",     "#C9E4CA", "Fitness",     "🏋️", [2, 4, 6]),
        ("Meditation",      "#FFCCE1", "Wellness",    "🧘", [1, 2, 3, 4, 5, 6, 7]),
        ("Coding",          "#BFC8FF", "Work",        "💻", [2, 3, 4, 5, 6]),    // Weekdays
        ("Cooking",         "#FFD6A5", "Life",        "🍳", [1, 7]),             // Weekend
        ("Running",         "#CAFFBF", "Fitness",     "🏃", [3, 5, 7]),          // Tue, Thu, Sat
        ("Drawing",         "#FFB3BA", "Creative",    "🎨", [1, 4, 7]),          // Sun, Wed, Sat
        ("Language Study",  "#AED6F7", "Learning",    "🗣️", [2, 3, 4, 5, 6]),
        ("Journaling",      "#FDFFB6", "Wellness",    "📝", [1, 2, 3, 4, 5, 6, 7]),
    ]

    /// Populates a year's worth of realistic activity data for simulator UI testing.
    ///
    /// Creates 10 activities with time entries spanning the past 365 days.
    /// Entries are only created on each activity's scheduled days and durations
    /// vary to produce interesting charts (weekday patterns, occasional gaps).
    /// Goals are created for a subset of activities.
    ///
    /// Uses bulk `ModelContext.insert` + a single save for speed (~7 k inserts).
    ///
    /// - Parameters:
    ///   - context: The `ModelContext` to populate.
    ///   - clearFirst: When `true` (default), deletes existing data before seeding.
    @MainActor
    public static func seedYearOfData(in context: ModelContext, clearFirst: Bool = true) throws {
        if clearFirst {
            try clearAllData(in: context)
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // --- Activities -----------------------------------------------------------

        var activities: [Activity] = []
        for def in yearActivities {
            let activity = Activity(
                name: def.name,
                colorHex: def.colorHex,
                category: def.category,
                emoji: def.emoji,
                scheduledDays: def.days
            )
            context.insert(activity)
            activities.append(activity)
        }

        // --- Time Entries (365 days) ---------------------------------------------

        // Deterministic seed so the dataset is reproducible across runs.
        var rng = SeededRandomNumberGenerator(seed: 42)

        for (index, activity) in activities.enumerated() {
            let scheduledSet = Set(yearActivities[index].days)

            for dayOffset in 0..<365 {
                guard let date = cal.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
                let weekday = cal.component(.weekday, from: date) // 1=Sun…7=Sat

                guard scheduledSet.contains(weekday) else { continue }

                // Skip ~10 % of days to create realistic gaps.
                if Int.random(in: 0..<10, using: &rng) == 0 { continue }

                // Duration varies by activity index to spread the chart nicely.
                let baseMins = Double((index % 4 + 1) * 15) // 15, 30, 45, 60
                let jitter   = Double.random(in: -10...10, using: &rng)
                let mins     = max(5, baseMins + jitter)

                let entry = TimeEntry(
                    activityID: activity.id,
                    date: cal.startOfDay(for: date),
                    totalDuration: mins * 60
                )
                context.insert(entry)
            }
        }

        // --- Goals (first 5 activities) ------------------------------------------

        let goalDefs: [(idx: Int, freq: GoalFrequency, targetMins: Int)] = [
            (0, .daily,  30),   // Guitar — 30 min/day
            (1, .daily,  60),   // Reading — 1 h/day
            (2, .weekly, 180),  // Gym — 3 h/week
            (3, .daily,  15),   // Meditation — 15 min/day
            (4, .weekly, 300),  // Coding — 5 h/week
        ]

        for def in goalDefs {
            let goal = Goal(
                activityID: activities[def.idx].id,
                frequency: def.freq,
                targetSeconds: def.targetMins * 60
            )
            context.insert(goal)
        }

        // --- Persist -------------------------------------------------------------

        try context.save()

        // Ensure ActiveTimer singleton exists.
        _ = try ActiveTimer.shared(in: context)
    }
}

// MARK: - Deterministic RNG

/// A simple seedable RNG so that `seedYearOfData` produces the same dataset every time.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// MARK: - ModelContext Extensions for Testing

public extension ModelContext {
    /// Convenience method to populate sample data
    func populateSampleData() throws {
        try SampleData.populateSampleData(in: self)
    }

    /// Convenience method to clear all data
    @MainActor
    func clearAllData() throws {
        try SampleData.clearAllData(in: self)
    }
}

