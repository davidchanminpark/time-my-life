//
//  GoalCardView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct GoalCardView: View {
    let goalWithProgress: GoalsViewModel.GoalWithProgress
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                CircularProgressView(
                    progress: goalWithProgress.progressFraction,
                    color: goalWithProgress.activityColor,
                    size: 66,
                    lineWidth: 7
                )

                VStack(alignment: .leading, spacing: 6) {
                    // Activity name + streak
                    HStack(alignment: .center) {
                        Circle()
                            .fill(goalWithProgress.activityColor)
                            .frame(width: 10, height: 10)
                        Text(goalWithProgress.activity?.name ?? "Unknown")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        HStack(spacing: 3) {
                            Text("🔥")
                                .font(.system(.subheadline, design: .rounded))
                            Text("\(goalWithProgress.streak)")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                    }

                    // Progress text
                    Text("\(formatDuration(goalWithProgress.currentProgress)) / \(formatDuration(goalWithProgress.targetSeconds))")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)

                    // Streak history squares
                    StreakHistoryView(
                        history: goalWithProgress.history,
                        color: goalWithProgress.activityColor
                    )
                }
            }
            .padding(16)
            .appCard()
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}

#Preview {
    let activity = try! Activity.validated(
        name: "Guitar Practice",
        colorHex: "#FF5733",
        category: "Music",
        scheduledDays: [2, 4, 6]
    )
    let goal = Goal(activityID: activity.id, frequency: .daily, targetSeconds: 3600)
    let item = GoalsViewModel.GoalWithProgress(
        goal: goal,
        activity: activity,
        currentProgress: 2100,
        targetSeconds: 3600,
        streak: 5,
        history: [true, true, false, true, true, true, true]
    )
    GoalCardView(goalWithProgress: item, onTap: {})
        .padding()
}
