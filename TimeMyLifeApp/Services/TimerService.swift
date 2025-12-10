//
//  TimerService.swift
//  TimeMyLife Watch App
//

import Foundation
import Combine
import SwiftData
import Observation

/// Errors that can occur in TimerService
public enum TimerServiceError: Error, LocalizedError {
    case activityNotFound

    public var errorDescription: String? {
        switch self {
        case .activityNotFound:
            return "Activity not found"
        }
    }
}

/// Service that manages timer state and logic
/// Provides platform-independent timer functionality
/// Note: Uses @Observable for SwiftUI views, and Combine publishers for ViewModel observation
@Observable
@MainActor
public class TimerService {
    // MARK: - Observable Properties

    /// Current elapsed time in seconds
    public private(set) var elapsedTime: TimeInterval = 0 {
        didSet {
            elapsedTimeSubject.send(elapsedTime)
        }
    }

    /// Whether the timer is currently running
    public private(set) var isRunning: Bool = false {
        didSet {
            isRunningSubject.send(isRunning)
        }
    }

    /// The activity currently being timed
    public private(set) var currentActivity: Activity?

    /// The date the timer was started for (for saving to correct TimeEntry)
    public private(set) var currentDate: Date?
    
    // MARK: - Combine Publishers (for ViewModel observation)
    
    /// Publisher for elapsed time changes
    public var elapsedTimePublisher: AnyPublisher<TimeInterval, Never> {
        elapsedTimeSubject.eraseToAnyPublisher()
    }
    
