//
//  TimerViewModel.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftUI
import Combine
import Observation

/// ViewModel for the activity timer screen
/// Handles timer control and accumulated time display
@Observable
@MainActor
public class TimerViewModel {
    // MARK: - Observable Properties

    /// Current elapsed time from the running timer
    public var elapsedTime: TimeInterval = 0

    /// Accumulated time for this activity on the target date (from TimeEntry)
    public var accumulatedTime: TimeInterval = 0

    /// Whether the timer is currently running for this activity/date
    public var isRunning: Bool = false

    /// Error state
    public var error: Error?

    /// Alert message
    public var alertMessage: String?

    // MARK: - Properties

    public let activity: Activity
    public let targetDate: Date

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks for platform-specific features

    /// Callback for starting platform-specific background session (e.g., WKExtendedRuntimeSession)
    public var onStartBackgroundSession: (() -> Void)?

    /// Callback for stopping platform-specific background session
    public var onStopBackgroundSession: (() -> Void)?

    public var dataService: DataService
    public var timerService: TimerService
    // MARK: - Initialization

    public init(
        activity: Activity,
        targetDate: Date,
        dataService: DataService,
        timerService: TimerService
    ) {
        self.activity = activity
        self.targetDate = targetDate
        self.dataService = dataService
        self.timerService = timerService

        // Subscribe to timer service updates
        setupTimerObserver()
    }

    // MARK: - Public Methods

    /// Loads the accumulated time for this activity on the target date
    public func loadAccumulatedTime() async {
        do {
            #if os(watchOS)
            let entries = try dataService.fetchTimeEntriesForWatch(for: activity.id, on: targetDate)
            #else
            let entries = try dataService.fetchTimeEntries(for: activity.id, on: targetDate)
            #endif
            accumulatedTime = entries.first?.totalDuration ?? 0
        } catch {
            self.error = error
            #if DEBUG
            print("❌ TimerViewModel: Failed to load accumulated time: \(error)")
            #endif
        }
    }

    /// Starts the timer for the activity
    public func startTimer() {
        do {
            try timerService.start(activity: activity, targetDate: targetDate)

            // Call platform-specific background session start
            onStartBackgroundSession?()

            #if DEBUG
            print("✅ TimerViewModel: Started timer for '\(activity.name)'")
            #endif
        } catch {
            self.error = error
            alertMessage = "Failed to start timer: \(error.localizedDescription)"
            #if DEBUG
            print("❌ TimerViewModel: Failed to start timer: \(error)")
            #endif
        }
    }

    /// Stops the timer and updates accumulated time
    public func stopTimer() async {
        do {
            // Stop the timer and get the data
            guard let timerData = try timerService.stop() else {
                #if DEBUG
                print("⚠️ TimerViewModel: No timer was running")
                #endif
                return
            }

            // Call platform-specific background session stop
            onStopBackgroundSession?()

            // Save the duration to TimeEntry (orchestration!)
            try dataService.createOrUpdateTimeEntry(
                activityID: timerData.activityID,
                date: timerData.date,
                duration: timerData.duration
            )

            #if DEBUG
            print("✅ TimerViewModel: Stopped timer and saved duration: \(formatDuration(timerData.duration))")
            #endif

            // Reload accumulated time
            await loadAccumulatedTime()
        } catch {
            self.error = error
            alertMessage = "Failed to stop timer: \(error.localizedDescription)"
            #if DEBUG
            print("❌ TimerViewModel: Failed to stop timer: \(error)")
            #endif
        }
    }

    /// Checks if the timer should be resumed (if it was already running)
    public func checkAndResumeTimer() {
        // Check if this activity's timer is running for this date
        if timerService.isTimerRunning(for: activity, on: targetDate) {
            elapsedTime = timerService.getCurrentElapsedTime()

            // Resume platform-specific background session if needed
            onStartBackgroundSession?()

            #if DEBUG
            print("✅ TimerViewModel: Resumed timer for '\(activity.name)', elapsed: \(formatDuration(elapsedTime))")
            #endif
        }
    }

    /// Formats a duration as HH:MM:SS or MM:SS
    public func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    /// Calculates dynamic font size based on elapsed time
    public var timerFontSize: CGFloat {
        let hours = Int(elapsedTime) / 3600
        if hours < 1 {
            return 80  // MM:SS format - largest
        } else if hours < 100 {
            return 48  // 2-digit hours - medium
        } else {
            return 40  // 3-digit hours - smallest
        }
    }

    // MARK: - Lifecycle

    /// Called when the view appears - checks if timer should be resumed
    public func onAppear() {
        Task {
            await loadAccumulatedTime()
            checkAndResumeTimer()
        }
    }

    /// Called when the view disappears - stops background session if needed
    public func onDisappear() {
        // Only stop background session if this timer is still running
        // (user might have switched to another screen)
        if isRunning {
            onStopBackgroundSession?()
        }
    }

    // MARK: - Private Methods

    /// Sets up observer for timer service updates
    private func setupTimerObserver() {
        // Observe elapsed time from timer service
        timerService.elapsedTimePublisher
            .sink { [weak self] time in
                guard let self = self else { return }
                // Only update if it's for our activity and date
                if self.timerService.isTimerRunning(for: self.activity, on: self.targetDate) {
                    self.elapsedTime = time
                }
            }
            .store(in: &cancellables)

        // Observe running state from timer service
        timerService.isRunningPublisher
            .map { [weak self] isRunning in
                guard let self = self else { return false }
                // Only consider running if it's for our activity and date
                return isRunning && self.timerService.isTimerRunning(for: self.activity, on: self.targetDate)
            }
            .sink { [weak self] isRunning in
                self?.isRunning = isRunning
            }
            .store(in: &cancellables)
    }
}
