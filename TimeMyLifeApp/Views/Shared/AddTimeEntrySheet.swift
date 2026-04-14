import SwiftUI
import SwiftData

struct AddTimeEntrySheet: View {
    let activity: Activity
    let dataService: DataService
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedHour: Int = 0
    @State private var selectedMinute: Int = 0
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var minDate: Date {
        Calendar.current.date(byAdding: .day, value: -AppConstants.addTimeEntryLookbackDays, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }

    private var totalSeconds: TimeInterval {
        TimeInterval(selectedHour * 3600 + selectedMinute * 60)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        // Date picker card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DATE")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)

                            DatePicker(
                                "Date",
                                selection: $selectedDate,
                                in: minDate...Calendar.current.startOfDay(for: Date()),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(Color.appAccent)
                        }
                        .padding(18)
                        .appCard()

                        // Duration picker card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DURATION")
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)

                            HStack(spacing: 0) {
                                Picker("Hours", selection: $selectedHour) {
                                    ForEach(0...23, id: \.self) { h in
                                        Text(h == 1 ? "1 hr" : "\(h) hrs").tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)

                                Picker("Minutes", selection: $selectedMinute) {
                                    ForEach(0...59, id: \.self) { m in
                                        Text(m == 1 ? "1 min" : "\(m) min").tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 150)

                            if totalSeconds > 0 {
                                let h = Int(totalSeconds) / 3600
                                let m = (Int(totalSeconds) % 3600) / 60
                                let label = h > 0 && m > 0 ? "\(h)h \(m)m"
                                    : h > 0 ? "\(h)h"
                                    : "\(m)m"
                                Text("Adding \(label) to \(activity.name)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .foregroundStyle(Color.appAccent)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, 4)
                            }
                        }
                        .padding(18)
                        .appCard()

                        if let error = errorMessage {
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
            .foregroundStyle(Color.appPrimaryText)
            .fontDesign(.rounded)
            .navigationTitle("Add Time Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button {
                            Task { await save() }
                        } label: {
                            Text("Add")
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(totalSeconds > 0 ? Color.appAccent : Color.secondary)
                        }
                        .disabled(totalSeconds <= 0)
                    }
                }
            }
        }
    }

    private func save() async {
        guard totalSeconds > 0 else {
            errorMessage = "Please select a duration greater than 0"
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try dataService.createOrUpdateTimeEntry(
                activityID: activity.id,
                date: selectedDate,
                duration: totalSeconds
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

#Preview {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    let activity = IOSViewPreviewSupport.firstActivity(in: container.mainContext)!
    NavigationStack {
        AddTimeEntrySheet(activity: activity, dataService: dataService) { }
    }
    .modelContainer(container)
}
