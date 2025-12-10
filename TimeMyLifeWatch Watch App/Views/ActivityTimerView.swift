//
//  ActivityTimerView.swift
//  TimeMyLife Watch App
//

import SwiftUI
import SwiftData
import WatchKit

/// ActivityTimerView - Timer interface for tracking activity duration
struct ActivityTimerView: View {
    @Environment(DataService.self) private var dataService
    @Environment(TimerService.self) private var timerService

    let activity: Activity
    let targetDate: Date

    // Background runtime session (watchOS-specific)
    @State private var runtimeSession: WKExtendedRuntimeSession?
    @State private var viewModel: TimerViewModel?

    // MARK: - Computed Properties

    // Lazy ViewModel initialization using environment services
    private var vm: TimerViewModel {
        if let viewModel = viewModel {
            return viewModel
        } else {
            let newViewModel = TimerViewModel(
                activity: activity,
                targetDate: targetDate,
                dataService: dataService,
                timerService: timerService
            )
            DispatchQueue.main.async {
                viewModel = newViewModel
            }
            return newViewModel
        }
    }

    // Format current time as MM:SS or HH:MM:SS
    private var currentTime: String {
        vm.formatDuration(vm.elapsedTime)
    }

    // Check if we're viewing today's date
    private var isViewingToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.isDate(vm.targetDate, inSameDayAs: today)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Activity name with colored background
            Text(vm.activity.name)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(vm.activity.color())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 12)

            Spacer()

            // Large timer display
            Text(currentTime)
                .font(.system(size: vm.timerFontSize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.bottom, 10)

            // Start/Stop button
            Button {
                if vm.isRunning {
                    stopTimer()
                } else {
                    startTimer()
                }
            } label: {
                Text(vm.isRunning ? "Stop" : "Start")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(vm.isRunning ? Color.red : Color.green)
                    .cornerRadius(22)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            // Accumulated time for the target date
            HStack(spacing: 4) {
                Text("Total")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if vm.accumulatedTime > 0 {
                    Text(vm.formatDuration(vm.accumulatedTime))
                        .font(.callout)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                } else {
                    Text("--:--")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 16)

            Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupBackgroundSessionCallbacks()
            vm.onAppear()
        }
        .onDisappear {
            vm.onDisappear()
        }
        .alert("Timer Alert", isPresented: .constant(vm.alertMessage != nil)) {
            Button("OK") {
                vm.alertMessage = nil
            }
        } message: {
            if let message = vm.alertMessage {
                Text(message)
            }
        }
    }

    // MARK: - Timer Functions

    private func startTimer() {
        vm.startTimer()
    }

    private func stopTimer() {
        Task {
            await vm.stopTimer()
        }
    }

    // MARK: - Background Session Management (watchOS-specific)

    private func setupBackgroundSessionCallbacks() {
        vm.onStartBackgroundSession = { [weak runtimeSession] in
            startBackgroundSession()
        }

        vm.onStopBackgroundSession = { [weak runtimeSession] in
            stopBackgroundSession()
        }
    }

    private func startBackgroundSession() {
        #if targetEnvironment(simulator)
        // Skip background session in simulator - not fully supported
        #if DEBUG
        print("⚠️ Background session skipped (simulator)")
        #endif
        return
        #else
        // Create a new extended runtime session
        let session = WKExtendedRuntimeSession()
        runtimeSession = session

        // Start the session
        session.start()

        #if DEBUG
        if session.state == .running {
            print("✅ Background runtime session started")
        } else if session.state == .invalid {
            print("⚠️ Background session invalid (entitlements may be needed)")
        }
        #endif
        #endif
    }

    private func stopBackgroundSession() {
        guard let session = runtimeSession else {
            return
        }

        session.invalidate()
        runtimeSession = nil

        #if DEBUG
        print("✅ Background runtime session stopped")
        #endif
    }
}

