//
//  CRUDTestViewModel.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for CRUD testing and debugging
/// Provides test operations for development and QA
@Observable
@MainActor
public class CRUDTestViewModel {
    // MARK: - Observable Properties

    /// Number of activities in database
    public var activityCount: Int = 0

    /// Number of time entries in database
    public var timeEntryCount: Int = 0

    /// Operation log for displaying test results
    public var operationLog: [String] = []

    /// Error state
    public var error: Error?

    /// Error message for alert
    public var errorMessage: String = ""

    /// Whether to show error alert
    public var showError: Bool = false

    public var dataService: DataService
    public var timerService: TimerService
    // MARK: - Initialization

    public init(dataService: DataService, timerService: TimerService) {
        self.dataService = dataService
        self.timerService = timerService
    }

    // MARK: - Data Overview

    /// Loads the current counts of activities and time entries
    public func loadCounts() async {
        do {
            activityCount = try dataService.getActivityCount()

            // Get all activities and count their entries
            let activities = try dataService.fetchActivities(scheduledFor: nil)
            var totalEntries = 0
            for activity in activities {
                let entries = try dataService.fetchAllTimeEntries(for: activity.id)
                totalEntries += entries.count
            }
            timeEntryCount = totalEntries
        } catch {
            self.error = error
            #if DEBUG
            print("❌ CRUDTestViewModel: Failed to load counts: \(error)")
            #endif
        }
    }

    // MARK: - Test Operations

    /// Tests creating an activity
    public func testCreate() async {
        do {
            let testActivity = try Activity.validated(
                name: "Test Activity \(Date().timeIntervalSince1970)",
                colorHex: "#FF5733",
                category: "Test",
                scheduledDays: [1, 2, 3, 4, 5]
            )

            try dataService.createActivity(testActivity)
            logOperation("✅ CREATE: Created activity '\(testActivity.name)'")
            await loadCounts()
        } catch {
            showErrorAlert("CREATE failed: \(error.localizedDescription)")
        }
    }

    /// Tests reading an activity
    public func testRead() async {
        do {
            let activities = try dataService.fetchActivities(scheduledFor: nil)
            guard let firstActivity = activities.first else {
                logOperation("⚠️ READ: No activities to read")
                return
            }

            let activity = try? dataService.fetchActivity(id: firstActivity.id)
            if let activity = activity {
                logOperation("✅ READ: Found activity '\(activity.name)'")
            } else {
                logOperation("⚠️ READ: Activity not found")
            }
        } catch {
            showErrorAlert("READ failed: \(error.localizedDescription)")
        }
    }

    /// Tests updating an activity
    public func testUpdate() async {
        do {
            let activities = try dataService.fetchActivities(scheduledFor: nil)
            guard let firstActivity = activities.first else {
                logOperation("⚠️ UPDATE: No activities to update")
                return
            }

            let oldName = firstActivity.name
            let newName = "Updated \(oldName)"

            firstActivity.name = newName
            try dataService.updateActivity(firstActivity)

            logOperation("✅ UPDATE: Renamed '\(oldName)' → '\(newName)'")
            await loadCounts()
        } catch {
            showErrorAlert("UPDATE failed: \(error.localizedDescription)")
        }
    }

    /// Tests deleting an activity
    public func testDelete() async {
        do {
            let activities = try dataService.fetchActivities(scheduledFor: nil)
            guard let lastActivity = activities.last else {
                logOperation("⚠️ DELETE: No activities to delete")
                return
            }

            let name = lastActivity.name
            try dataService.deleteActivity(lastActivity)
            logOperation("✅ DELETE: Deleted activity '\(name)'")
            await loadCounts()
        } catch {
            showErrorAlert("DELETE failed: \(error.localizedDescription)")
        }
    }

    /// Tests timer operations
    public func testTimer() async {
        do {
            let activities = try dataService.fetchActivities(scheduledFor: nil)
            guard let testActivity = activities.first else {
                // Create a test activity if none exists
                let newActivity = try Activity.validated(
                    name: "Timer Test Activity",
                    colorHex: "#3498db",
                    category: "Test",
                    scheduledDays: [1, 2, 3, 4, 5, 6, 7]
                )
                try dataService.createActivity(newActivity)
                logOperation("✅ Created test activity for timer test")
                try await testTimer() // Retry
                return
            }

            // Start timer
            let startDate = Date()
            try timerService.start(activity: testActivity, targetDate: startDate)
            logOperation("⏱️ TIMER: Started for '\(testActivity.name)'")

            // Simulate some time passing
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            // Stop timer
            guard let timerData = try timerService.stop() else {
                logOperation("⚠️ TIMER: No timer was running")
                return
            }

            // Save the duration
            try dataService.createOrUpdateTimeEntry(
                activityID: timerData.activityID,
                date: timerData.date,
                duration: timerData.duration
            )

            logOperation("✅ TIMER: Stopped (elapsed: \(String(format: "%.3f", timerData.duration))s)")
            await loadCounts()
        } catch {
            showErrorAlert("TIMER test failed: \(error.localizedDescription)")
        }
    }

    /// Adds large time value to first activity
    public func addLargeTime(hours: Double) async {
        do {
            let activities = try dataService.fetchActivities(scheduledFor: nil)
            guard let firstActivity = activities.first else {
                logOperation("⚠️ No activities found")
                return
            }

            let duration = hours * 3600 // Convert hours to seconds
            let today = Calendar.current.startOfDay(for: Date())

            try dataService.createOrUpdateTimeEntry(
                activityID: firstActivity.id,
                date: today,
                duration: duration
            )

            logOperation("✅ Added \(String(format: "%.1f", hours)) hours to '\(firstActivity.name)'")
            await loadCounts()
        } catch {
            showErrorAlert("Failed to add time: \(error.localizedDescription)")
        }
    }

    /// Creates an activity with large time value
    public func createActivityWithLargeTime(hours: Double) async {
        do {
            let activity = try Activity.validated(
                name: "\(String(format: "%.0f", hours)) Hour Activity",
                colorHex: "#e74c3c",
                category: "Large Time Test",
                scheduledDays: [1, 2, 3, 4, 5, 6, 7]
            )

            try dataService.createActivity(activity)

            let duration = hours * 3600
            let today = Calendar.current.startOfDay(for: Date())

            try dataService.createOrUpdateTimeEntry(
                activityID: activity.id,
                date: today,
                duration: duration
            )

            logOperation("✅ Created '\(activity.name)' with \(String(format: "%.1f", hours)) hours")
            await loadCounts()
        } catch {
            showErrorAlert("Failed to create activity: \(error.localizedDescription)")
        }
    }

    /// Clears all data from the database
    public func clearAllData() async {
        do {
            try dataService.clearAllData()
            try timerService.reset()
            operationLog.removeAll()
            logOperation("✅ Cleared all data")
            await loadCounts()
        } catch {
            showErrorAlert("Clear failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    /// Logs an operation to the operation log
    private func logOperation(_ message: String) {
        let timestamp = DateFormatter.localizedString(
            from: Date(),
            dateStyle: .none,
            timeStyle: .medium
        )
        operationLog.append("[\(timestamp)] \(message)")

        // Keep only last 20 operations
        if operationLog.count > 20 {
            operationLog.removeFirst()
        }
    }

    /// Shows an error alert
    private func showErrorAlert(_ message: String) {
        errorMessage = message
        showError = true
        logOperation("❌ ERROR: \(message)")
    }
}
