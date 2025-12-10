//
//  DataServiceWatchExtensions.swift
//  TimeMyLifeWatch Watch App
//
//  Workaround for SwiftData #Predicate reflection metadata issues
//  These methods avoid predicates by fetching all and filtering in memory
//

import Foundation
import SwiftData

extension DataService {
    /// Fetch activities with optional weekday filter - Watch app version
    /// Avoids #Predicate by fetching all and filtering in memory
    func fetchActivitiesForWatch(scheduledFor weekday: Int? = nil) throws -> [Activity] {
        // Fetch ALL activities without any predicate
        let descriptor = FetchDescriptor<Activity>(
            sortBy: [SortDescriptor(\.name)]
        )
        let allActivities = try modelContext.fetch(descriptor)

        // Filter in memory if needed
        if let weekday = weekday {
            return allActivities.filter { $0.scheduledDays.contains(weekday) }
        } else {
            return allActivities
        }
    }

    /// Fetch activity by ID - Watch app version
    /// Avoids #Predicate by fetching all and filtering in memory
    func fetchActivityForWatch(id: UUID) throws -> Activity? {
        // Fetch ALL activities without predicate, filter in memory
        let descriptor = FetchDescriptor<Activity>()
        let allActivities = try modelContext.fetch(descriptor)
        return allActivities.first { $0.id == id }
    }

    /// Fetch time entries for activity and date - Watch app version
    /// Avoids #Predicate by fetching all and filtering in memory
    func fetchTimeEntriesForWatch(for activityID: UUID, on date: Date) throws -> [TimeEntry] {
        let normalizedDate = Calendar.current.startOfDay(for: date)

        // Fetch ALL time entries without predicate, filter in memory
        let descriptor = FetchDescriptor<TimeEntry>()
        let allEntries = try modelContext.fetch(descriptor)
        return allEntries.filter { $0.activityID == activityID && $0.date == normalizedDate }
    }

    /// Fetch all time entries for activity - Watch app version
    /// Avoids #Predicate by fetching all and filtering in memory
    func fetchAllTimeEntriesForWatch(for activityID: UUID) throws -> [TimeEntry] {
        // Fetch ALL time entries without predicate, filter and sort in memory
        let descriptor = FetchDescriptor<TimeEntry>()
        let allEntries = try modelContext.fetch(descriptor)
        return allEntries
            .filter { $0.activityID == activityID }
            .sorted { $0.date > $1.date }
    }

    /// Fetch time entries in date range - Watch app version
    /// Avoids #Predicate by fetching all and filtering in memory
    func fetchTimeEntriesForWatch(
        for activityID: UUID? = nil,
        from startDate: Date,
        to endDate: Date
    ) throws -> [TimeEntry] {
        let normalizedStart = Calendar.current.startOfDay(for: startDate)
        let normalizedEnd = Calendar.current.startOfDay(for: endDate)

        // Fetch ALL time entries without predicate, filter and sort in memory
        let descriptor = FetchDescriptor<TimeEntry>()
        let allEntries = try modelContext.fetch(descriptor)

        let filtered: [TimeEntry]
        if let activityID = activityID {
            filtered = allEntries.filter {
                $0.activityID == activityID &&
                $0.date >= normalizedStart &&
                $0.date <= normalizedEnd
            }
        } else {
            filtered = allEntries.filter {
                $0.date >= normalizedStart &&
                $0.date <= normalizedEnd
            }
        }

        return filtered.sorted { $0.date > $1.date }
    }

    /// Check if activity exists by name - Watch app version
    /// Avoids #Predicate by fetching all and filtering in memory
    func activityExistsForWatch(withName name: String) throws -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fetch ALL activities without predicate, check in memory
        let descriptor = FetchDescriptor<Activity>()
        let allActivities = try modelContext.fetch(descriptor)
        return allActivities.contains { $0.name == trimmedName }
    }

    /// Delete all time entries for activity - Watch app version
    /// Avoids #Predicate by fetching all and filtering in memory
    @discardableResult
    func deleteAllTimeEntriesForWatch(for activityID: UUID) throws -> Int {
        // Fetch ALL time entries without predicate, filter in memory
        let descriptor = FetchDescriptor<TimeEntry>()
        let allEntries = try modelContext.fetch(descriptor)
        let entriesToDelete = allEntries.filter { $0.activityID == activityID }

        for entry in entriesToDelete {
            modelContext.delete(entry)
        }

        try modelContext.save()
        return entriesToDelete.count
    }
}
