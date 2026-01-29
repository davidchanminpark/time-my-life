//
//  TimeMyLifeAppApp.swift
//  TimeMyLifeApp
//
//  Created by Chanmin Park on 12/9/25.
//

import SwiftUI
import SwiftData

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

    // MARK: - Scene Phase Tracking

    @Environment(\.scenePhase) private var scenePhase

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

            // Configure model container for local-only storage
            // No CloudKit - will use WatchConnectivity for sync
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            // Initialize ModelContainer with error handling
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )

            // Initialize sync service
            let sync = WatchConnectivitySyncService()
            self.syncService = sync

            // Initialize services with sync
            self.dataService = DataService(
                modelContext: modelContainer.mainContext,
                syncService: sync
            )
            self.timerService = TimerService(modelContext: modelContainer.mainContext)

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
                syncService: syncService
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

        case .inactive:
            #if DEBUG
            print("📱 iOS App became inactive")
            #endif

        case .background:
            #if DEBUG
            print("📱 iOS App went to background")
            #endif
            // Timer state is automatically persisted by SwiftData
            // CloudKit sync happens automatically in the background

        @unknown default:
            break
        }
    }

    /// Checks if a timer is running when app becomes active
    private func checkForRunningTimer() {
        Task { @MainActor in
            do {
                let context = modelContainer.mainContext
                let timer = try ActiveTimer.shared(in: context)

                if timer.isRunning {
                    #if DEBUG
                    if let startTime = timer.startTime {
                        let elapsed = Date().timeIntervalSince(startTime)
                        print("✅ Timer is running - elapsed: \(formatElapsed(elapsed))")
                    }
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ Error checking timer state: \(error.localizedDescription)")
                #endif
            }
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
