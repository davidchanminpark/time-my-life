//
//  ActivityFormView.swift
//  TimeMyLifeApp
//

import SwiftUI

// fileprivate extension Color {
//     init?(hex: String) {
//         var hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//         if hexString.count == 3 { // shorthand like FFF
//             let r = hexString[hexString.startIndex]
//             let g = hexString[hexString.index(hexString.startIndex, offsetBy: 1)]
//             let b = hexString[hexString.index(hexString.startIndex, offsetBy: 2)]
//             hexString = "\(r)\(r)\(g)\(g)\(b)\(b)"
//         }
//         guard hexString.count == 6 || hexString.count == 8 else { return nil }
//         var int: UInt64 = 0
//         Scanner(string: hexString).scanHexInt64(&int)
//         let a, r, g, b: UInt64
//         if hexString.count == 8 {
//             a = (int & 0xFF000000) >> 24
//             r = (int & 0x00FF0000) >> 16
//             g = (int & 0x0000FF00) >> 8
//             b = (int & 0x000000FF)
//         } else {
//             a = 255
//             r = (int & 0xFF0000) >> 16
//             g = (int & 0x00FF00) >> 8
//             b = (int & 0x0000FF)
//         }
//         self = Color(.sRGB, red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: Double(a) / 255.0)
//     }

//     func toHex(includeAlpha: Bool = false) -> String? {
//         #if canImport(UIKit)
//         let uiColor = UIColor(self)
//         var r: CGFloat = 0
//         var g: CGFloat = 0
//         var b: CGFloat = 0
//         var a: CGFloat = 0
//         guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
//         if includeAlpha {
//             return String(format: "%02X%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
//         } else {
//             return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
//         }
//         #else
//         return nil
//         #endif
//     }
// }

struct ActivityFormView: View {
    enum Mode {
        case create
        case edit(Activity)
    }

    let mode: Mode
    let dataService: DataService

    @State private var viewModel: ActivityFormViewModel
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

    var body: some View {
        Form {
            detailsSection
            colorSection
            scheduleSection
            if let errorMessage = viewModel.validationError {
                errorSection(errorMessage)
            }
        }
        .navigationTitle(mode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        do {
                            if try await viewModel.save() {
                                dismiss()
                            }
                        } catch {
                            // Error is already handled in ViewModel (validationError is set)
                            // Just log for debugging
                            #if DEBUG
                            print("Error saving activity: \(error)")
                            #endif
                        }
                    }
                }
                .disabled(!viewModel.isValid)
            }
        }
    }
    
    // MARK: - View Components
    
    private var detailsSection: some View {
        Section("Details") {
            TextField("Activity Name", text: Binding(
                get: { viewModel.name },
                set: { viewModel.name = $0 }
            ))
            TextField("Category", text: Binding(
                get: { viewModel.category },
                set: { viewModel.category = $0 }
            ))
        }
    }
    
    private var colorSection: some View {
        Section("Color") {
            ColorPicker("Select Color", selection: Binding(
                get: { Color(hex: viewModel.selectedColorHex) ?? .blue },
                set: { newColor in
                    if let hex = newColor.toHex() {
                        viewModel.selectedColorHex = hex
                    }
                }
            ))
        }
    }
    
    private var scheduleSection: some View {
        Section("Schedule") {
            ForEach(daysOfWeek, id: \.number) { day in
                Toggle(day.name, isOn: Binding(
                    get: { viewModel.selectedDays.contains(day.number) },
                    set: { isOn in
                        if isOn {
                            viewModel.selectedDays.insert(day.number)
                        } else {
                            viewModel.selectedDays.remove(day.number)
                        }
                    }
                ))
            }
        }
    }
    
    // MARK: - Helpers
    
    private var daysOfWeek: [(number: Int, name: String)] {
        let weekdaySymbols = Calendar.current.shortWeekdaySymbols
        return (1...7).map { day in
            let rawIndex = day - 1
            let index = min(max(rawIndex, 0), weekdaySymbols.count - 1)
            let name = index < weekdaySymbols.count ? weekdaySymbols[index] : "Day \(day)"
            return (number: day, name: name)
        }
    }
    
    private func errorSection(_ errorMessage: String) -> some View {
        Section {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}

private extension ActivityFormView.Mode {
    var title: String {
        switch self {
        case .create:
            return "New Activity"
        case .edit:
            return "Edit Activity"
        }
    }
}
