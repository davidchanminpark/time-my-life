//
//  GoalFormView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct GoalFormView: View {

    enum Mode {
        case create
        case edit(Goal)
    }

    let mode: Mode
    let dataService: DataService
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var selectedActivityID: UUID? = nil
    @State private var selectedFrequency: GoalFrequency = .daily
    @State private var targetMinutes: Int = 60
    @State private var isActive: Bool = true

    // Supporting state
    @State private var activities: [Activity] = []
    @State private var showDuplicateAlert = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        if isCreating {
                            activityCard
                            frequencyCard
                        }
                        durationCard
                        if !isCreating {
                            activeCard
                            deleteSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(isCreating ? "New Goal" : "Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Color.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(canSave ? Color.appAccent : Color.secondary)
                        .disabled(!canSave)
                }
            }
            .alert("Duplicate Goal", isPresented: $showDuplicateAlert) {
                Button("OK") { }
            } message: {
                Text("A goal already exists for this activity and frequency.")
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete Goal?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteGoalConfirmed()
                }
            } message: {
                Text("This will permanently delete this goal. This action cannot be undone.")
            }
            .task {
                loadActivities()
                populateForEdit()
            }
        }
    }

    // MARK: - Activity Card

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ACTIVITY")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if activities.isEmpty {
                Text("No activities yet — create one on the Home tab first.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(activities) { activity in
                        activityOption(activity)
                    }
                }
            }
        }
        .padding(18)
        .appCard()
    }

    private func activityOption(_ activity: Activity) -> some View {
        let isSelected = selectedActivityID == activity.id
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                selectedActivityID = activity.id
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            activity.emoji.isEmpty
                                ? activity.color()
                                : activity.color().opacity(0.18)
                        )
                        .frame(width: 36, height: 36)
                    if activity.emoji.isEmpty {
                        Text(String(activity.name.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(white: 0.18))
                    } else {
                        Text(activity.emoji)
                            .font(.system(size: 18))
                    }
                }

                Text(activity.name)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Color.primary)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.appAccent)
                        .font(.system(size: 20))
                } else {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.appAccent.opacity(0.08) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Frequency Card

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("FREQUENCY")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(spacing: 8) {
                frequencyPill(for: .daily)
                frequencyPill(for: .weekly)
                Spacer()
            }
        }
        .padding(18)
        .appCard()
    }

    private func frequencyPill(for freq: GoalFrequency) -> some View {
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

    // MARK: - Duration Card

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("TARGET DURATION")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(alignment: .center) {
                Text(formatMinutes(targetMinutes))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.appAccent)

                Spacer()

                Stepper("", value: $targetMinutes, in: 15...1440, step: 15)
                    .labelsHidden()
            }

            Text("Adjust in 15-minute increments (max 24h)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
        .padding(18)
        .appCard()
    }

    // MARK: - Active Card

    private var activeCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Active")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                Text("Paused goals won't count toward streaks")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isActive)
                .tint(Color.appAccent)
                .labelsHidden()
        }
        .padding(18)
        .appCard()
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Text("Delete Goal")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .tint(.red)
        .appCard()
    }

    // MARK: - Helpers

    private var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    private var canSave: Bool {
        let hasActivity = isCreating ? selectedActivityID != nil : true
        return hasActivity && targetMinutes >= 15
    }

    private var targetSeconds: Int { targetMinutes * 60 }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }

    private func loadActivities() {
        activities = (try? dataService.fetchActivities()) ?? []
    }

    private func populateForEdit() {
        if case .edit(let goal) = mode {
            targetMinutes = goal.targetSeconds / 60
            isActive = goal.isActive
        }
    }

    private func deleteGoalConfirmed() {
        guard case .edit(let goal) = mode else { return }
        do {
            try dataService.deleteGoal(goal)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }

    private func save() {
        do {
            switch mode {
            case .create:
                guard let activityID = selectedActivityID else { return }
                if (try? dataService.goalExists(activityID: activityID, frequency: selectedFrequency)) == true {
                    showDuplicateAlert = true
                    return
                }
                let goal = Goal(
                    activityID: activityID,
                    frequency: selectedFrequency,
                    targetSeconds: targetSeconds
                )
                try dataService.createGoal(goal)

            case .edit(let goal):
                goal.targetSeconds = targetSeconds
                goal.isActive = isActive
                try dataService.updateGoal(goal)
            }
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

#Preview("Create goal") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    GoalFormView(mode: .create, dataService: dataService, onSave: {})
        .modelContainer(container)
}
