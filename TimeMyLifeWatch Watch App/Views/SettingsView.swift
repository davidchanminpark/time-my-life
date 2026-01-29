//
//  SettingsView.swift
//  TimeMyLife Watch App
//

import SwiftUI
import SwiftData


/// SettingsView - List all activities for management
struct SettingsView: View {
    @Environment(DataService.self) private var dataService

    @State private var viewModel: SettingsViewModel?
    @State private var activityToDelete: Activity?
    @State private var showDeleteConfirmation = false
    @State private var lastDeleteTime: Date?

    // MARK: - Computed Properties

    // Lazy ViewModel initialization using environment services
    private var vm: SettingsViewModel {
        if let viewModel = viewModel {
            return viewModel
        } else {
            let newViewModel = SettingsViewModel(dataService: dataService)
            DispatchQueue.main.async {
                viewModel = newViewModel
            }
            return newViewModel
        }
    }

    var body: some View {
        List {
            Section("Debug") {
                NavigationLink {
                    SyncDebugView()
                } label: {
                    Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
                }
            }

            if vm.activities.isEmpty {
                ContentUnavailableView(
                    "No Activities Yet",
                    systemImage: "tray",
                    description: Text("Create activities using the + button on the main screen")
                )
            } else {
                ForEach(vm.activities) { activity in
                    NavigationLink {
                        ActivityFormView(mode: .edit(activity))
                    } label: {
                        HStack(spacing: 12) {
                            // Color indicator
                            Circle()
                                .fill(activity.color())
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(activity.name)
                                    .font(.headline)

                                Text(activity.category)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Wrench icon to indicate editable
                            Image(systemName: "wrench.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                    }
                }
                .onDelete { indexSet in
                    // Rate limiting: 1-second cooldown
                    if let lastDelete = lastDeleteTime,
                       Date().timeIntervalSince(lastDelete) < 1.0 {
                        return
                    }

                    if let index = indexSet.first {
                        activityToDelete = vm.activities[index]
                        showDeleteConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("All Activities")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.loadActivities()
        }
        .alert("Delete Activity?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                activityToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let activity = activityToDelete {
                    deleteActivity(activity)
                }
            }
        } message: {
            if let activity = activityToDelete {
                Text("This will permanently delete '\(activity.name)' and all associated time entries. This action cannot be undone.")
            }
        }
        .alert("Error", isPresented: .constant(vm.alertMessage != nil)) {
            Button("OK") {
                vm.alertMessage = nil
            }
        } message: {
            if let message = vm.alertMessage {
                Text(message)
            }
        }
    }

    // MARK: - Actions

    private func deleteActivity(_ activity: Activity) {
        Task {
            await vm.deleteActivity(activity)
            lastDeleteTime = Date()
            activityToDelete = nil
        }
    }
}
