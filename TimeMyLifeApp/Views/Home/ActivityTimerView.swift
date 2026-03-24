//
//  ActivityTimerView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct ActivityTimerView: View {
    let activity: Activity
    let dataService: DataService
    let timerService: TimerService

    @State private var viewModel: TimerViewModel
    @Environment(\.dismiss) private var dismiss

    init(activity: Activity, targetDate: Date, dataService: DataService, timerService: TimerService) {
        self.activity = activity
        self.dataService = dataService
        self.timerService = timerService
        _viewModel = State(wrappedValue: TimerViewModel(
            activity: activity,
            targetDate: targetDate,
            dataService: dataService,
            timerService: timerService
        ))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Avatar + name
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .fill(activity.emoji.isEmpty
                                  ? activity.color()
                                  : activity.color().opacity(0.18))
                            .frame(width: 100, height: 100)
                            .shadow(
                                color: activity.color().opacity(0.45),
                                radius: 24,
                                x: 0, y: 10
                            )
                        if activity.emoji.isEmpty {
                            Text(String(activity.name.prefix(1)).uppercased())
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(white: 0.18))
                        } else {
                            Text(activity.emoji)
                                .font(.system(size: 52))
                        }
                    }

                    VStack(spacing: 6) {
                        Text(activity.name)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(.primary)

                        if !activity.category.isEmpty {
                            Text(activity.category)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 5)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                // Timer display
                Text(viewModel.displayedElapsedTime.formattedAsHoursMinutes())
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.isRunning ? Color.appAccent : .primary)
                    .contentTransition(.numericText())

                Spacer()

                // Control button
                Button {
                    Task {
                        if viewModel.isRunning {
                            await viewModel.stopTimer()
                            dismiss()
                        } else {
                            await viewModel.startTimer()
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(viewModel.isRunning ? "Stop" : "Start")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(viewModel.isRunning ? Color(red: 0.91, green: 0.42, blue: 0.42) : Color.appAccent)
                    .clipShape(Capsule())
                    .shadow(
                        color: (viewModel.isRunning
                            ? Color(red: 0.91, green: 0.42, blue: 0.42)
                            : Color.appAccent).opacity(0.35),
                        radius: 14, x: 0, y: 5
                    )
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAccumulatedTime()
            viewModel.checkAndResumeTimer()
        }
    }
}

#Preview {
    let (container, dataService, timerService) = IOSViewPreviewSupport.dependencies()
    let activity = IOSViewPreviewSupport.firstActivity(in: container.mainContext)
        ?? (try! Activity.validated(name: "Preview", colorHex: "#BFC8FF", category: "", scheduledDays: [2]))
    NavigationStack {
        ActivityTimerView(
            activity: activity,
            targetDate: Calendar.current.startOfDay(for: Date()),
            dataService: dataService,
            timerService: timerService
        )
    }
    .modelContainer(container)
}
