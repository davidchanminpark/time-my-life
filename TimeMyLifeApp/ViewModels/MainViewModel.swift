//
//  MainViewModel.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for the main activity list screen
/// Handles activity filtering, midnight mode, and timer status
@Observable
@MainActor
public class MainViewModel {
    // MARK: - Observable Properties

    /// List of activities to display (filtered by selected day)
    public var activities: [Activity] = []

    /// Current view mode (today or yesterday)
    public var viewMode: ViewMode = .today

    /// Whether to show the midnight mode prompt
    public var showMidnightPrompt = false

    /// Whether to show the activity limit alert
    public var showActivityLimitAlert = false

    /// Loading state
    public var isLoading = false

    /// Error state
    public var error: Error?

    /// Refresh trigger - increment this to force view updates
    public var refreshTrigger: Int = 0

    public var dataService: DataService
    public var timerService: TimerService
    // MARK: - View Mode

    public enum ViewMode: String, CaseIterable {
        case yesterday = "Yesterday"
        case today = "Today"
    }

    // MARK: - Initialization

    public init(dataService: DataService, timerService: TimerService) {
        self.dataService = dataService
        self.timerService = timerService

        // Listen for synced time entries
        NotificationCenter.default.addObserver(
            forName: .timeEntryDidSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActivities()
                self?.refreshTrigger += 1
            }
        }

        // Listen for synced activities
        NotificationCenter.default.addObserver(
            forName: .activityDidSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadActivities()
                self?.refreshTrigger += 1
            }
        }
    }

    // MARK: - Public Methods

    /// Loads activities for the current view mode
    public func loadActivities() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let weekday = targetWeekday
            let fetchedActivities = try dataService.fetchActivities(scheduledFor: weekday)

            // Force update by creating a new array to trigger SwiftUI observation
            activities = []
            activities = fetchedActivities

            #if DEBUG
            print("🔄 MainViewModel: Loaded \(fetchedActivities.count) activities for weekday \(weekday)")
            #endif
        } catch {
            self.error = error
            #if DEBUG
            print("❌ MainViewModel: Failed to load activities: \(error)")
            #endif
        }
    }

    /// Checks if we should show the midnight mode prompt
    /// - Parameter midnightPreference: Current user preference
    /// - Parameter lastPromptDate: Last date the prompt was shown
    /// - Parameter todayDateString: Today's date as string
    /// - Returns: True if prompt should be shown
    public func shouldShowMidnightPrompt(
        midnightPreference: String,
        lastPromptDate: String,
        todayDateString: String
    ) -> Bool {
        guard isMidnightHours else { return false }

        // Check if we've already prompted today
        if lastPromptDate != todayDateString {
            // Haven't prompted today - show the prompt
            return true
        } else if midnightPreference == "unset" {
            // First time ever - show the prompt
            return true
        }

        return false
    }

    /// Checks if the day toggle should be shown
    /// - Parameter midnightPreference: Current user preference
    /// - Parameter lastPromptDate: Last date the prompt was shown
    /// - Parameter todayDateString: Today's date as string
    /// - Returns: True if toggle should be shown
    public func shouldShowDayToggle(
        midnightPreference: String,
        lastPromptDate: String,
        todayDateString: String
    ) -> Bool {
        guard isMidnightHours else { return false }

        switch midnightPreference {
        case "always":
            return true
        case "today":
            return lastPromptDate == todayDateString
        case "no":
            return false
        default:
            return false
        }
    }

    /// Gets the duration for an activity on the target date
    /// - Parameter activity: Activity to check
    /// - Returns: Total duration in seconds
    public func durationForDate(activity: Activity) -> TimeInterval {
        do {
            let entries = try dataService.fetchTimeEntries(for: activity.id, on: targetDate)
            return entries.first?.totalDuration ?? 0
        } catch {
            #if DEBUG
            print("❌ MainViewModel: Failed to fetch duration: \(error)")
            #endif
            return 0
        }
    }

    /// Checks if a timer is running for the given activity on the target date
    /// - Parameter activity: Activity to check
    /// - Returns: True if timer is running for this activity on target date
    public func isTimerRunning(for activity: Activity) -> Bool {
        return timerService.isTimerRunning(for: activity, on: targetDate)
    }

    /// Checks if the activity limit has been reached
    /// - Returns: True if at or above limit (30)
    public func isActivityLimitReached() -> Bool {
        do {
            let count = try dataService.getActivityCount()
            return count >= 30
        } catch {
            #if DEBUG
            print("❌ MainViewModel: Failed to check activity count: \(error)")
            #endif
            return false
        }
    }

    /// Switches the view mode and reloads activities
    /// - Parameter mode: New view mode to set
    public func switchViewMode(to mode: ViewMode) async {
        viewMode = mode
        await loadActivities()
    }

    // MARK: - Computed Properties

    /// Current weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    /// Yesterday's weekday
    private var yesterdayWeekday: Int {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return Calendar.current.component(.weekday, from: yesterday)
    }

    /// Target weekday based on view mode
    private var targetWeekday: Int {
        viewMode == .yesterday ? yesterdayWeekday : currentWeekday
    }

    /// Target date based on view mode
    public var targetDate: Date {
        let today = Calendar.current.startOfDay(for: Date())
        if viewMode == .yesterday {
            return Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today
        }
        return today
    }

    /// Check if current time is between midnight and 5 AM
    private var isMidnightHours: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= 0 && hour < 5
    }
}
