//
//  SettingsView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import WatchConnectivity

struct SettingsView: View {
    let dataService: DataService
    let syncService: WatchConnectivitySyncService?

    // MARK: - Persisted preferences

    /// "always" = always continue past midnight, "no" = never, "unset"/"today" = prompt
    @AppStorage("midnightModePreference") private var midnightMode: String = "unset"
    /// 1 = Sunday, 2 = Monday
    @AppStorage("firstDayOfWeek") private var firstDayOfWeek: Int = 1
    /// Unix timestamp of last successful sync
    @AppStorage("lastSyncTimestamp") private var lastSyncTimestamp: Double = 0

    // MARK: - Transient state

    @State private var isSyncing = false
    @State private var syncError: String? = nil
    @State private var showClearConfirm = false
    @State private var showClearSuccess = false
    #if DEBUG
    @State private var showSeedConfirm = false
    @State private var isSeeding = false
    @State private var showSeedSuccess = false
    #endif

    init(dataService: DataService, syncService: WatchConnectivitySyncService? = nil) {
        self.dataService = dataService
        self.syncService = syncService
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                generalSection
                activitiesSection
                dataSection
                if syncService != nil { syncSection }
                #if DEBUG
                debugSection
                #endif
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.appAccent)
            .contentMargins(.bottom, 110, for: .scrollContent)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onReceive(NotificationCenter.default.publisher(for: .timeEntryDidSync)) { _ in
                lastSyncTimestamp = Date().timeIntervalSince1970
            }
            .onReceive(NotificationCenter.default.publisher(for: .activityDidSync)) { _ in
                lastSyncTimestamp = Date().timeIntervalSince1970
            }
            .alert("Clear All Data?", isPresented: $showClearConfirm) {
                Button("Clear Everything", role: .destructive) {
                    Task { await clearAllData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all activities, time entries, and goals. This cannot be undone.")
            }
            .alert("Data Cleared", isPresented: $showClearSuccess) {
                Button("OK") {}
            } message: {
                Text("All data has been deleted.")
            }
            #if DEBUG
            .alert("Load Sample Year?", isPresented: $showSeedConfirm) {
                Button("Load Data", role: .destructive) {
                    Task { await seedYearOfData() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace all existing data with a year's worth of sample activities and time entries.")
            }
            .alert("Sample Data Loaded", isPresented: $showSeedSuccess) {
                Button("OK") {}
            } message: {
                Text("10 activities with 365 days of time entries and 5 goals have been added.")
            }
            #endif
        }
    }

    // MARK: - General Section

    private var generalSection: some View {
        Section("General") {
            Toggle(isOn: Binding(
                get: { midnightMode == "always" },
                set: { midnightMode = $0 ? "always" : "no" }
            )) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Continue Past Midnight")
                        Text("Keep tracking yesterday's activities after midnight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(.indigo)
                }
            }

            Picker(selection: $firstDayOfWeek) {
                Text("Sunday").tag(1)
                Text("Monday").tag(2)
            } label: {
                Label {
                    Text("First Day of Week")
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    // MARK: - Activities Section

    private var activitiesSection: some View {
        Section("Activities") {
            NavigationLink {
                ManageActivitiesView(dataService: dataService)
            } label: {
                Label {
                    Text("Manage Activities")
                } icon: {
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section("Data") {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }
        }
    }

    // MARK: - Sync Section

    @ViewBuilder
    private var syncSection: some View {
        Section("Watch Sync") {
            // Connection status
            HStack {
                Label {
                    Text("Watch Status")
                } icon: {
                    Image(systemName: "applewatch")
                        .foregroundStyle(.primary)
                }
                Spacer()
                watchStatusBadge
            }

            // Last synced
            HStack {
                Label {
                    Text("Last Synced")
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(lastSyncedText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Force sync
            Button {
                Task { await forceSyncNow() }
            } label: {
                HStack {
                    Label {
                        Text("Sync Now")
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Color.appAccent)
                    }
                    if isSyncing {
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .disabled(isSyncing || syncService?.isCounterpartReachable != true)

            if let err = syncError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        Section("Developer") {
            Button {
                showSeedConfirm = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Load Year of Sample Data")
                            Text("10 activities × 365 days + goals")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "tablecells.badge.ellipsis")
                            .foregroundStyle(Color.appAccent)
                    }
                    if isSeeding {
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                    }
                }
            }
            .disabled(isSeeding)
        }
    }
    #endif

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Build") {
                Text(appBuild)
                    .foregroundStyle(.secondary)
                    
            }
        }
    }

    // MARK: - Computed Helpers

    private var watchStatusBadge: some View {
        let reachable = syncService?.isCounterpartReachable ?? false
        let paired = WCSession.isSupported() ? WCSession.default.isPaired : false
        let installed = WCSession.isSupported() ? WCSession.default.isWatchAppInstalled : false

        let (label, color): (String, Color) = {
            if !WCSession.isSupported() { return ("Not Supported", .secondary) }
            if !paired               { return ("No Watch", .secondary) }
            if !installed            { return ("App Not Installed", .orange) }
            if reachable             { return ("Connected", .green) }
            return ("Not Reachable", .secondary)
        }()

        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(color)
        }
    }

    private var lastSyncedText: String {
        guard lastSyncTimestamp > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: lastSyncTimestamp)
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Actions

    private func forceSyncNow() async {
        guard let syncService else { return }
        isSyncing = true
        syncError = nil
        defer { isSyncing = false }
        do {
            try await syncService.requestFullSync()
            lastSyncTimestamp = Date().timeIntervalSince1970
        } catch {
            syncError = "Sync failed: \(error.localizedDescription)"
        }
    }

    #if DEBUG
    private func seedYearOfData() async {
        isSeeding = true
        defer { isSeeding = false }
        do {
            try SampleData.seedYearOfData(in: dataService.modelContext)
            showSeedSuccess = true
        } catch {
            print("Error seeding year data: \(error)")
        }
    }
    #endif

    private func clearAllData() async {
        do {
            try dataService.clearAllData()
            // Also remove all goals
            let goals = try dataService.fetchGoals(activeOnly: false)
            for goal in goals {
                try dataService.deleteGoal(goal)
            }
            showClearSuccess = true
        } catch {
            print("Error clearing data: \(error)")
        }
    }
}

#Preview("Settings") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    SettingsView(dataService: dataService, syncService: nil)
        .modelContainer(container)
}

#Preview("Settings — empty store") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies(seedSample: false)
    SettingsView(dataService: dataService, syncService: nil)
        .modelContainer(container)
}