    /// Publisher for running state changes
    public var isRunningPublisher: AnyPublisher<Bool, Never> {
        isRunningSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var timer: Timer?
    private var startTime: Date?
    private let modelContext: ModelContext
    
    // Combine subjects for publishing changes
    private let elapsedTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let isRunningSubject = CurrentValueSubject<Bool, Never>(false)

    // MARK: - Initialization

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Timer Control

    /// Starts the timer for a specific activity and date
    /// - Parameters:
    ///   - activity: Activity to track
    ///   - targetDate: Date to track time for (will be normalized to start of day)
    /// - Throws: Error if unable to start timer or save state
    public func start(activity: Activity, targetDate: Date) throws {
        // Stop any running timer first
        if isRunning {
            let _ = try stop()
        }

        let normalizedDate = Calendar.current.startOfDay(for: targetDate)

        // Update local state
        self.currentActivity = activity
        self.currentDate = normalizedDate
        self.startTime = Date()
        self.isRunning = true
        self.elapsedTime = 0

        // Save to ActiveTimer model
        let activeTimer = try ActiveTimer.shared(in: modelContext)
        activeTimer.activityID = activity.id
        activeTimer.startTime = startTime
        activeTimer.startDate = normalizedDate
        activeTimer.isRunning = true
        try modelContext.save()

        // Start UI updates
        startTimerUpdates()

        #if DEBUG
        print("✅ TimerService: Started timer for '\(activity.name)'")
        #endif
    }

    /// Stops the timer and returns the timer data
    /// - Returns: Tuple containing (activityID, date, duration) or nil if no timer running
    /// - Throws: Error if unable to update ActiveTimer state
    @discardableResult
    public func stop() throws -> (activityID: UUID, date: Date, duration: TimeInterval)? {
        guard let activity = currentActivity,
              let date = currentDate,
              isRunning else {
            return nil
        }

        let duration = elapsedTime
        let activityID = activity.id

        // Reset ActiveTimer state
        let activeTimer = try ActiveTimer.shared(in: modelContext)
        activeTimer.activityID = nil
        activeTimer.startTime = nil
        activeTimer.startDate = nil
        activeTimer.isRunning = false
        try modelContext.save()

        // Stop UI updates
        stopTimerUpdates()

        // Reset local state
        self.isRunning = false
        self.currentActivity = nil
        self.currentDate = nil
        self.startTime = nil
        self.elapsedTime = 0

        #if DEBUG
        print("✅ TimerService: Stopped timer, duration: \(formatDuration(duration))")
        #endif

        return (activityID: activityID, date: date, duration: duration)
    }

    /// Resumes a timer that was previously started
    /// - Parameters:
    ///   - activity: Activity being timed
    ///   - startTime: When the timer was originally started
    ///   - targetDate: Date the timer is tracking
    /// - Throws: Error if unable to resume
    public func resume(activity: Activity, startTime: Date, targetDate: Date) throws {
        let normalizedDate = Calendar.current.startOfDay(for: targetDate)

        // Update local state
        self.currentActivity = activity
        self.currentDate = normalizedDate
        self.startTime = startTime
        self.isRunning = true
        self.elapsedTime = Date().timeIntervalSince(startTime)

        // Start UI updates
        startTimerUpdates()

        #if DEBUG
        print("✅ TimerService: Resumed timer for '\(activity.name)', elapsed: \(formatDuration(elapsedTime))")
        #endif
    }

    /// Gets the current elapsed time without stopping the timer
    /// - Returns: Current elapsed time in seconds
    public func getCurrentElapsedTime() -> TimeInterval {
        guard let startTime = startTime, isRunning else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }

    /// Checks if a specific activity is currently being timed
    /// - Parameter activity: Activity to check
    /// - Returns: True if this activity's timer is running
    public func isTimerRunning(for activity: Activity) -> Bool {
        return isRunning && currentActivity?.id == activity.id
    }

    /// Checks if the timer is running for a specific activity and date
    /// - Parameters:
    ///   - activity: Activity to check
    ///   - date: Date to check
    /// - Returns: True if timer is running for this activity on this date
    public func isTimerRunning(for activity: Activity, on date: Date) -> Bool {
        guard isRunning,
              currentActivity?.id == activity.id,
              let currentDate = currentDate else {
            return false
        }
        return Calendar.current.isDate(currentDate, inSameDayAs: date)
    }

    /// Gets the activity ID currently being timed
    /// - Returns: Activity ID if timer is running, nil otherwise
    public func getCurrentActivityID() -> UUID? {
        return isRunning ? currentActivity?.id : nil
    }

    /// Gets the date the current timer is tracking
    /// - Returns: Date if timer is running, nil otherwise
    public func getCurrentTrackingDate() -> Date? {
        return isRunning ? currentDate : nil
    }

    /// Restores timer state from persisted ActiveTimer and activity
    /// - Parameters:
    ///   - activeTimer: The persisted active timer state
    ///   - activity: The activity being timed
    /// - Throws: Error if unable to restore
    public func restoreTimerState(from activeTimer: ActiveTimer, activity: Activity) throws {
        guard activeTimer.isRunning,
              let startTime = activeTimer.startTime,
              let startDate = activeTimer.startDate else {
            return
        }

        // Resume the timer
        try resume(activity: activity, startTime: startTime, targetDate: startDate)
    }

    /// Gets the persisted ActiveTimer
    /// - Returns: The ActiveTimer singleton
    /// - Throws: Error if fetch fails
    public func getActiveTimer() throws -> ActiveTimer {
        return try ActiveTimer.shared(in: modelContext)
    }

    /// Resets the timer state (for testing/clearing data)
    /// - Throws: Error if save fails
    public func reset() throws {
        // Stop any running timer first
        if isRunning {
            let _ = try stop()
        }

        // Reset persisted state
        let activeTimer = try ActiveTimer.shared(in: modelContext)
        activeTimer.activityID = nil
        activeTimer.startTime = nil
        activeTimer.startDate = nil
        activeTimer.isRunning = false
        try modelContext.save()

        #if DEBUG
        print("✅ TimerService: Reset timer state")
        #endif
    }

    /// Async version of stop() that doesn't return a value
    /// - Throws: Error if unable to stop timer
    public func stopTimer() async throws {
        _ = try stop()
    }

    /// Non-throwing version of start() for convenience
    /// - Parameters:
    ///   - activity: Activity to track
    ///   - date: Date to track time for
    public func startTimer(for activity: Activity, on date: Date) {
        do {
            try start(activity: activity, targetDate: date)
        } catch {
            #if DEBUG
            print("❌ TimerService: Failed to start timer: \(error)")
            #endif
            // In a non-throwing method, we can't propagate the error
            // The error state will be reflected in the service's state
        }
    }

    /// Pauses the timer (stops it without saving)
    /// Note: This implementation stops the timer completely
    /// For a true pause/resume, you would need additional state management
    public func pauseTimer() {
        // For now, pause is equivalent to stop
        // A full pause/resume implementation would require additional state
        do {
            _ = try stop()
        } catch {
            #if DEBUG
            print("❌ TimerService: Failed to pause timer: \(error)")
            #endif
        }
    }

    // MARK: - Private Methods

    private func startTimerUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let startTime = self.startTime,
                  self.isRunning else {
                return
            }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimerUpdates() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Helper Methods

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

extension TimerService {
    static var preview: TimerService {
        let schema = Schema([Activity.self, TimeEntry.self, ActiveTimer.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        return TimerService(modelContext: container.mainContext)
    }
}
