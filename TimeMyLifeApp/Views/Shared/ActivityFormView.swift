//
//  ActivityFormView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct ActivityFormView: View {
    enum Mode {
        case create
        case edit(Activity)
    }

    let mode: Mode
    let dataService: DataService

    @State private var viewModel: ActivityFormViewModel
    @State private var showEmojiPicker = false
    @State private var showAddTimeEntry = false
    @State private var showEditTimeEntry = false
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    init(mode: Mode, dataService: DataService) {
        self.mode = mode
        self.dataService = dataService

        switch mode {
        case .create:
            _viewModel = State(wrappedValue: ActivityFormViewModel(
                mode: .create,
                dataService: dataService
            ))
        case .edit(let activity):
            _viewModel = State(wrappedValue: ActivityFormViewModel(
                mode: .edit(activity),
                dataService: dataService
            ))
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if let toastMessage {
                toastBanner(message: toastMessage)
                    .zIndex(1)
            }

            ScrollView {
                VStack(spacing: 14) {
                    previewAndNameCard
                    colorCard
                    scheduleCard

                    if case .edit = mode {
                        addTimeEntrySection
                        editTimeEntrySection
                        deleteSection
                    }

                    if let error = viewModel.validationError {
                        Text(error)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .accessibilityLabel("Back")
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        do { if try await viewModel.save() { dismiss() } } catch {}
                    }
                } label: {
                    Text("Save")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(viewModel.isValid ? Color.appAccent : Color.secondary)
                }
                .disabled(!viewModel.isValid)
            }
        }
        .sheet(isPresented: $showAddTimeEntry) {
            if case .edit(let activity) = mode {
                AddTimeEntrySheet(activity: activity, dataService: dataService) {
                    showToast("Time entry added")
                }
            }
        }
        .sheet(isPresented: $showEditTimeEntry) {
            if case .edit(let activity) = mode {
                EditTimeEntrySheet(
                    activity: activity,
                    dataService: dataService,
                    onSaved: { showToast("Time entry updated") },
                    onDeleted: { showToast("Time entry deleted") }
                )
            }
        }
        .sheet(isPresented: $showEmojiPicker) {
            EmojiPickerSheet(selectedEmoji: Binding(
                get: { viewModel.emoji },
                set: { viewModel.emoji = $0 }
            ))
        }
        .alert("Delete Activity?", isPresented: $viewModel.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        if try await viewModel.delete() {
                            dismiss()
                        }
                    } catch {
                        viewModel.validationError = "Couldn't delete activity"
                    }
                }
            }
        } message: {
            Text("This will permanently delete “\(viewModel.trimmedName)” and all associated time entries. This action cannot be undone.")
        }
    }

    // MARK: - Toast

    private func toastBanner(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.appAccent)
            Text(message)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.appCardBackground)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 6)
        )
        .transition(.scale(scale: 0.8).combined(with: .opacity))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toastMessage = message
        }
        toastTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    toastMessage = nil
                }
            }
        }
    }

    private var addTimeEntrySection: some View {
        Button {
            showAddTimeEntry = true
        } label: {
            Label("Add Time Entry", systemImage: "plus.circle")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .appCard()
    }

    private var editTimeEntrySection: some View {
        Button {
            showEditTimeEntry = true
        } label: {
            Label("Edit Time Entry", systemImage: "pencil.circle")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.appAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .appCard()
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            viewModel.showDeleteConfirmation = true
        } label: {
            Text("Delete Activity")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .tint(.red)
        .appCard()
    }

    // MARK: - Preview + Name Card

    private var previewAndNameCard: some View {
        VStack(spacing: 0) {
            // Tappable avatar preview
            HStack {
                Spacer()
                ZStack(alignment: .bottomTrailing) {
                    Button { showEmojiPicker = true } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22)
                                .fill(
                                    viewModel.emoji.isEmpty
                                        ? (Color(hex: viewModel.selectedColorHex) ?? .appAccent)
                                        : (Color(hex: viewModel.selectedColorHex) ?? .appAccent).opacity(0.18)
                                )
                                .frame(width: 80, height: 80)
                                .shadow(
                                    color: (Color(hex: viewModel.selectedColorHex) ?? .appAccent).opacity(0.3),
                                    radius: 16, x: 0, y: 6
                                )
                            if viewModel.emoji.isEmpty {
                                Text(viewModel.name.isEmpty ? "?" : String(viewModel.name.prefix(1)).uppercased())
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(white: 0.18))
                            } else {
                                Text(viewModel.emoji)
                                    .font(.system(size: 42))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.3), value: viewModel.selectedColorHex)
                    .animation(.spring(response: 0.3), value: viewModel.emoji)

                    // Edit badge
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.appAccent)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                        .offset(x: 3, y: 3)
                }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.bottom, 18)

            Divider().opacity(0.5)

            TextField("Activity name", text: Binding(
                get: { viewModel.name },
                set: { viewModel.name = $0 }
            ))
            .font(.system(.title3, design: .rounded, weight: .medium))
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider().opacity(0.5)

            TextField("Category (optional)", text: Binding(
                get: { viewModel.category },
                set: { viewModel.category = $0 }
            ))
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.secondary)
            .textInputAutocapitalization(.words)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
        }
        .appCard()
    }

    // MARK: - Color Card

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COLOR")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(ActivityFormHelpers.availableColors, id: \.hex) { item in
                    colorCircle(hex: item.hex)
                }
            }
        }
        .padding(18)
        .appCard()
    }

    private func colorCircle(hex: String) -> some View {
        let isSelected = viewModel.selectedColorHex.uppercased() == hex.uppercased()
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                viewModel.selectedColorHex = hex
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: hex) ?? .gray)
                    .frame(width: 36, height: 36)
                if isSelected {
                    Circle()
                        .strokeBorder(Color(white: 0.2).opacity(0.55), lineWidth: 2.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(white: 0.18))
                }
            }
            .scaleEffect(isSelected ? 1.12 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SCHEDULE")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)

            HStack(spacing: 8) {
                ForEach(dayChips, id: \.number) { day in
                    dayPill(day: day)
                }
            }
        }
        .padding(18)
        .appCard()
    }

    private func dayPill(day: (number: Int, short: String)) -> some View {
        let isSelected = viewModel.selectedDays.contains(day.number)
        return Button {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                if isSelected { viewModel.selectedDays.remove(day.number) }
                else          { viewModel.selectedDays.insert(day.number) }
            }
        } label: {
            Text(day.short)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(isSelected ? Color(white: 0.15) : Color.secondary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(isSelected ? Color.appTabSelected : Color(.systemGray6)))
        }
        .buttonStyle(.plain)
    }

    private var dayChips: [(number: Int, short: String)] {
        let shorts = ["S", "M", "T", "W", "T", "F", "S"]
        return (1...7).map { (number: $0, short: shorts[$0 - 1]) }
    }
}

