//
//  TimeMyLifeWatchApp.swift
//  TimeMyLifeWatch Watch App
//
//  Created by Chanmin Park on 12/9/25.
//

import SwiftUI
import SwiftData

@main
struct TimeMyLifeWatch_Watch_AppApp: App {
    // MARK: - SwiftData ModelContainer

        /// Shared ModelContainer for the app
        /// Configured with Activity, TimeEntry, and ActiveTimer models
        let modelContainer: ModelContainer

        // MARK: - Services

        /// Core data service for SwiftData operations
        let dataService: DataService

        /// Timer service for managing timer state
        let timerService: TimerService

        // MARK: - Scene Phase Tracking

        @Environment(\.scenePhase) private var scenePhase

        // MARK: - Initialization

        init() {
            do {
                // Create schema with all three models
                let schema = Schema([
                    Activity.self,
                    TimeEntry.self,
                    ActiveTimer.self
                ])

                // Configure model container
                // Note: If you see "CoreData: error: Recovery attempt... was successful!" in console,
                // this is NOT an error - it means SwiftData automatically recovered from a database issue.
                // This can happen if the app was force-quit during a write operation, but recovery is automatic.
                let modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false // Persist to disk
                )

                // Initialize ModelContainer with error handling
                modelContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )

                // Initialize services
                self.dataService = DataService(modelContext: modelContainer.mainContext)
                self.timerService = TimerService(modelContext: modelContainer.mainContext)

                // Ensure ActiveTimer singleton exists on first launch
                let container = modelContainer
                Task { @MainActor in
                    do {
                        let context = container.mainContext
                        _ = try ActiveTimer.shared(in: context)
                    } catch {
                        // Log error but don't crash - singleton creation can fail gracefully
                        print("Warning: Failed to initialize ActiveTimer singleton: \(error.localizedDescription)")
                    }
                }

            } catch {
                // More detailed error message for debugging
                let errorMessage = """
                Failed to initialize ModelContainer:
                Error: \(error.localizedDescription)

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
                ContentView(dataService: dataService, timerService: timerService)
            }
            .modelContainer(modelContainer)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
        }

        // MARK: - Scene Phase Handling

        /// Handles app lifecycle transitions (background, foreground, inactive)
        /// - Parameters:
        ///   - oldPhase: Previous scene phase
        ///   - newPhase: New scene phase
        private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
            switch newPhase {
            case .active:
                // App became active (foreground)
                #if DEBUG
                print("📱 App became active")
                #endif
                checkForRunningTimer()

            case .inactive:
                // App became inactive (transitioning)
                #if DEBUG
                print("📱 App became inactive")
                #endif

            case .background:
                // App went to background
                #if DEBUG
                print("📱 App went to background")
                #endif
                // Timer state is automatically persisted by SwiftData
                // WKExtendedRuntimeSession keeps timer running

            @unknown default:
                break
            }
        }

        /// Checks if a timer is running when app becomes active
        /// This helps ensure timer state is visible when app resumes
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
