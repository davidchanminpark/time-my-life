//
//  HomeView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HomeView: View {
    @State private var viewModel: MainViewModel
    @State private var greetingText: String = ""
    @State private var draggingActivityID: UUID?

    @AppStorage("midnightModePreference") private var midnightModePreference: String = "unset"
    @AppStorage("lastMidnightPromptDate") private var lastMidnightPromptDate: String = ""

    init(dataService: DataService, timerService: TimerService) {
        _viewModel = State(wrappedValue: MainViewModel(
            dataService: dataService,
            timerService: timerService
        ))
    }

    // MARK: - Computed Properties

    private var todayDateString: String {
        let today = Calendar.current.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: today)
    }

    private var shouldShowDayToggle: Bool {
        viewModel.shouldShowDayToggle(
            midnightPreference: midnightModePreference,
            lastPromptDate: lastMidnightPromptDate,
            todayDateString: todayDateString
        )
    }

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9:   return "🌅"
        case 9..<12:  return "🌱"
        case 12..<15: return "☀️"
        case 15..<18: return "🍂"
        case 18..<22: return "🌇"
        default:      return "🌙"
        }
    }

    private func randomGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let options: [String]
        switch hour {
        case 5..<9:
            options = ["Rise & thrive", "Early bird wins", "Make it count", "Fresh start"]
        case 9..<12:
            options = ["In your flow", "Deep focus time", "Lock in", "On a roll"]
        case 12..<15:
            options = ["Keep the momentum", "Midday grind", "Stay locked in", "Halfway there"]
        case 15..<18:
            options = ["Finish strong", "Push through", "Final stretch", "Don't slow down"]
        case 18..<22:
            options = ["Reflect & recharge", "Wind down well", "Good work today", "Evening mode"]
        default:
            options = ["Night owl mode", "Burning the midnight oil", "Late night grind", "Still going"]
        }
        return options.randomElement() ?? options[0]
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        greetingHeader
                            .padding(.horizontal, 24)
                            .padding(.top, 12)
                            .padding(.bottom, 24)

                        if shouldShowDayToggle {
                            dayToggleView
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                        }

                        if viewModel.activities.isEmpty {
                            emptyState
                        } else {
                            activitiesSection
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 110)
                }
                .refreshable {
                    await viewModel.loadActivities()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
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
            .onAppear {
                greetingText = randomGreeting()
                Task {
                    await viewModel.loadActivities()
                    checkMidnightModePrompt()
                }
            }
        }
        .environment(viewModel.dataService)
        .environment(viewModel.timerService)
    }

    // MARK: - Greeting Header

    private var greetingHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(greetingEmoji) \(greetingText)")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appPrimaryText)
                Text(formattedDate)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Day Toggle

    private var dayToggleView: some View {
        HStack(spacing: 8) {
            ForEach(MainViewModel.ViewMode.allCases, id: \.self) { mode in
                dayToggleButton(for: mode)
            }
            Spacer()
        }
    }

    private func dayToggleButton(for mode: MainViewModel.ViewMode) -> some View {
        let isSelected = viewModel.viewMode == mode
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                viewModel.viewMode = mode
            }
            Task { await viewModel.loadActivities() }
        } label: {
            Text(mode.rawValue)
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appAccent : Color(.systemGray5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Activities Section

    private var activitiesSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.activities) { activity in
                NavigationLink {
                    ActivityTimerView(
                        activity: activity,
                        targetDate: viewModel.targetDate,
                        dataService: viewModel.dataService,
                        timerService: viewModel.timerService
                    )
                } label: {
                    ActivityRowView(
                        activity: activity,
                        displayedDuration: viewModel.durationForDate(activity: activity),
                        isTimerRunning: viewModel.isTimerRunning(for: activity),
                        targetDate: viewModel.targetDate
                    )
                }
                .buttonStyle(.plain)
                .onDrag {
                    draggingActivityID = activity.id
                    return NSItemProvider(object: activity.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: ActivityDropDelegate(
                    activity: activity,
                    activities: $viewModel.activities,
                    draggingID: $draggingActivityID,
                    onReorder: { viewModel.saveActivityOrder() }
                ))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("✨")
                .font(.system(size: 52))
            VStack(spacing: 6) {
                Text("No activities yet")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("Tap + to add your first activity")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if viewModel.isActivityLimitReached() {
                Button {
                    viewModel.showActivityLimitAlert = true
                } label: {
                    addButtonLabel
                }
            } else {
                NavigationLink {
                    ActivityFormView(
                        mode: .create,
                        dataService: viewModel.dataService
                    )
                } label: {
                    addButtonLabel
                }
            }
        }
    }

    private var addButtonLabel: some View {
        Image(systemName: "plus")
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.appAccent)
    }

    // MARK: - Helpers

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

// Home tab only (no bottom bar — that lives in `ContentView` / `IOSPreviewFullAppShell`).
#Preview("Home — sample data") {
    let (container, dataService, timerService) = IOSViewPreviewSupport.dependencies()
    NavigationStack {
        HomeView(dataService: dataService, timerService: timerService)
    }
    .modelContainer(container)
}

#Preview("Home — empty") {
    let (container, dataService, timerService) = IOSViewPreviewSupport.dependencies(seedSample: false)
    NavigationStack {
        HomeView(dataService: dataService, timerService: timerService)
    }
    .modelContainer(container)
}

#Preview("Full app — floating tab bar") {
    IOSPreviewFullAppShell()
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
                Text("You've reached the maximum of \(AppConstants.maxActivities) activities. Delete an activity from Settings to add a new one.")
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

// MARK: - Activity Drop Delegate

private struct ActivityDropDelegate: DropDelegate {
    let activity: Activity
    @Binding var activities: [Activity]
    @Binding var draggingID: UUID?
    let onReorder: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != activity.id,
              let fromIndex = activities.firstIndex(where: { $0.id == draggingID }),
              let toIndex = activities.firstIndex(where: { $0.id == activity.id }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            activities.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        onReorder()
        return true
    }

    func dropExited(info: DropInfo) {
        // No action needed
    }
}
