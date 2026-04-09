//
//  LiveActivityService.swift
//  TimeMyLifeApp
//

import ActivityKit
import Foundation

/// Type alias to disambiguate ActivityKit.Activity from the SwiftData Activity model.
private typealias LiveActivity = ActivityKit.Activity<TimerActivityAttributes>

/// Manages the timer Live Activity lifecycle (start, update, end).
@MainActor
public final class LiveActivityService {

    // MARK: - Properties

    private var currentActivity: LiveActivity?

    // MARK: - Public Methods

    /// Starts a Live Activity for the given timer session.
    func start(
        activityName: String,
        activityEmoji: String,
        activityColorHex: String,
        startDate: Date
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            #if DEBUG
            print("⚠️ LiveActivityService: Live Activities not enabled")
            #endif
            return
        }

        let attributes = TimerActivityAttributes(
            activityName: activityName,
            activityEmoji: activityEmoji,
            activityColorHex: activityColorHex
        )

        let contentState = TimerActivityAttributes.ContentState(
            timerStartDate: startDate
        )

        let content = ActivityContent(state: contentState, staleDate: nil)

        do {
            currentActivity = try LiveActivity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            #if DEBUG
            print("✅ LiveActivityService: Started Live Activity for '\(activityName)'")
            #endif
        } catch {
            #if DEBUG
            print("❌ LiveActivityService: Failed to start Live Activity: \(error)")
            #endif
        }
    }

    /// Ends the current Live Activity.
    func stop() {
        guard let activity = currentActivity else { return }

        let finalContent = ActivityContent(
            state: activity.content.state,
            staleDate: nil
        )

        Task {
            await activity.end(finalContent, dismissalPolicy: .immediate)
            #if DEBUG
            print("✅ LiveActivityService: Ended Live Activity")
            #endif
        }

        currentActivity = nil
    }

    /// Ends all timer Live Activities (cleanup on app launch).
    func endAll() {
        Task {
            for activity in LiveActivity.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
