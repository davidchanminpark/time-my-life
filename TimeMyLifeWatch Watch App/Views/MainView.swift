//
//  MainView.swift
//  TimeMyLife Watch App
//

import SwiftUI
import SwiftData
import WatchKit

struct MainView: View {
    @State private var viewModel: MainViewModel

    @AppStorage("midnightModePreference") private var midnightModePreference: String = "unset"
    @AppStorage("lastMidnightPromptDate") private var lastMidnightPromptDate: String = ""

    // MARK: - Initialization

    init(dataService: DataService, timerService: TimerService) {
        _viewModel = State(wrappedValue: MainViewModel(
            dataService: dataService,
            timerService: timerService
        ))
    }

    // MARK: - Computed Properties

    // Get today's date as a string for comparison
    private var todayDateString: String {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: today)
    }

    // Should show the Yesterday/Today toggle
    private var shouldShowDayToggle: Bool {
        viewModel.shouldShowDayToggle(
            midnightPreference: midnightModePreference,
            lastPromptDate: lastMidnightPromptDate,
            todayDateString: todayDateString
        )
    }

    // MARK: - Body

    var body: some View {
        navigationView
            .environment(viewModel.dataService)
            .environment(viewModel.timerService)
    }
    
    private var navigationView: some View {
        NavigationStack {
            mainContent
                .navigationTitle(viewModel.viewMode.rawValue)
                .toolbar {
                    toolbarContent
                }
                .modifier(AlertModifiers(
                    showActivityLimitAlert: Binding(
                        get: { viewModel.showActivityLimitAlert },
                        set: { viewModel.showActivityLimitAlert = $0 }
                    ),
                    showMidnightPrompt: Binding(
                        get: { viewModel.showMidnightPrompt },
                        set: { viewModel.showMidnightPrompt = $0 }
                    ),
                    midnightModePreference: $midnightModePreference,
                    lastMidnightPromptDate: $lastMidnightPromptDate,
                    todayDateString: todayDateString
                ))
                .task {
                    await viewModel.loadActivities()
                    checkMidnightModePrompt()
                }
        }
    }
    
    // MARK: - View Components
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            if shouldShowDayToggle {
                dayToggleView
            }
            activitiesList
        }
    }
    
    private var dayToggleView: some View {
        HStack(spacing: 0) {
            ForEach(MainViewModel.ViewMode.allCases, id: \.self) { mode in
                dayToggleButton(for: mode)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.2))
    }
    
    private func dayToggleButton(for mode: MainViewModel.ViewMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { }
            Task { @MainActor in
                await viewModel.switchViewMode(to: mode)
            }
        } label: {
            dayToggleButtonLabel(for: mode)
        }
        .buttonStyle(.plain)
    }

    private func dayToggleButtonLabel(for mode: MainViewModel.ViewMode) -> some View {
        let isSelected = viewModel.viewMode == mode
        return Text(mode.rawValue)
            .font(.caption)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundColor(isSelected ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue : Color.clear)
            )
    }
    
    private var activitiesList: some View {
        List {
            if viewModel.activities.isEmpty {
                ContentUnavailableView(
                    "No Activities \(viewModel.viewMode == .today ? "Today" : "Yesterday")",
                    systemImage: "calendar.badge.clock",
                    description: Text("Add activities using the + button")
                )
            } else {
                ForEach(viewModel.activities) { activity in
                    ActivityRowView(
                        activity: activity,
                        displayedDuration: viewModel.durationForDate(activity: activity),
                        isTimerRunning: viewModel.isTimerRunning(for: activity),
                        targetDate: viewModel.targetDate
                    )
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape.fill")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isActivityLimitReached() {
                Button {
                    viewModel.showActivityLimitAlert = true
                } label: {
                    Image(systemName: "plus")
                }
            } else {
                NavigationLink {
                    ActivityFormView(mode: .create)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }
    

    // MARK: - Helper Functions

    /// Check if we should show the midnight mode prompt
    private func checkMidnightModePrompt() {
        if viewModel.shouldShowMidnightPrompt(
            midnightPreference: midnightModePreference,
            lastPromptDate: lastMidnightPromptDate,
            todayDateString: todayDateString
        ) {
            viewModel.showMidnightPrompt = true
        }
    }
}

// MARK: - Alert Modifiers

private struct AlertModifiers: ViewModifier {
    @Binding var showActivityLimitAlert: Bool
    @Binding var showMidnightPrompt: Bool
    @Binding var midnightModePreference: String
    @Binding var lastMidnightPromptDate: String
    let todayDateString: String
    
    func body(content: Content) -> some View {
        content
            .alert("Activity Limit Reached", isPresented: $showActivityLimitAlert) {
                Button("OK") { }
            } message: {
                Text("You've reached the maximum of 30 activities. Delete an activity from Settings to add a new one.")
            }
            .alert("Still finishing up?", isPresented: $showMidnightPrompt) {
                Button("Yes") {
                    midnightModePreference = "today"
                    lastMidnightPromptDate = todayDateString
                }
                Button("Yes, no need to ask again") {
                    midnightModePreference = "always"
                    lastMidnightPromptDate = todayDateString
                }
                Button("No", role: .cancel) {
                    midnightModePreference = "no"
                    lastMidnightPromptDate = todayDateString
                }
            } message: {
                Text("Do you want to continue yesterday's tasks past midnight?")
            }
    }
}

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

    MainView(dataService: dataService, timerService: timerService)
        .modelContainer(container)
}
