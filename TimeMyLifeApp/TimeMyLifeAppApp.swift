//
//  TimeMyLifeAppApp.swift
//  TimeMyLifeApp
//
//  Created by Chanmin Park on 12/9/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct TimeMyLifeAppApp: App {
    // MARK: - SwiftData ModelContainer with CloudKit

    /// Shared ModelContainer configured with CloudKit sync
    /// Configured with Activity, TimeEntry, ActiveTimer, and Goal models
    let modelContainer: ModelContainer

    // MARK: - Services

    /// Core data service for SwiftData operations
    let dataService: DataService

    /// Timer service for managing timer state
    let timerService: TimerService

    /// Sync service for iOS ↔ watchOS communication
    let syncService: WatchConnectivitySyncService

    /// Notification service for goal progress reminders
    let notificationService: NotificationService

    // MARK: - Scene Phase Tracking

    @Environment(\.scenePhase) private var scenePhase

    /// User-selected appearance override (system/light/dark). Controlled in Settings.
    @AppStorage("appearancePreference") private var appearancePreferenceRaw: String = AppearancePreference.system.rawValue

    // MARK: - Initialization

    init() {
        do {
            // Create schema with all models
            let schema = Schema([
                Activity.self,
                ScheduledDay.self,
                TimeEntry.self,
                ActiveTimer.self,
                Goal.self
            ])

            // Versioned store name avoids `loadIssueModelContainer` when an old default store
            // on disk doesn't match the current schema (see SwiftDataPersistence.swift).
            modelContainer = try SwiftDataAppConfiguration.makeModelContainer(schema: schema)

            // Initialize sync service
            let sync = WatchConnectivitySyncService()
            self.syncService = sync

            // Initialize services with sync
            self.dataService = DataService(
                modelContext: modelContainer.mainContext,
                syncService: sync
            )
            self.timerService = TimerService(modelContext: modelContainer.mainContext)
            self.notificationService = NotificationService()

            // Activate sync service
            Task { @MainActor in
                sync.activate()
            }

            // Ensure ActiveTimer singleton exists on first launch
            let container = modelContainer
            Task { @MainActor in
                do {
                    let context = container.mainContext
                    _ = try ActiveTimer.shared(in: context)
                } catch {
                    print("Warning: Failed to initialize ActiveTimer singleton: \(error.localizedDescription)")
                }
            }

            #if DEBUG
            // Auto-seed large dataset when launched with -seedLargeDataset argument.
            // Set via Xcode scheme → Run → Arguments Passed On Launch.
            if CommandLine.arguments.contains("-seedLargeDataset") {
                let seedContainer = modelContainer
                Task { @MainActor in
                    do {
                        try SampleData.seedYearOfData(in: seedContainer.mainContext)
                        print("✅ Seeded year of sample data via launch argument")
                    } catch {
                        print("❌ Failed to seed sample data: \(error)")
                    }
                }
            }
            #endif

        } catch {
            let errorMessage = """
            Failed to initialize ModelContainer:
            Error: \(error)

            This usually happens if:
            - The database file is corrupted
            - There's a schema mismatch
            - Disk space is full

            Try deleting the app and reinstalling to reset the database.
            """
            fatalError(errorMessage)
        }
    }

    // MARK: - App Scene

    var body: some Scene {
        WindowGroup {
            ContentView(
                dataService: dataService,
                timerService: timerService,
                notificationService: notificationService,
                syncService: syncService
            )
            .preferredColorScheme(
                AppearancePreference(rawValue: appearancePreferenceRaw)?.colorScheme
            )
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - Scene Phase Handling

    /// Handles app lifecycle transitions (background, foreground, inactive)
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            #if DEBUG
            print("📱 iOS App became active")
            #endif
            checkForRunningTimer()
            rescheduleNotificationsIfEnabled()

        case .inactive:
            #if DEBUG
            print("📱 iOS App became inactive")
            #endif

        case .background:
            #if DEBUG
            print("📱 iOS App went to background")
            #endif
            // Checkpoint the running timer's elapsed time so it's saved
            // even if the user force-kills the app from the app switcher.
            // The timer and Live Activity keep running in the background.
            checkpointRunningTimer()

        @unknown default:
            break
        }
    }

    /// Cleans up orphaned timers from a previous session (e.g. after a force-kill).
    /// The elapsed time was already checkpointed when the app last went to background,
    /// so we just need to clear the ActiveTimer state and end stale Live Activities.
    private func checkForRunningTimer() {
        Task { @MainActor in
            do {
                // End any Live Activities left over from a killed session.
                timerService.endAllLiveActivities()

                let context = modelContainer.mainContext
                let activeTimer = try ActiveTimer.shared(in: context)

                // If the timer is running in-memory, this is a normal foreground return — do nothing.
                // If it's only running in SwiftData, the app was killed and we need to clean up.
                if activeTimer.isRunning, !timerService.isRunning {
                    activeTimer.activityID = nil
                    activeTimer.startTime = nil
                    activeTimer.startDate = nil
                    activeTimer.isRunning = false
                    try context.save()

                    #if DEBUG
                    print("✅ Cleaned up orphaned ActiveTimer (time was saved on background)")
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ Error checking timer state: \(error.localizedDescription)")
                #endif
            }
        }
    }

    /// Saves the running timer's elapsed time to the TimeEntry as a checkpoint.
    /// Called when the app goes to background so the duration is preserved
    /// even if the user force-kills the app from the app switcher.
    private func checkpointRunningTimer() {
        guard timerService.isRunning,
              let activity = timerService.currentActivity,
              let date = timerService.currentDate else { return }

        let elapsed = timerService.getCurrentElapsedTime()
        do {
            try dataService.createOrUpdateTimeEntry(
                activityID: activity.id,
                date: date,
                duration: elapsed
            )
            #if DEBUG
            print("✅ Checkpointed timer: \(formatElapsed(elapsed))")
            #endif
        } catch {
            #if DEBUG
            print("❌ Failed to checkpoint timer: \(error.localizedDescription)")
            #endif
        }
    }

    /// Re-schedules goal progress notifications so content reflects the latest progress.
    /// Only runs if the user has notifications enabled in Settings.
    private func rescheduleNotificationsIfEnabled() {
        let enabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        guard enabled else { return }
        let hoursString = UserDefaults.standard.string(forKey: "notificationHours")
        let hours = NotificationService.selectedHours(from: hoursString)
        Task { @MainActor in
            await notificationService.scheduleProgressNotifications(
                dataService: dataService,
                selectedHours: hours
            )
        }
    }

    #if DEBUG
    private func formatElapsed(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    #endif
}
