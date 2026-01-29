//
//  ActivityTimerView.swift
//  TimeMyLifeApp
//

import SwiftUI

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
        VStack(spacing: 32) {
            Spacer()

            // Activity info
            VStack(spacing: 12) {
                Circle()
                    .fill(activity.color())
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: "clock.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    )

                Text(activity.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if !activity.category.isEmpty {
                    Text(activity.category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Timer display
            Text(viewModel.displayedElapsedTime.formattedAsHoursMinutes())
                .font(.system(size: 56, weight: .medium, design: .rounded))
                .monospacedDigit()

            Spacer()

            // Control buttons
            HStack(spacing: 24) {
                if viewModel.isRunning {
                    Button {
                        Task {
                            await viewModel.stopTimer()
                            dismiss()
                        }
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                } else {
                    Button {
                        Task {
                            await viewModel.startTimer()
                        }
                    } label: {
                        Label("Start", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadAccumulatedTime()
            viewModel.checkAndResumeTimer()
        }
    }
}
