//
//  ManageActivitiesView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct ManageActivitiesView: View {
    let dataService: DataService

    @State private var viewModel: SettingsViewModel
    @State private var editingActivity: Activity? = nil
    @State private var showDeleteError = false

    init(dataService: DataService) {
        self.dataService = dataService
        _viewModel = State(wrappedValue: SettingsViewModel(dataService: dataService))
    }

    var body: some View {
        List {
            if viewModel.activities.isEmpty {
                ContentUnavailableView(
                    "No Activities",
                    systemImage: "list.bullet",
                    description: Text("Add activities from the Home screen.")
                )
            } else {
                Section {
                    ForEach(viewModel.activities) { activity in
                        Button {
                            editingActivity = activity
                        } label: {
                            activityRow(activity)
                                .contentShape(Rectangle())
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("\(viewModel.activities.count) / \(AppConstants.maxActivities) activities")
                }
                .listRowBackground(Color.appCardBackground)
            }

            Section {} footer: {
                Color.clear.frame(height: 90)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("Manage Activities")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingActivity, onDismiss: {
            Task { await viewModel.loadActivities() }
        }) { activity in
            NavigationStack {
                ActivityFormView(mode: .edit(activity), dataService: dataService)
            }
            .fontDesign(.rounded)
        }
        .alert("Error", isPresented: $showDeleteError) {
            Button("OK") {}
        } message: {
            Text(viewModel.alertMessage ?? "Failed to delete activity")
        }
        .task {
            await viewModel.loadActivities()
        }
        .onChange(of: viewModel.alertMessage) { _, newValue in
            // Observe `alertMessage` (Equatable) instead of `error` — `Error` is not Equatable.
            showDeleteError = newValue != nil
        }
    }

    private func activityRow(_ activity: Activity) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(activity.emoji.isEmpty
                          ? activity.color()
                          : activity.color().opacity(0.2))
                    .frame(width: 32, height: 32)
                if activity.emoji.isEmpty {
                    Text(String(activity.name.prefix(1)).uppercased())
                        .font(.caption.bold())
                        .foregroundStyle(Color(white: 0.18))
                } else {
                    Text(activity.emoji)
                        .font(.system(size: 16))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    if !activity.category.isEmpty {
                        Text(activity.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("·").font(.caption).foregroundStyle(.tertiary)
                    }
                    let days = activity.scheduledDayInts
                    Text(shortDayList(days))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func shortDayList(_ days: [Int]) -> String {
        let symbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        if days.count == 7 { return "Every day" }
        if days == [1, 7] || days == [7, 1] { return "Weekends" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays" }
        return days.compactMap { $0 < symbols.count ? symbols[$0] : nil }.joined(separator: ", ")
    }
}

#Preview {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    NavigationStack {
        ManageActivitiesView(dataService: dataService)
    }
    .modelContainer(container)
}