private extension ActivityFormView {

    // MARK: - Edit Time Entry Sheet

    struct EditTimeEntrySheet: View {
        let activity: Activity
        let dataService: DataService
        let onSaved: () -> Void
        let onDeleted: () -> Void

        @Environment(\.dismiss) private var dismiss
        @State private var viewModel: EditTimeEntryViewModel
        @State private var showSaveConfirmation = false
        @State private var showDeleteConfirmation = false

        init(
            activity: Activity,
            dataService: DataService,
            onSaved: @escaping () -> Void,
            onDeleted: @escaping () -> Void
        ) {
            self.activity = activity
            self.dataService = dataService
            self.onSaved = onSaved
            self.onDeleted = onDeleted
            _viewModel = State(wrappedValue: EditTimeEntryViewModel(
                activity: activity,
                dataService: dataService
            ))
        }

        var body: some View {
            NavigationStack {
                ZStack {
                    Color.appBackground.ignoresSafeArea()

                    ScrollView {
                        VStack(spacing: 14) {
                            recentEntriesCard
                            if viewModel.selectedEntry != nil {
                                durationCard
                            }
                            if let error = viewModel.alertMessage {
                                Text(error)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
                .navigationTitle("Edit Time Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if viewModel.isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Button {
                                showSaveConfirmation = true
                            } label: {
                                Text("Save")
                                    .font(.system(.body, design: .rounded, weight: .semibold))
                                    .foregroundStyle(viewModel.canSave ? Color.appAccent : Color.secondary)
                            }
                            .disabled(!viewModel.canSave || viewModel.isDeleting)
                        }
                    }
                }
                .alert("Update Time Entry?", isPresented: $showSaveConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Update") {
                        Task {
                            if await viewModel.save() {
                                onSaved()
                                dismiss()
                            }
                        }
                    }
                } message: {
                    Text("This will overwrite the duration for the selected entry.")
                }
                .alert("Delete Time Entry?", isPresented: $showDeleteConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        Task {
                            if await viewModel.deleteSelectedEntry() {
                                onDeleted()
                            }
                        }
                    }
                } message: {
                    Text("This removes this day's logged time for this activity. This cannot be undone.")
                }
                .onAppear { viewModel.loadRecentEntries() }
            }
        }

