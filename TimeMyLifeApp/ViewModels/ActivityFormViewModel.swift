//
//  ActivityFormViewModel.swift
//  TimeMyLifeCore
//

import Foundation
import SwiftUI
import SwiftData
import Observation

/// Mode for activity form (create new or edit existing)
public enum ActivityFormMode {
    case create
    case edit(Activity)

    public var title: String {
        switch self {
        case .create: return "Add Activity"
        case .edit: return "Edit Activity"
        }
    }

    public var saveButtonTitle: String {
        return "Save"
    }
}

/// ViewModel for the activity form (create/edit)
/// Handles validation, saving, and deletion
@Observable
@MainActor
public class ActivityFormViewModel {
    // MARK: - Observable Properties

    /// Activity name
    public var name: String = ""

    /// Activity category
    public var category: String = ""

    /// Selected color hex value
    public var selectedColorHex: String = "#BFC8FF"

    /// Selected weekdays (1=Sunday, 2=Monday, ..., 7=Saturday)
    public var selectedDays: Set<Int> = []

    /// Validation error message
    public var validationError: String?

    /// Whether the form is currently saving
    public var isSaving = false

    /// Error state
    public var error: Error?

    /// Whether to show delete confirmation
    public var showDeleteConfirmation = false

    // MARK: - Properties

    public let mode: ActivityFormMode

    private let dataService: DataService
    // MARK: - Initialization

    public init(mode: ActivityFormMode, dataService: DataService) {
        self.mode = mode
        self.dataService = dataService

        // Initialize fields based on mode
        switch mode {
        case .create:
            // Set today as default selected day
            selectedDays = [Calendar.current.component(.weekday, from: Date())]

        case .edit(let activity):
            name = activity.name
            category = activity.category
            selectedColorHex = activity.colorHex
            selectedDays = Set(activity.scheduledDayInts)
        }
    }

    // MARK: - Computed Properties

    /// Trimmed activity name
    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trimmed category name
    public var trimmedCategory: String {
        category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Whether the form has required fields filled (for UI feedback)
    /// Note: Full validation happens in Activity.validated()
    public var isValid: Bool {
        // Basic UI checks - just enough to enable/disable Save button
        let hasName = !trimmedName.isEmpty
        let hasAtLeastOneDay = !selectedDays.isEmpty

        // For create mode, check activity limit (UI-specific rule)
        if case .create = mode {
            do {
                let count = try dataService.getActivityCount()
                return hasName && hasAtLeastOneDay && count < 30
            } catch {
                return false
            }
        }

        return hasName && hasAtLeastOneDay
    }

    /// Name validation error message (for real-time UI feedback)
    public var nameValidationError: String? {
        // Only show error if user has typed something
        guard !name.isEmpty else { return nil }

        if trimmedName.isEmpty {
            return "Activity name is required"
        } else if trimmedName.count > 30 {
            return "Activity name must be 30 characters or less"
        }
        return nil
    }

    /// Category validation error message (for real-time UI feedback)
    public var categoryValidationError: String? {
        // Only show error if user has typed something
        guard !category.isEmpty else { return nil }

        if trimmedCategory.count > 20 {
            return "Category must be 20 characters or less"
        }
        return nil
    }

    /// Activity limit error message (create mode only)
    public var activityLimitError: String? {
        if case .create = mode {
            do {
                let count = try dataService.getActivityCount()
                if count >= 30 {
                    return "Maximum 30 activities allowed"
                }
            } catch {
                return "Failed to check activity limit"
            }
        }
        return nil
    }

    /// Characters remaining for name
    public var nameCharactersRemaining: Int {
        30 - trimmedName.count
    }

    /// Characters remaining for category
    public var categoryCharactersRemaining: Int {
        20 - trimmedCategory.count
    }

    // MARK: - Public Methods

    /// Quick pre-validation check (UI-specific rules only)
    /// Note: Full domain validation happens in Activity.validated()
    /// - Returns: True if basic UI rules pass
    private func preValidate() -> Bool {
        validationError = nil

        // Check UI-specific rule: activity limit (not a domain rule)
        if let limitError = activityLimitError {
            validationError = limitError
            return false
        }

        return true
    }

    /// Saves the activity (create or update)
    /// - Returns: True if saved successfully
    @discardableResult
    public func save() async throws -> Bool {
        // Quick pre-check for UI-specific rules
        guard preValidate() else {
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            switch mode {
            case .create:
                // Create new activity - validation happens in Activity.validated()
                let newActivity = try Activity.validated(
                    name: trimmedName,
                    colorHex: selectedColorHex,
                    category: trimmedCategory.isEmpty ? "Uncategorized" : trimmedCategory,
                    scheduledDays: Array(selectedDays)
                )
                
                // Ensure scheduled days have proper relationship
                for day in newActivity.scheduledDays {
                    day.activity = newActivity
                }

                try dataService.createActivity(newActivity)

                #if DEBUG
                print("✅ ActivityFormViewModel: Created activity '\(newActivity.name)'")
                #endif

            case .edit(let activity):
                // Validate domain rules with Activity.validated()
                _ = try Activity.validated(
                    name: trimmedName,
                    colorHex: selectedColorHex,
                    category: trimmedCategory.isEmpty ? "Uncategorized" : trimmedCategory,
                    scheduledDays: Array(selectedDays)
                )

                // Update existing activity
                activity.name = trimmedName
                activity.colorHex = selectedColorHex
                activity.category = trimmedCategory.isEmpty ? "Uncategorized" : trimmedCategory
                
                // Update scheduled days - remove old ones and create new ones
                // Delete old scheduled days
                for day in activity.scheduledDays {
                    // SwiftData will handle cascade delete, but we need to remove from array first
                }
                activity.scheduledDays.removeAll()
                
                // Create new scheduled days
                let newDays = Array(selectedDays).sorted().map { weekday in
                    ScheduledDay(weekday: weekday, activity: activity)
                }
                activity.scheduledDays = newDays

                try dataService.updateActivity(activity)

                #if DEBUG
                print("✅ ActivityFormViewModel: Updated activity '\(activity.name)'")
                #endif
            }

            return true
        } catch let error as ActivityValidationError {
            // Convert model validation errors to UI error messages
            validationError = error.localizedDescription
            self.error = error
            throw error
        } catch {
            validationError = "Failed to save activity"
            self.error = error
            #if DEBUG
            print("❌ ActivityFormViewModel: Failed to save: \(error)")
            #endif
            throw error
        }
    }

    /// Deletes the activity (edit mode only)
    /// - Returns: True if deleted successfully
    @discardableResult
    public func delete() async throws -> Bool {
        guard case .edit(let activity) = mode else {
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try dataService.deleteActivity(activity)

            #if DEBUG
            print("✅ ActivityFormViewModel: Deleted activity '\(activity.name)'")
            #endif

            return true
        } catch {
            self.error = error
            #if DEBUG
            print("❌ ActivityFormViewModel: Failed to delete: \(error)")
            #endif
            throw error
        }
    }

    /// Updates the name field with character limit enforcement
    /// - Parameter newValue: New name value
    public func updateName(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 30 {
            name = String(trimmed.prefix(30))
        } else {
            name = trimmed
        }
    }

    /// Updates the category field with character limit enforcement
    /// - Parameter newValue: New category value
    public func updateCategory(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 20 {
            category = String(trimmed.prefix(20))
        } else {
            category = trimmed
        }
    }
}
