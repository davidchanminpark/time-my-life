//
//  ActivityRowView.swift
//  TimeMyLifeApp
//

import SwiftUI

struct ActivityRowView: View {
    let activity: Activity
    let displayedDuration: TimeInterval
    let isTimerRunning: Bool
    let targetDate: Date

    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(activity.color())
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)

                if !activity.category.isEmpty {
                    Text(activity.category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(displayedDuration.formattedAsHoursMinutes())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isTimerRunning ? .blue : .primary)

                if isTimerRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                        Text("Running")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
