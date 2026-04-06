//
//  NotificationService.swift
//  TimeMyLifeApp
//

import Foundation
import UserNotifications
import Observation

@Observable
@MainActor
class NotificationService {

    // MARK: - Constants

    static let presetHours = [9, 12, 15, 18, 21]
    private static let notificationIdentifierPrefix = "goal-progress-"
    private static let defaultHours = "12,18"

    // MARK: - Observable State

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Dependencies

    private let notificationCenter: UNUserNotificationCenter

    // MARK: - Init

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            print("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Scheduling

    func scheduleProgressNotifications(dataService: DataService, selectedHours: Set<Int>) async {
        // Cancel existing goal progress notifications
        cancelProgressNotifications()

        guard !selectedHours.isEmpty else { return }

        // Skip notifications entirely if all goals are already met
        let summary = buildGoalSummary(dataService: dataService)
        guard !summary.allGoalsMet else { return }

        // Build notification content from current goal progress
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.title = summary.title
        content.body = summary.body

        for hour in selectedHours.sorted() {
            let identifier = "\(Self.notificationIdentifierPrefix)\(hour)"

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
            } catch {
                print("Failed to schedule notification for \(hour):00 — \(error.localizedDescription)")
            }
        }
    }

    func cancelProgressNotifications() {
        let identifiers = Self.presetHours.map { "\(Self.notificationIdentifierPrefix)\($0)" }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    // MARK: - Content Generation

    struct GoalSummary {
        let title: String
        let body: String
        let allGoalsMet: Bool
    }

    func buildGoalSummary(dataService: DataService) -> GoalSummary {
        do {
            let goals = try dataService.fetchGoals(frequency: .daily)
            guard !goals.isEmpty else {
                return GoalSummary(
                    title: "Time My Life",
                    body: "Set up daily goals to track your progress!",
                    allGoalsMet: false
                )
            }

            let today = Calendar.current.startOfDay(for: Date())
            var completed = 0

            for goal in goals {
                let entries = try dataService.fetchTimeEntries(for: goal.activityID, on: today)
                let totalSeconds = entries.reduce(0.0) { $0 + $1.totalDuration }
                if totalSeconds >= Double(goal.targetSeconds) {
                    completed += 1
                }
            }

            let total = goals.count
            if completed == total {
                return GoalSummary(
                    title: "All Goals Met!",
                    body: "You've completed all \(total) daily goal\(total == 1 ? "" : "s") today. Great work!",
                    allGoalsMet: true
                )
            } else {
                return GoalSummary(
                    title: "Daily Goals: \(completed)/\(total)",
                    body: "\(total - completed) goal\(total - completed == 1 ? "" : "s") remaining — keep going!",
                    allGoalsMet: false
                )
            }
        } catch {
            return GoalSummary(
                title: "Time My Life",
                body: "Check your daily goals progress!",
                allGoalsMet: false
            )
        }
    }

    // MARK: - Settings Helpers

    static func selectedHours(from storedString: String?) -> Set<Int> {
        guard let stored = storedString, !stored.isEmpty else {
            return parseHours(defaultHours)
        }
        return parseHours(stored)
    }

    static func storeHours(_ hours: Set<Int>) -> String {
        hours.sorted().map(String.init).joined(separator: ",")
    }

    private static func parseHours(_ string: String) -> Set<Int> {
        Set(string.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) })
    }

    static func formatHour(_ hour: Int) -> String {
        if hour == 0 { return "12 AM" }
        if hour < 12 { return "\(hour) AM" }
        if hour == 12 { return "12 PM" }
        return "\(hour - 12) PM"
    }
}
