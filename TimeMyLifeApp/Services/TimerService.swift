//
//  TimerService.swift
//  TimeMyLife Watch App
//

import Foundation
import Combine
import SwiftData
import Observation
import WidgetKit

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

    #if os(iOS)
    /// Service for managing the Live Activity (Lock Screen / Dynamic Island)
    private let liveActivityService = LiveActivityService()
    #endif

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
        // Stop any running timer first and save its time entry
        if isRunning {
            if let timerData = try stop() {
                let _ = try TimeEntry.createOrUpdate(
                    activityID: timerData.activityID,
                    date: timerData.date,
                    duration: timerData.duration,
                    in: modelContext
                )
                try modelContext.save()
            }
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

        // Start Live Activity (iOS only)
        #if os(iOS)
        let accumulated = fetchAccumulatedTime(activityID: activity.id, date: normalizedDate)
        liveActivityService.start(
            activityName: activity.name,
            activityEmoji: activity.emoji,
            activityColorHex: activity.colorHex,
            startDate: startTime!,
            accumulatedTime: accumulated
        )
        #endif

        // Update watch complication (watchOS only)
        #if os(watchOS)
        WatchTimerSharedState.writeRunning(
            activityName: activity.name,
            activityEmoji: activity.emoji,
            activityColorHex: activity.colorHex,
            startDate: startTime!
        )
        WidgetCenter.shared.reloadAllTimelines()
        #endif

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

        // End Live Activity (iOS only)
        #if os(iOS)
        liveActivityService.stop()
        #endif

        // Update watch complication (watchOS only)
        #if os(watchOS)
        WatchTimerSharedState.writeStopped()
        WidgetCenter.shared.reloadAllTimelines()
        #endif

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

    /// Maximum duration a single timer session can accumulate (24 hours).
    /// If a persisted timer exceeds this (e.g. app not opened for days, clock
    /// manipulation), the excess is discarded to prevent data corruption.
    private static let maxTimerDuration: TimeInterval = 86_400

    /// Resumes a timer that was previously started
    /// - Parameters:
    ///   - activity: Activity being timed
    ///   - startTime: When the timer was originally started
    ///   - targetDate: Date the timer is tracking
    /// - Throws: Error if unable to resume
    public func resume(activity: Activity, startTime: Date, targetDate: Date) throws {
        let normalizedDate = Calendar.current.startOfDay(for: targetDate)

        // Sanity-check the persisted startTime
        let rawElapsed = Date().timeIntervalSince(startTime)

        // Reject future startTimes (negative elapsed) — likely clock tampering
        guard rawElapsed >= 0 else {
            #if DEBUG
            print("⚠️ TimerService: startTime is in the future, discarding stale timer")
            #endif
            try clearPersistedTimer()
            return
        }

        // Cap elapsed time at 24h to prevent phantom durations from clock
        // manipulation or the app not being opened for extended periods
        let cappedElapsed = min(rawElapsed, Self.maxTimerDuration)

        // Update local state
        self.currentActivity = activity
        self.currentDate = normalizedDate
        self.startTime = Date().addingTimeInterval(-cappedElapsed)
        self.isRunning = true
        self.elapsedTime = cappedElapsed

        if rawElapsed > Self.maxTimerDuration {
            #if DEBUG
            print("⚠️ TimerService: Timer exceeded 24h (\(formatDuration(rawElapsed))), capped to 24h")
            #endif
        }

        // Start UI updates
        startTimerUpdates()

        // Start Live Activity on resume (iOS only)
        #if os(iOS)
        let accumulated = fetchAccumulatedTime(activityID: activity.id, date: normalizedDate)
        liveActivityService.start(
            activityName: activity.name,
            activityEmoji: activity.emoji,
            activityColorHex: activity.colorHex,
            startDate: startTime,
            accumulatedTime: accumulated
        )
        #endif

        // Update watch complication on resume (watchOS only)
        #if os(watchOS)
        WatchTimerSharedState.writeRunning(
            activityName: activity.name,
            activityEmoji: activity.emoji,
            activityColorHex: activity.colorHex,
            startDate: startTime
        )
        WidgetCenter.shared.reloadAllTimelines()
        #endif

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

    /// Restores timer state from persisted ActiveTimer and activity.
    /// Validates the persisted state before resuming — rejects startTimes
    /// in the future or with a startDate that doesn't match a recent day.
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

        // Reject startTime in the future — likely clock tampering
        guard startTime <= Date() else {
            #if DEBUG
            print("⚠️ TimerService: Persisted startTime is in the future, clearing stale timer")
            #endif
            try clearPersistedTimer()
            return
        }

        // Reject startDate more than 2 days ago — stale timer from days-old session
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Calendar.current.startOfDay(for: Date()))!
        guard startDate >= twoDaysAgo else {
            #if DEBUG
            print("⚠️ TimerService: Persisted startDate is too old (\(startDate)), clearing stale timer")
            #endif
            try clearPersistedTimer()
            return
        }

        // Resume the timer (resume() applies its own 24h cap)
        try resume(activity: activity, startTime: startTime, targetDate: startDate)
    }

    /// Gets the persisted ActiveTimer
    /// - Returns: The ActiveTimer singleton
    /// - Throws: Error if fetch fails
    public func getActiveTimer() throws -> ActiveTimer {
        return try ActiveTimer.shared(in: modelContext)
    }

    /// Ends all Live Activities (cleanup after force-kill or stale state).
    public func endAllLiveActivities() {
        #if os(iOS)
        liveActivityService.endAll()
        #endif
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

        // End all Live Activities (iOS only)
        #if os(iOS)
        liveActivityService.endAll()
        #endif

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

    /// Clears persisted ActiveTimer state without saving a time entry.
    /// Used when the persisted timer is stale or invalid (e.g. future startTime).
    private func clearPersistedTimer() throws {
        let activeTimer = try ActiveTimer.shared(in: modelContext)
        activeTimer.activityID = nil
        activeTimer.startTime = nil
        activeTimer.startDate = nil
        activeTimer.isRunning = false
        try modelContext.save()

        // Reset local state
        self.isRunning = false
        self.currentActivity = nil
        self.currentDate = nil
        self.startTime = nil
        self.elapsedTime = 0
    }

    /// Fetches the accumulated duration already logged for an activity on a given date.
    /// The Live Activity widget runs in a separate process and can't observe the app's
    /// in-memory timer state. We offset its start date by the accumulated time so the
    /// widget's `Text(.timerInterval:)` produces the same total as the in-app display.
    private func fetchAccumulatedTime(activityID: UUID, date: Date) -> TimeInterval {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let predicate = #Predicate<TimeEntry> { entry in
            entry.activityID == activityID && entry.date == normalizedDate
        }
        let descriptor = FetchDescriptor<TimeEntry>(predicate: predicate)
        return (try? modelContext.fetch(descriptor).first?.totalDuration) ?? 0
    }

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
        duration.formattedDuration(style: .timer)
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
