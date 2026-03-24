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
        let descriptor = FetchDescriptor<Goal>(sortBy: [SortDescriptor(\.createdDate)])
        let all = try modelContext.fetch(descriptor)
        return all.filter { goal in
            let frequencyMatch = frequency == nil || goal.frequency == frequency
            let activeMatch = !activeOnly || goal.isActive
            return frequencyMatch && activeMatch
        }
    }

    public func fetchGoal(id: UUID) throws -> Goal? {
        let descriptor = FetchDescriptor<Goal>()
        return try modelContext.fetch(descriptor).first { $0.id == id }
    }

    public func goalExists(activityID: UUID, frequency: GoalFrequency) throws -> Bool {
        let descriptor = FetchDescriptor<Goal>()
        let all = try modelContext.fetch(descriptor)
        return all.contains { $0.activityID == activityID && $0.frequency == frequency && $0.isActive }
    }

    public func createGoal(_ goal: Goal) throws {
        modelContext.insert(goal)
        try modelContext.save()

        Task {
            try? await syncService?.syncModel(goal, type: .goal, action: .create)
        }
    }

    public func updateGoal(_ goal: Goal) throws {
        try modelContext.save()

        Task {
            try? await syncService?.syncModel(goal, type: .goal, action: .update)
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
