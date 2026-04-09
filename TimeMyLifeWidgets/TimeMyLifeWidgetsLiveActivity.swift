//
//  TimeMyLifeWidgetsLiveActivity.swift
//  TimeMyLifeWidgets
//
//  Created by Chanmin Park on 4/8/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct TimeMyLifeWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            // MARK: - Lock Screen / Banner UI
            lockScreenView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Dynamic Island
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .center, spacing: 10) {
                        activityIcon(context: context, size: 32)

                        Text(context.attributes.activityName)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        Text(
                            timerInterval: context.state.timerStartDate...Date.distantFuture,
                            countsDown: false
                        )
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                    }
                }
            } compactLeading: {
                // MARK: - Compact Leading
                activityIcon(context: context, size: 18)
            } compactTrailing: {
                // MARK: - Compact Trailing
                Text(
                    timerInterval: context.state.timerStartDate...Date.distantFuture,
                    countsDown: false
                )
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .monospacedDigit()
            } minimal: {
                // MARK: - Minimal
                activityIcon(context: context, size: 22)
            }
            .keylineTint(activityColor(hex: context.attributes.activityColorHex))
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        HStack(spacing: 14) {
            activityIcon(context: context, size: 44)

            Text(context.attributes.activityName)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Text(
                timerInterval: context.state.timerStartDate...Date.distantFuture,
                countsDown: false
            )
            .font(.system(.title, design: .rounded, weight: .bold))
            .monospacedDigit()
            .multilineTextAlignment(.trailing)
            .frame(alignment: .trailing)
            .foregroundStyle(activityColor(hex: context.attributes.activityColorHex))
        }
        .padding(16)
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(activityColor(hex: context.attributes.activityColorHex))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func activityIcon(context: ActivityViewContext<TimerActivityAttributes>, size: CGFloat) -> some View {
        let emoji = context.attributes.activityEmoji
        let color = activityColor(hex: context.attributes.activityColorHex)

        if emoji.isEmpty {
            RoundedRectangle(cornerRadius: size * 0.3)
                .fill(color)
                .frame(width: size, height: size)
        } else {
            Text(emoji)
                .font(.system(size: size * 0.6))
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.3)
                        .fill(color.opacity(0.3))
                )
        }
    }

    private func activityColor(hex: String) -> Color {
        Color(hex: hex) ?? Color(red: 0.545, green: 0.498, blue: 0.910)
    }
}

// MARK: - Color Extension (duplicated for widget target which can't access main app's Color+Hex)

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Previews

extension TimerActivityAttributes {
    fileprivate static var preview: TimerActivityAttributes {
        TimerActivityAttributes(
            activityName: "Reading",
            activityEmoji: "📚",
            activityColorHex: "#FFB3BA"
        )
    }
}

extension TimerActivityAttributes.ContentState {
    fileprivate static var running: TimerActivityAttributes.ContentState {
        TimerActivityAttributes.ContentState(timerStartDate: Date())
    }
}

#Preview("Lock Screen", as: .content, using: TimerActivityAttributes.preview) {
    TimeMyLifeWidgetsLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.running
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: TimerActivityAttributes.preview) {
    TimeMyLifeWidgetsLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.running
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: TimerActivityAttributes.preview) {
    TimeMyLifeWidgetsLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.running
}

#Preview("Dynamic Island Minimal", as: .dynamicIsland(.minimal), using: TimerActivityAttributes.preview) {
    TimeMyLifeWidgetsLiveActivity()
} contentStates: {
    TimerActivityAttributes.ContentState.running
}
