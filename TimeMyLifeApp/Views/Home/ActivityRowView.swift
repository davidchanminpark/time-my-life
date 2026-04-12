//
//  ActivityRowView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct ActivityRowView: View {
    let activity: Activity
    let displayedDuration: TimeInterval
    let isTimerRunning: Bool
    let targetDate: Date

    var body: some View {
        HStack(spacing: 14) {
            activityAvatar

            VStack(alignment: .leading, spacing: 5) {
                Text(activity.name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.primary)

                if !activity.category.isEmpty {
                    Text(activity.category)
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(formattedDuration)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(isTimerRunning ? Color.appAccent : .primary)

                if isTimerRunning {
                    runningBadge
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .appCard()
    }

    // MARK: - Sub-views

    private var activityAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13)
                .fill(activity.emoji.isEmpty
                      ? activity.color()
                      : activity.color().opacity(0.18))
                .frame(width: 48, height: 48)
            if activity.emoji.isEmpty {
                Text(String(activity.name.prefix(1)).uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
            } else {
                Text(activity.emoji)
                    .font(.system(size: 26))
            }
        }
    }

    private var runningBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.appAccent)
                .frame(width: 5, height: 5)
            Text("live")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.appAccent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.appAccent.opacity(0.12))
        .clipShape(Capsule())
    }

    // MARK: - Helpers

    private var formattedDuration: String {
        displayedDuration.formattedDuration(style: .compact)
    }
}

#Preview("Running") {
    let activity = try! Activity.validated(
        name: "Deep Work",
        colorHex: "#BFC8FF",
        category: "Focus",
        scheduledDays: [2, 3, 4, 5, 6]
    )
    ActivityRowView(
        activity: activity,
        displayedDuration: 3661,
        isTimerRunning: true,
        targetDate: Date()
    )
    .padding(.horizontal)
}

#Preview("Idle") {
    let activity = try! Activity.validated(
        name: "Reading",
        colorHex: "#33C3FF",
        category: "Learning",
        scheduledDays: Array(1...7)
    )
    ActivityRowView(
        activity: activity,
        displayedDuration: 2700,
        isTimerRunning: false,
        targetDate: Date()
    )
    .padding(.horizontal)
}
