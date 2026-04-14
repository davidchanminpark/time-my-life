//
//  SettingsView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import WatchConnectivity

struct SettingsView: View {
    let dataService: DataService
    let notificationService: NotificationService
    let syncService: WatchConnectivitySyncService?

    // MARK: - Persisted preferences

    /// "always" = always continue past midnight, "no" = never, "unset"/"today" = prompt
    @AppStorage("midnightModePreference") private var midnightMode: String = "unset"
    /// Appearance override: "system" | "light" | "dark"
    @AppStorage("appearancePreference") private var appearancePreferenceRaw: String = AppearancePreference.system.rawValue
    /// Unix timestamp of last successful sync
    @AppStorage("lastSyncTimestamp") private var lastSyncTimestamp: Double = 0
    /// Whether goal progress notifications are enabled
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = false
    /// Comma-separated hours for notification times (e.g., "12,18")
    @AppStorage("notificationHours") private var notificationHours: String = "12,18"

    // MARK: - Transient state

    @State private var isSyncing = false
    @State private var syncError: String? = nil
    #if DEBUG
    @State private var showClearConfirm = false
    @State private var showClearSuccess = false
    @State private var showSeedConfirm = false
    @State private var isSeeding = false
    @State private var showSeedSuccess = false
    #endif

    init(dataService: DataService, notificationService: NotificationService, syncService: WatchConnectivitySyncService? = nil) {
        self.dataService = dataService
        self.notificationService = notificationService
        self.syncService = syncService
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                generalSection
                notificationsSection
                activitiesSection
                if syncService != nil { syncSection }
                #if DEBUG
                debugSection
                #endif
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .tint(Color.appAccent)
            .contentMargins(.bottom, 110, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("Settings")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.appPrimaryText)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 4)
                .background(Color.appBackground)
            }
            .onReceive(NotificationCenter.default.publisher(for: .timeEntryDidSync)) { _ in
                lastSyncTimestamp = Date().timeIntervalSince1970
            }
            .onReceive(NotificationCenter.default.publisher(for: .activityDidSync)) { _ in
                lastSyncTimestamp = Date().timeIntervalSince1970
            }
            #if DEBUG
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

            Picker(selection: $appearancePreferenceRaw) {
                ForEach(AppearancePreference.allCases) { pref in
                    Text(pref.label).tag(pref.rawValue)
                }
            } label: {
                Label {
                    Text("Appearance")
                } icon: {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.purple)
                }
            }
        }
        .listRowBackground(Color.appCardBackground)
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Goal Reminders")
                        Text("Get daily goal progress updates")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.orange)
                }
            }
            .onChange(of: notificationsEnabled) { _, enabled in
                Task {
                    if enabled {
                        let granted = await notificationService.requestPermission()
                        if !granted {
                            notificationsEnabled = false
                        } else {
                            let hours = NotificationService.selectedHours(from: notificationHours)
                            await notificationService.scheduleProgressNotifications(
                                dataService: dataService,
                                selectedHours: hours
                            )
                        }
                    } else {
                        notificationService.cancelProgressNotifications()
                    }
                }
            }

            if notificationsEnabled {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reminder Times")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(NotificationService.presetHours, id: \.self) { hour in
                            let selected = selectedHoursSet.contains(hour)
                            Button {
                                toggleHour(hour)
                            } label: {
                                Text(NotificationService.formatHour(hour))
                                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                                    .lineLimit(1)
                                    .fixedSize()
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 8)
                                    .background(
                                        selected
                                            ? Color.appAccent.opacity(0.15)
                                            : Color.secondary.opacity(0.08)
                                    )
                                    .foregroundStyle(selected ? Color.appAccent : .secondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                selected ? Color.appAccent : Color.clear,
                                                lineWidth: 1.5
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("Notifications")
        }
        .listRowBackground(Color.appCardBackground)
    }

    private var selectedHoursSet: Set<Int> {
        NotificationService.selectedHours(from: notificationHours)
    }

    private func toggleHour(_ hour: Int) {
        var hours = selectedHoursSet
        if hours.contains(hour) {
            hours.remove(hour)
        } else {
            hours.insert(hour)
        }
        notificationHours = NotificationService.storeHours(hours)

        if notificationsEnabled {
            Task {
                await notificationService.scheduleProgressNotifications(
                    dataService: dataService,
                    selectedHours: hours
                )
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
        .listRowBackground(Color.appCardBackground)
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
        .listRowBackground(Color.appCardBackground)
    }

    // MARK: - Debug Section

    #if DEBUG
    private var debugSection: some View {
        Section("Developer") {
            Button(role: .destructive) {
                showClearConfirm = true
            } label: {
                Label("Clear All Data", systemImage: "trash")
            }

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
        .listRowBackground(Color.appCardBackground)
    }
    #endif

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

    #if DEBUG
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
    #endif
}

#Preview("Settings") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    SettingsView(dataService: dataService, notificationService: NotificationService(), syncService: nil)
        .modelContainer(container)
}

#Preview("Settings — empty store") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies(seedSample: false)
    SettingsView(dataService: dataService, notificationService: NotificationService(), syncService: nil)
        .modelContainer(container)
}
