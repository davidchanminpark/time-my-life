//
//  EditTimeEntryViewModel.swift
//  TimeMyLifeApp
//

import Foundation
import Observation

/// Powers the Edit Time Entry sheet: lists the most-recent time entries for an
/// activity (within the last 7 days, capped at 5 rows) and lets the user
/// overwrite the duration via an hours/minutes picker.
@Observable
@MainActor
final class EditTimeEntryViewModel {

    // MARK: - State

    let activity: Activity

    /// Most-recent entries for `activity` from the last 7 days, newest first.
    /// Empty if no entries exist in the window.
    var recentEntries: [TimeEntry] = []

    /// The entry the user has selected to edit. `nil` until the user picks one.
    var selectedEntry: TimeEntry? {
        didSet { syncDurationPickerToSelection() }
    }

    /// Hour component of the duration picker (0...23).
    var selectedHour: Int = 0

    /// Minute component of the duration picker (0...59).
    var selectedMinute: Int = 0

    var isSaving = false
    var errorMessage: String?

    // MARK: - Computed

    /// Combined duration in seconds from the picker components.
    var totalSeconds: TimeInterval {
        TimeInterval(selectedHour * 3600 + selectedMinute * 60)
    }

    /// Whether the current picker state represents a valid save (an entry is
    /// selected and the duration differs from the entry's existing value).
    var canSave: Bool {
        guard let selected = selectedEntry else { return false }
        return totalSeconds != selected.totalDuration
    }

    // MARK: - Init

    private let dataService: DataService

    init(activity: Activity, dataService: DataService) {
        self.activity = activity
        self.dataService = dataService
    }

    // MARK: - Load

    /// Fetches up to 5 of the most recent time entries for the activity that
    /// fall within the last 7 days (today inclusive). Sorted newest-first.
    func loadRecentEntries() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let startDate = cal.date(byAdding: .day, value: -6, to: today) else {
            recentEntries = []
            return
        }

        do {
            let all = try dataService.fetchTimeEntries(
                for: activity.id,
                from: startDate,
                to: today
            )
            recentEntries = all
                .filter { $0.totalDuration > 0 }
                .sorted { $0.date > $1.date }
                .prefix(5)
                .map { $0 }
        } catch {
            recentEntries = []
            errorMessage = "Failed to load recent entries"
        }
    }

    // MARK: - Save

    /// Persists the picker's duration onto the selected entry. Returns `true`
    /// on success so the caller can dismiss the sheet.
    @discardableResult
    func save() async -> Bool {
        guard let entry = selectedEntry else {
            errorMessage = "Select a time entry first"
            return false
        }
        isSaving = true
        defer { isSaving = false }

        do {
            try dataService.setTimeEntryDuration(
                activityID: entry.activityID,
                date: entry.date,
                duration: totalSeconds
            )
            return true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Helpers

    /// Resets the duration picker to match `selectedEntry`'s current duration.
    private func syncDurationPickerToSelection() {
        guard let entry = selectedEntry else {
            selectedHour = 0
            selectedMinute = 0
            return
        }
        let totalMinutes = Int(entry.totalDuration) / 60
        selectedHour = min(23, totalMinutes / 60)
        selectedMinute = totalMinutes % 60
    }
}
