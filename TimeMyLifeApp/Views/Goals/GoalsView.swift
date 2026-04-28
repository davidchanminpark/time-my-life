//
//  GoalsView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct GoalsView: View {
    let dataService: DataService

    @State private var viewModel: GoalsViewModel
    @State private var selectedFrequency: GoalFrequency = .daily
    @State private var showingAddGoal = false
    @State private var editingGoal: Goal? = nil
    @State private var draggingGoalID: UUID?

    init(dataService: DataService) {
        self.dataService = dataService
        _viewModel = State(wrappedValue: GoalsViewModel(dataService: dataService))
    }

    private var currentGoals: [GoalsViewModel.GoalWithProgress] {
        selectedFrequency == .daily
            ? viewModel.dailyGoalsWithProgress
            : viewModel.weeklyGoalsWithProgress
    }

    private var currentGoalsBinding: Binding<[GoalsViewModel.GoalWithProgress]> {
        selectedFrequency == .daily
            ? $viewModel.dailyGoalsWithProgress
            : $viewModel.weeklyGoalsWithProgress
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text("Goals")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(Color.appPrimaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    frequencyToggle
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                    if viewModel.isLoading {
                        loadingView
                    } else if currentGoals.isEmpty {
                        emptyStateView
                    } else {
                        goalsList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .foregroundStyle(Color.appPrimaryText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.appAccent)
                    }
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                GoalFormView(
                    mode: .create,
                    dataService: dataService,
                    onSave: { Task { await viewModel.loadGoals() } }
                )
                .fontDesign(.rounded)
            }
            .sheet(item: $editingGoal) { goal in
                GoalFormView(
                    mode: .edit(goal),
                    dataService: dataService,
                    onSave: { Task { await viewModel.loadGoals() } }
                )
                .fontDesign(.rounded)
            }
            .onAppear {
                Task { await viewModel.loadGoals() }
            }
        }
    }

    // MARK: - Frequency Toggle

    private var frequencyToggle: some View {
        HStack(spacing: 8) {
            frequencyButton(for: .daily)
            frequencyButton(for: .weekly)
            Spacer()
        }
    }

    private func frequencyButton(for freq: GoalFrequency) -> some View {
        let isSelected = selectedFrequency == freq
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                selectedFrequency = freq
            }
        } label: {
            Text(freq == .daily ? "Daily" : "Weekly")
                .font(.system(.subheadline, design: .rounded, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.appAccent : Color(.systemGray5))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subviews

    private var goalsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(currentGoals) { goalWithProgress in
                    GoalCardView(
                        goalWithProgress: goalWithProgress,
                        onTap: { editingGoal = goalWithProgress.goal }
                    )
                    .padding(.horizontal, 20)
                    .onDrag {
                        draggingGoalID = goalWithProgress.goal.id
                        return NSItemProvider(object: goalWithProgress.goal.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: GoalDropDelegate(
                        goalWithProgress: goalWithProgress,
                        goalsBinding: currentGoalsBinding,
                        draggingID: $draggingGoalID,
                        onReorder: { saveGoalOrder() }
                    ))
                }

                addGoalButton
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
            }
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
    }

    private func saveGoalOrder() {
        if selectedFrequency == .daily {
            viewModel.saveDailyGoalOrder()
        } else {
            viewModel.saveWeeklyGoalOrder()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("🎯")
                .font(.system(size: 52))
            VStack(spacing: 6) {
                Text("No \(selectedFrequency == .daily ? "daily" : "weekly") goals yet")
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                Text("Tap + to set a goal for your activities")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private var addGoalButton: some View {
        Button {
            showingAddGoal = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                Text("Add Goal")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
            }
            .foregroundStyle(Color.appPrimaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Goal Drop Delegate

private struct GoalDropDelegate: DropDelegate {
    let goalWithProgress: GoalsViewModel.GoalWithProgress
    let goalsBinding: Binding<[GoalsViewModel.GoalWithProgress]>
    @Binding var draggingID: UUID?
    let onReorder: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggingID,
              draggingID != goalWithProgress.goal.id,
              let fromIndex = goalsBinding.wrappedValue.firstIndex(where: { $0.goal.id == draggingID }),
              let toIndex = goalsBinding.wrappedValue.firstIndex(where: { $0.goal.id == goalWithProgress.goal.id }) else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            goalsBinding.wrappedValue.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
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

#Preview {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    GoalsView(dataService: dataService)
        .modelContainer(container)
}

#Preview("No goals") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies(seedSample: false)
    GoalsView(dataService: dataService)
        .modelContainer(container)
}
