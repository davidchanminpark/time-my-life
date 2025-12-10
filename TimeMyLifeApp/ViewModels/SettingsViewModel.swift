//
//  SettingsViewModel.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for the settings/all activities screen
/// Handles loading all activities and deletion
@Observable
@MainActor
public class SettingsViewModel {
    // MARK: - Observable Properties

    /// All activities sorted by name
    public var activities: [Activity] = []

    /// Whether activities are currently loading
    public var isLoading = false

    /// Error state
    public var error: Error?

    /// Alert message for errors
    public var alertMessage: String?
    
    /// Backing data service
    public var dataService: DataService
    
    // MARK: - Initialization

    public init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Public Methods

    /// Loads all activities sorted by name
    public func loadActivities() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch all activities (no weekday filter)
            #if os(watchOS)
            activities = try dataService.fetchActivitiesForWatch(scheduledFor: nil)
            #else
            activities = try dataService.fetchActivities(scheduledFor: nil)
            #endif

            #if DEBUG
            print("✅ SettingsViewModel: Loaded \(activities.count) activities")
            #endif
        } catch {
            self.error = error
            self.alertMessage = "Failed to load activities"
            #if DEBUG
            print("❌ SettingsViewModel: Failed to load activities: \(error)")
            #endif
        }
    }

    /// Deletes an activity and all associated time entries
    /// - Parameter activity: Activity to delete
    public func deleteActivity(_ activity: Activity) async {
        do {
            try dataService.deleteActivity(activity)

            #if DEBUG
            print("✅ SettingsViewModel: Deleted activity '\(activity.name)'")
            #endif

            // Reload activities to update the list
            await loadActivities()
        } catch {
            self.error = error
            self.alertMessage = "Failed to delete activity"
            #if DEBUG
            print("❌ SettingsViewModel: Failed to delete activity: \(error)")
            #endif
        }
    }

    /// Gets the count of activities
    /// - Returns: Total number of activities
    public func getActivityCount() -> Int {
        return activities.count
    }
}

