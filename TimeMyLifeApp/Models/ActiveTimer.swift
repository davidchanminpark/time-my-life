//
//  ActiveTimer.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftData

/// Represents the currently active timer (singleton-like behavior)
@Model
public final class ActiveTimer {
    // MARK: - Properties

    /// Unique identifier for the timer
    public var id: UUID

    /// UUID of the currently running activity (nil if no timer is running)
    public var activityID: UUID?

    /// Start time of the current timer session (nil if not running)
    public var startTime: Date?

    /// The date (start of day) the timer was started for - used to save TimeEntry to correct date
    public var startDate: Date?

    /// Flag indicating whether the timer is currently running
    public var isRunning: Bool

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        activityID: UUID? = nil,
        startTime: Date? = nil,
        startDate: Date? = nil,
        isRunning: Bool = false
    ) {
        self.id = id
        self.activityID = activityID
        self.startTime = startTime
        self.startDate = startDate
        self.isRunning = isRunning
    }

    // MARK: - Timer Control Methods

    /// Starts the timer for a specific activity
    /// - Parameter activityID: UUID of the activity to track
    public func start(for activityID: UUID) {
        self.activityID = activityID
        self.startTime = Date()
        self.isRunning = true
    }

    /// Stops the timer and returns the elapsed duration
    /// - Returns: Elapsed duration in seconds (always non-negative), or 0 if timer wasn't running
    public func stop() -> TimeInterval {
        guard isRunning, let startTime = startTime else {
            // Reset state even if guard fails (defensive programming)
            reset()
            return 0
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Reset timer state
        self.activityID = nil
        self.startTime = nil
        self.isRunning = false

        // Ensure non-negative duration (guards against system clock changes)
        return max(0, elapsed)
    }

    /// Gets the current elapsed time without stopping the timer
    /// - Returns: Current elapsed duration in seconds, or 0 if timer isn't running
    public func currentElapsedTime() -> TimeInterval {
        guard isRunning, let startTime = startTime else {
            return 0
        }

        return Date().timeIntervalSince(startTime)
    }

    /// Resets the timer to initial state
    public func reset() {
        self.activityID = nil
        self.startTime = nil
        self.startDate = nil
        self.isRunning = false
    }

    // MARK: - Formatting Methods

}

// MARK: - Static Helper Methods

public extension ActiveTimer {
    /// Retrieves or creates the singleton ActiveTimer instance
    /// - Parameter context: ModelContext for SwiftData operations
    /// - Returns: The ActiveTimer instance
    /// - Note: This method is thread-safe and must be called on the main actor
    @MainActor
    static func shared(in context: ModelContext) throws -> ActiveTimer {
        let descriptor = FetchDescriptor<ActiveTimer>()
        let results = try context.fetch(descriptor)

        // Clean up duplicate timers if they exist (defensive programming)
        if results.count > 1 {
            // Keep the first timer, delete the rest
            for index in 1..<results.count {
                context.delete(results[index])
            }
            try context.save()
        }

        if let existingTimer = results.first {
            return existingTimer
        } else {
            // Create new timer if none exists
            let newTimer = ActiveTimer()
            context.insert(newTimer)
            try context.save()
            return newTimer
        }
    }

    /// Checks if any timer is currently running
    /// - Parameter context: ModelContext for SwiftData operations
    /// - Returns: True if a timer is running, false otherwise
    @MainActor
    static func isAnyTimerRunning(in context: ModelContext) throws -> Bool {
        let timer = try shared(in: context)
        return timer.isRunning
    }
}
