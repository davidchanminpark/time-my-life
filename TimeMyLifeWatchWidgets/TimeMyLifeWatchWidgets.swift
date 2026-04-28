//
//  TimeMyLifeWatchWidgets.swift
//  TimeMyLifeWatchWidgets
//
//  watchOS complication showing current timer status.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct TimerEntry: TimelineEntry {
    let date: Date
    let activityName: String?
    let activityEmoji: String
    let activityColorHex: String
    let timerStartDate: Date?
}

// MARK: - Timeline Provider

struct TimerComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> TimerEntry {
        TimerEntry(
            date: .now,
            activityName: "Activity",
            activityEmoji: "⏱",
            activityColorHex: "#8B7FE8",
            timerStartDate: .now
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TimerEntry) -> Void) {
        let entry = makeEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimerEntry>) -> Void) {
        let entry = makeEntry()
        // Refresh every 15 minutes if idle, or every minute if running
        let refreshDate: Date
        if entry.activityName != nil {
            refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: .now)!
        } else {
            refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: .now)!
        }
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func makeEntry() -> TimerEntry {
        if let snapshot = WatchTimerSharedState.read() {
            return TimerEntry(
                date: .now,
                activityName: snapshot.activityName,
                activityEmoji: snapshot.activityEmoji,
                activityColorHex: snapshot.activityColorHex,
                timerStartDate: snapshot.startDate
            )
        } else {
            return TimerEntry(
                date: .now,
                activityName: nil,
                activityEmoji: "",
                activityColorHex: "#8B7FE8",
                timerStartDate: nil
            )
        }
    }
}

// MARK: - Complication Views

struct TimerComplicationView: View {
    var entry: TimerEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }

    // MARK: - Circular

    private var circularView: some View {
        ZStack {
            if let name = entry.activityName, let startDate = entry.timerStartDate {
                VStack(spacing: 1) {
                    Text(entry.activityEmoji.isEmpty ? "⏱" : entry.activityEmoji)
                        .font(.system(size: 14))
                    Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 1) {
                    Image(systemName: "timer")
                        .font(.system(size: 16))
                    Text("--:--")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let name = entry.activityName, let startDate = entry.timerStartDate {
                HStack(spacing: 4) {
                    Text(entry.activityEmoji.isEmpty ? "⏱" : entry.activityEmoji)
                        .font(.system(size: 12))
                    Text(name)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(1)
                }

                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(activityColor)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 12))
                    Text("Time My Life")
                        .font(.system(.headline, design: .rounded))
                }

                Text("No timer running")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Inline

    private var inlineView: some View {
        Group {
            if let name = entry.activityName, let startDate = entry.timerStartDate {
                HStack(spacing: 4) {
                    Text(entry.activityEmoji.isEmpty ? "⏱" : entry.activityEmoji)
                    Text(name)
                    Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                }
            } else {
                Text("⏱ No timer")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Corner

    private var cornerView: some View {
        ZStack {
            if let startDate = entry.timerStartDate, entry.activityName != nil {
                Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            } else {
                Image(systemName: "timer")
                    .font(.system(size: 18))
            }
        }
        .widgetLabel {
            if let name = entry.activityName {
                Text("\(entry.activityEmoji.isEmpty ? "⏱" : entry.activityEmoji) \(name)")
            } else {
                Text("Time My Life")
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    // MARK: - Helpers

    private var activityColor: Color {
        Color(hex: entry.activityColorHex) ?? Color(red: 0.545, green: 0.498, blue: 0.910)
    }
}

// MARK: - Widget Definition

struct TimeMyLifeWatchWidgets: Widget {
    let kind: String = "TimeMyLifeWatchWidgets"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimerComplicationProvider()) { entry in
            TimerComplicationView(entry: entry)
        }
        .configurationDisplayName("Timer")
        .description("Shows the currently running timer.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Color Extension

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

#Preview(as: .accessoryCircular) {
    TimeMyLifeWatchWidgets()
} timeline: {
    TimerEntry(date: .now, activityName: "Meditation", activityEmoji: "🧘", activityColorHex: "#FFB3BA", timerStartDate: .now)
    TimerEntry(date: .now, activityName: nil, activityEmoji: "", activityColorHex: "#8B7FE8", timerStartDate: nil)
}

#Preview(as: .accessoryRectangular) {
    TimeMyLifeWatchWidgets()
} timeline: {
    TimerEntry(date: .now, activityName: "Meditation", activityEmoji: "🧘", activityColorHex: "#FFB3BA", timerStartDate: .now)
    TimerEntry(date: .now, activityName: nil, activityEmoji: "", activityColorHex: "#8B7FE8", timerStartDate: nil)
}

#Preview(as: .accessoryInline) {
    TimeMyLifeWatchWidgets()
} timeline: {
    TimerEntry(date: .now, activityName: "Meditation", activityEmoji: "🧘", activityColorHex: "#FFB3BA", timerStartDate: .now)
    TimerEntry(date: .now, activityName: nil, activityEmoji: "", activityColorHex: "#8B7FE8", timerStartDate: nil)
}
