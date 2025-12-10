//
//  CRUDTestView.swift
//  TimeMyLife Watch App
//

import SwiftUI
import SwiftData

/// View for manually testing CRUD operations with sample data
struct CRUDTestView: View {
    @State private var viewModel: CRUDTestViewModel

    init(dataService: DataService, timerService: TimerService) {
        _viewModel = State(wrappedValue: CRUDTestViewModel(
            dataService: dataService,
            timerService: timerService
        ))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Data Overview") {
                    Text("Activities: \(viewModel.activityCount)")
                    Text("Time Entries: \(viewModel.timeEntryCount)")
                }

                Section("CRUD Operations") {
                    Button("Test Create") {
                        Task { await viewModel.testCreate() }
                    }

                    Button("Test Read") {
                        Task { await viewModel.testRead() }
                    }

                    Button("Test Update") {
                        Task { await viewModel.testUpdate() }
                    }

                    Button("Test Delete") {
                        Task { await viewModel.testDelete() }
                    }

                    Button("Test Timer") {
                        Task { await viewModel.testTimer() }
                    }

                    Button("Clear All Data", role: .destructive) {
                        Task { await viewModel.clearAllData() }
                    }
                }

                Section("Quick Large Time Actions") {
                    Button("Add 10 Hours to First Activity") {
                        Task { await viewModel.addLargeTime(hours: 10) }
                    }

                    Button("Add 24 Hours to First Activity") {
                        Task { await viewModel.addLargeTime(hours: 24) }
                    }

                    Button("Create Activity with 50 Hours") {
                        Task { await viewModel.createActivityWithLargeTime(hours: 50) }
                    }
                }

                Section("Operation Log") {
                    if viewModel.operationLog.isEmpty {
                        Text("No operations yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.operationLog.reversed(), id: \.self) { log in
                            Text(log)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("CRUD Test")
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage)
            }
            .task {
                await viewModel.loadCounts()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([
        Activity.self,
        TimeEntry.self,
        ActiveTimer.self
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: config
    )

    let context = container.mainContext
    let dataService = DataService(modelContext: context)
    let timerService = TimerService(modelContext: context)

    CRUDTestView(dataService: dataService, timerService: timerService)
        .modelContainer(container)
}
