//
//  ActivityRowView.swift
//  TimeMyLife Watch App
//

import SwiftUI
import SwiftData

/// Activity row component for displaying activity in list
struct ActivityRowView: View {
    let activity: Activity
    let displayedDuration: TimeInterval
    let isTimerRunning: Bool
    let targetDate: Date

    var body: some View {
        NavigationLink {
            ActivityTimerView(activity: activity, targetDate: targetDate)
        } label: {
            // Colored blob containing the activity info
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(activity.name)
                            .font(.headline)
                            .foregroundColor(activity.textColor())
                            .lineLimit(1)


                    }

                    // Show accumulated time if any
                    if displayedDuration > 0 {
                        Text(displayedDuration.formatted())
                            .font(.caption)
                            .foregroundColor(activity.textColor().opacity(0.9))
                    } else {
                        Text("Not started")
                            .font(.caption)
                            .foregroundColor(activity.textColor().opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Clock icon when timer is running
                if isTimerRunning {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(activity.textColor())
                        //.padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(activity.color())
            )
            .overlay(
                // Highlight border when timer is running
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isTimerRunning ? Color.white : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }
}
