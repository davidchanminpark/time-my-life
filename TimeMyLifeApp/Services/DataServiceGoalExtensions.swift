//
//  DataServiceGoalExtensions.swift
//  TimeMyLifeApp
//
//  Goal CRUD + `handleGoalSync`. Must be part of the Watch app target if `DataService.swift` is shared
//  (add `Services/DataServiceGoalExtensions.swift` to the Watch target’s synchronized exceptions).
//

import Foundation
import SwiftData

extension DataService {

    // MARK: - Goal CRUD

    public func fetchGoals(frequency: GoalFrequency? = nil, activeOnly: Bool = true) throws -> [Goal] {
        var descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdDate)])
        // SwiftData cannot filter on enum properties via #Predicate at runtime (computed rawValue access crashes).
        // Fetch with isActive predicate only (a plain Bool), then filter frequency in-memory.
        if activeOnly {
            descriptor.predicate = #Predicate<Goal> { $0.isActive == true }
        }
        let results = try modelContext.fetch(descriptor)
        guard let frequency else { return results }
        return results.filter { $0.frequency == frequency }
    }

    public func fetchGoal(id: UUID) throws -> Goal? {
        let predicate = #Predicate<Goal> { $0.id == id }
        var descriptor = FetchDescriptor<Goal>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    public func fetchGoal(activityID: UUID, frequency: GoalFrequency) throws -> Goal? {
        let predicate = #Predicate<Goal> { $0.activityID == activityID && $0.isActive == true }
        var descriptor = FetchDescriptor<Goal>(predicate: predicate)
        return try modelContext.fetch(descriptor).first { $0.frequency == frequency }
    }

    public func goalExists(activityID: UUID, frequency: GoalFrequency) throws -> Bool {
        let predicate = #Predicate<Goal> { $0.activityID == activityID && $0.isActive == true }
        var descriptor = FetchDescriptor<Goal>(predicate: predicate)
        descriptor.fetchLimit = 1
        let results = try modelContext.fetch(descriptor)
        return results.contains { $0.frequency == frequency }
    }

    /// Reorders goals by updating their sortOrder values
    /// - Parameter goals: Goals in their new order
    /// - Throws: Error if save fails
    public func reorderGoals(_ goals: [Goal]) throws {
        for (index, goal) in goals.enumerated() {
            goal.sortOrder = index
        }
        try modelContext.save()
    }

    public func createGoal(_ goal: Goal) throws {
        try validateGoal(goal)
        if try goalExists(activityID: goal.activityID, frequency: goal.frequency) {
            throw DataServiceValidationError.duplicateGoal
        }

        modelContext.insert(goal)
        try modelContext.save()

        Task {
            try? await syncService?.syncModel(goal, type: .goal, action: .create)
        }
    }

    public func updateGoal(_ goal: Goal) throws {
        try validateGoal(goal)
        try modelContext.save()

        Task {
            try? await syncService?.syncModel(goal, type: .goal, action: .update)
        }
    }

    // MARK: - Goal Validation

    private func validateGoal(_ goal: Goal) throws {
        let minTarget = 15 * 60   // 15 minutes
        let maxTarget = 24 * 3600 // 24 hours
        guard goal.targetSeconds >= minTarget, goal.targetSeconds <= maxTarget else {
            throw DataServiceValidationError.goalTargetOutOfRange
        }
        guard try fetchActivity(id: goal.activityID) != nil else {
            throw DataServiceValidationError.activityNotFound(goal.activityID)
        }
    }

    public func deleteGoal(_ goal: Goal) throws {
        let goalID = goal.id
        modelContext.delete(goal)
        try modelContext.save()

        Task {
            try? await syncService?.syncDelete(id: goalID, type: .goal)
        }
    }

    // MARK: - Sync (Goal)

    /// Applies a goal sync message from the counterpart device (WatchConnectivity / etc.).
    func handleGoalSync(_ message: SyncMessage) async throws {
        switch message.action {
        case .create, .update:
            let goal = try JSONDecoder().decode(Goal.self, from: message.data)

            // Validate synced data
            let minTarget = 15 * 60   // 15 minutes (matches UI stepper minimum)
            let maxTarget = 24 * 3600 // 24 hours
            guard goal.targetSeconds >= minTarget, goal.targetSeconds <= maxTarget else {
                print("❌ Sync rejected: goal targetSeconds out of range (\(goal.targetSeconds))")
                return
            }
            // Verify the referenced activity exists
            guard try fetchActivity(id: goal.activityID) != nil else {
                print("❌ Sync rejected: no activity found for goal's activityID \(goal.activityID)")
                return
            }
            // Prevent duplicate goals (same activity + frequency) for new goals
            if try fetchGoal(id: goal.id) == nil {
                if try goalExists(activityID: goal.activityID, frequency: goal.frequency) {
                    print("❌ Sync rejected: duplicate goal for activity \(goal.activityID) / \(goal.frequency.rawValue)")
                    return
                }
            }

            if let existing = try fetchGoal(id: goal.id) {
                existing.activityID = goal.activityID
                existing.frequency = goal.frequency
                existing.targetSeconds = goal.targetSeconds
                existing.isActive = goal.isActive
                existing.createdDate = goal.createdDate
                try modelContext.save()
            } else {
                modelContext.insert(goal)
                try modelContext.save()
            }
        case .delete:
            guard let goalID = UUID(uuidString: message.modelId),
                  let goal = try fetchGoal(id: goalID) else { return }
            modelContext.delete(goal)
            try modelContext.save()
        }
    }
}
