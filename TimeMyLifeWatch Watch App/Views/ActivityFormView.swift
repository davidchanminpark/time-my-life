//
//  ActivityFormView.swift
//  TimeMyLife Watch App
//

import SwiftUI
import SwiftData

/// Shared form view for creating and editing activities
struct ActivityFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(DataService.self) private var dataService

    let mode: ActivityFormMode

    @State private var viewModel: ActivityFormViewModel?
    @State private var showError: Bool = false
    @State private var lastDeleteTime: Date?

    // MARK: - Computed Properties

    // Lazy ViewModel initialization using environment services
    private var vm: ActivityFormViewModel {
        if let viewModel = viewModel {
            return viewModel
        } else {
            let newViewModel = ActivityFormViewModel(
                mode: mode,
                dataService: dataService
            )
            DispatchQueue.main.async {
                viewModel = newViewModel
            }
            return newViewModel
        }
    }

    private var selectedColor: Color {
        Color(hex: vm.selectedColorHex) ?? .blue
    }

    private var selectedColorName: String {
        ActivityFormHelpers.colorName(for: vm.selectedColorHex)
    }

    // MARK: - Body

    var body: some View {
        List {
            // Details section
            Section() {
                // Activity name input using TextFieldLink for better watchOS keyboard support
                VStack {
                    TextFieldLink(prompt: Text("Enter activity name")) {
                        Text(vm.trimmedName.isEmpty ? "Activity name" : vm.trimmedName)
                            .foregroundStyle(vm.trimmedName.isEmpty ? .secondary : .primary)
                    } onSubmit: { newValue in
                        vm.updateName(newValue)
                    }
                    .buttonStyle(.plain)
                }

                if let error = vm.nameValidationError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else {
                    Text("\(vm.nameCharactersRemaining) characters remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Category input using TextFieldLink for better watchOS keyboard support
                HStack {
                    TextFieldLink(prompt: Text("Enter Category")) {
                        Text(vm.trimmedCategory.isEmpty ? "Category Name (optional)" : vm.trimmedCategory)
                            .foregroundStyle(vm.trimmedCategory.isEmpty ? .secondary : .primary)
                    } onSubmit: { newValue in
                        vm.updateCategory(newValue)
                    }
                    .buttonStyle(.plain)
                }

                if let error = vm.categoryValidationError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                } else if !vm.trimmedCategory.isEmpty {
                    Text("\(vm.categoryCharactersRemaining) characters remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Color section
            Section() {
                NavigationLink {
                    ColorSelectionView(selectedColorHex: Binding(
                        get: { vm.selectedColorHex },
                        set: { vm.selectedColorHex = $0 }
                    ))
                } label: {
                    HStack {
                        Text("Color")
                        Spacer()
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 20, height: 20)
                        Text(selectedColorName)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Scheduled Days section
            Section() {
                NavigationLink {
                    WeekdaySelectionView(selectedDays: Binding(
                        get: { vm.selectedDays },
                        set: { vm.selectedDays = $0 }
                    ))
                } label: {
                    HStack {
                        Text("Days")
                        Spacer()
                        if vm.selectedDays.isEmpty {
                            Text("None selected")
                                .foregroundStyle(.red)
                        } else {
                            Text(ActivityFormHelpers.formatSelectedDays(vm.selectedDays))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if vm.selectedDays.isEmpty {
                    Text("Select at least one day")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            // Activity limit warning (create mode only)
            if let limitError = vm.activityLimitError {
                Section {
                    Text(limitError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Delete button (edit mode only)
            if case .edit = vm.mode {
                Section {
                    Button(role: .destructive) {
                        // Rate limiting: 1-second cooldown
                        if let lastDelete = lastDeleteTime,
                           Date().timeIntervalSince(lastDelete) < 1.0 {
                            return
                        }
                        vm.showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Activity")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle(vm.mode.title)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(vm.mode.saveButtonTitle) {
                    saveActivity()
                }
                .disabled(!vm.isValid)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            if let error = vm.validationError {
                Text(error)
            }
        }
        .alert("Delete Activity?", isPresented: Binding(
            get: { vm.showDeleteConfirmation },
            set: { vm.showDeleteConfirmation = $0 }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteActivity()
            }
        } message: {
            if case .edit(let activity) = vm.mode {
                Text("This will permanently delete '\(activity.name)' and all associated time entries. This action cannot be undone.")
            }
        }
    }

    // MARK: - Actions

    private func saveActivity() {
        Task {
            do {
                try await vm.save()
                dismiss()
            } catch {
                showError = true
            }
        }
    }

    private func deleteActivity() {
        Task {
            do {
                try await vm.delete()
                lastDeleteTime = Date()
                dismiss()
            } catch {
                showError = true
            }
        }
    }
}


// MARK: - Color Selection View

struct ColorSelectionView: View {
    @Binding var selectedColorHex: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(ActivityFormHelpers.availableColors, id: \.hex) { colorOption in
                Button {
                    selectedColorHex = colorOption.hex
                    dismiss()
                } label: {
                    HStack {
                        Circle()
                            .fill((Color(hex: colorOption.hex) ?? Color.blue))
                            .frame(width: 24, height: 24)

                        Text(colorOption.name)

                        Spacer()

                        if selectedColorHex == colorOption.hex {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.tint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Select Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Weekday Selection View

struct WeekdaySelectionView: View {
    @Binding var selectedDays: Set<Int>
    @Environment(\.dismiss) private var dismiss

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        List {
            ForEach(1...7, id: \.self) { day in
                let label = weekdayLabel(for: day)

                Toggle(isOn: Binding(
                    get: { selectedDays.contains(day) },
                    set: { isOn in
                        if isOn {
                            selectedDays.insert(day)
                        } else {
                            selectedDays.remove(day)
                        }
                    }
                )) {
                    Text(label)
                }
            }

            if selectedDays.isEmpty {
                Text("Select at least one day")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("Select Days")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weekdayLabel(for day: Int) -> String {
        guard !weekdaySymbols.isEmpty else { return "Day \(day)" }

        let rawIndex = day - 1
        let index = min(max(rawIndex, 0), weekdaySymbols.count - 1)
        return weekdaySymbols[index]
    }
}