        // MARK: - Recent Entries Card

        private var recentEntriesCard: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text("RECENT ENTRIES")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                if viewModel.recentEntries.isEmpty {
                    Text("No entries in the last \(AppConstants.editTimeEntryWindowDays) days")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                } else {
                    ForEach(Array(viewModel.recentEntries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(entry: entry)
                        if index < viewModel.recentEntries.count - 1 {
                            Divider().padding(.leading, 18)
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
            .appCard()
        }

        private func entryRow(entry: TimeEntry) -> some View {
            let isSelected = viewModel.selectedEntry?.id == entry.id
            return Button {
                viewModel.selectedEntry = entry
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.appAccent : Color.secondary.opacity(0.5))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDate(entry.date))
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(.primary)
                        Text(entry.totalDuration.formattedDuration(style: .verbose))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }

        // MARK: - Duration Card

        private var durationCard: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("DURATION")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                HStack(spacing: 0) {
                    Picker("Hours", selection: Binding(
                        get: { viewModel.selectedHour },
                        set: { viewModel.selectedHour = $0 }
                    )) {
                        ForEach(0...23, id: \.self) { h in
                            Text(h == 1 ? "1 hr" : "\(h) hrs").tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)

                    Picker("Minutes", selection: Binding(
                        get: { viewModel.selectedMinute },
                        set: { viewModel.selectedMinute = $0 }
                    )) {
                        ForEach(0...59, id: \.self) { m in
                            Text(m == 1 ? "1 min" : "\(m) min").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 150)

                Divider()
                    .padding(.top, 4)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Text("Delete Time Entry")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isDeleting)
            }
            .padding(18)
            .appCard()
        }

        // MARK: - Helpers

        private func formatDate(_ date: Date) -> String {
            let cal = Calendar.current
            if cal.isDateInToday(date) { return "Today" }
            if cal.isDateInYesterday(date) { return "Yesterday" }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }

    }

}

#Preview("Create") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies(seedSample: false)
    NavigationStack {
        ActivityFormView(mode: .create, dataService: dataService)
    }
    .modelContainer(container)
}

#Preview("Edit") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    let activity = IOSViewPreviewSupport.firstActivity(in: container.mainContext)
        ?? (try! Activity.validated(name: "Edit me", colorHex: "#FFC300", category: "Work", scheduledDays: [2, 3, 4, 5, 6]))
    NavigationStack {
        ActivityFormView(mode: .edit(activity), dataService: dataService)
    }
    .modelContainer(container)
}

private extension ActivityFormView.Mode {
    var title: String {
        switch self {
        case .create: return "New Activity"
        case .edit:   return "Edit Activity"
        }
    }
}
