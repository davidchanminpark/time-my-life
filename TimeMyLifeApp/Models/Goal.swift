//
//  Goal.swift
//  TimeMyLifeApp
//

import Foundation
import SwiftData

/// Frequency options for goals
public enum GoalFrequency: String, Codable {
    case daily
    case weekly
}

/// Represents a goal for tracking activity progress
@Model
public final class Goal {
    // MARK: - Properties

    /// Unique identifier for the goal
    public var id: UUID

    /// Reference to the activity this goal tracks
    public var activityID: UUID

    /// Frequency of the goal (daily or weekly)
    public var frequency: GoalFrequency

    /// Target duration in seconds
    public var targetSeconds: Int

    /// Whether the goal is active
    public var isActive: Bool

    /// Timestamp when the goal was created
    public var createdDate: Date

    /// Running streak count, updated incrementally when goals are loaded
    public var currentStreak: Int

    /// The last scheduled date that was evaluated for the streak
    /// nil means the streak has never been evaluated (needs full recompute)
    public var lastStreakDate: Date?

    /// Sort order for user-defined ordering (lower = higher in list)
    public var sortOrder: Int

    // MARK: - Initialization

    public init(
        id: UUID = UUID(),
        activityID: UUID,
        frequency: GoalFrequency,
        targetSeconds: Int,
        isActive: Bool = true,
        createdDate: Date = Date(),
        currentStreak: Int = 0,
        lastStreakDate: Date? = nil,
        sortOrder: Int = Int.max
    ) {
        self.id = id
        self.activityID = activityID
        self.frequency = frequency
        self.targetSeconds = targetSeconds
        self.isActive = isActive
        self.createdDate = createdDate
        self.currentStreak = currentStreak
        self.lastStreakDate = lastStreakDate
        self.sortOrder = sortOrder
    }
}

// MARK: - Codable Conformance for Syncing

extension Goal: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, activityID, frequency, targetSeconds, isActive, createdDate
        case currentStreak, lastStreakDate, sortOrder
    }

    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let activityID = try container.decode(UUID.self, forKey: .activityID)
        let frequency = try container.decode(GoalFrequency.self, forKey: .frequency)
        let targetSeconds = try container.decode(Int.self, forKey: .targetSeconds)
        let isActive = try container.decode(Bool.self, forKey: .isActive)
        let createdDate = try container.decode(Date.self, forKey: .createdDate)
        let currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
        let lastStreakDate = try container.decodeIfPresent(Date.self, forKey: .lastStreakDate)
        let sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? Int.max
        self.init(
            id: id,
            activityID: activityID,
            frequency: frequency,
            targetSeconds: targetSeconds,
            isActive: isActive,
            createdDate: createdDate,
            currentStreak: currentStreak,
            lastStreakDate: lastStreakDate,
            sortOrder: sortOrder
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(activityID, forKey: .activityID)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(targetSeconds, forKey: .targetSeconds)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(currentStreak, forKey: .currentStreak)
        try container.encodeIfPresent(lastStreakDate, forKey: .lastStreakDate)
        try container.encode(sortOrder, forKey: .sortOrder)
    }
}
