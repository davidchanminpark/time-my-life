import SwiftUI
import SwiftData

struct EmojiPickerSheet: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) private var dismiss

    @State private var customInput: String = ""

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private let sections: [(title: String, emojis: [String])] = [
        ("Sport & Health", ["🏃", "🧘", "💪", "🚴", "🏊", "🤸", "🏋️", "🎾", "⚽", "🧗", "🥊", "🏄"]),
        ("Learning & Work", ["📚", "✍️", "💻", "🎓", "🔬", "📊", "💡", "🎯", "📝", "📖", "🗓️", "🧠"]),
        ("Creative", ["🎨", "🎵", "📷", "🎬", "🖌️", "🎸", "🎹", "✂️", "🎭", "🎤", "🖊️", "🎲"]),
        ("Lifestyle", ["☕", "🛌", "🍳", "🌿", "💊", "🥗", "🌱", "🧺", "🛁", "🧴", "🍵", "🥦"]),
        ("Social & Fun", ["👥", "🎮", "💬", "🌍", "🎉", "🛍️", "📱", "🍕", "🎪", "🤝", "🎁", "🏡"]),
        ("Mood & Nature", ["🌸", "🌞", "⭐", "🔥", "💫", "✨", "🌈", "🍀", "🦋", "🌙", "🌺", "🌻"])
    ]

    private var allPresetEmojis: [String] { sections.flatMap(\.emojis) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.title)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.4)
                                .padding(.horizontal, 4)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(section.emojis, id: \.self) { emoji in
                                    Button {
                                        selectedEmoji = emoji
                                        dismiss()
                                    } label: {
                                        Text(emoji)
                                            .font(.system(size: 28))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 48)
                                            .background(
                                                selectedEmoji == emoji
                                                    ? Color.appTabSelected.opacity(0.35)
                                                    : Color(.systemGray6)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    customSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Choose Emoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if !customInput.isEmpty {
                            selectedEmoji = customInput
                        }
                        dismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                }
                ToolbarItem(placement: .cancellationAction) {
                    if !selectedEmoji.isEmpty {
                        Button("Remove") {
                            selectedEmoji = ""
                            dismiss()
                        }
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.red)
                    }
                }
            }
            .onAppear {
                if !selectedEmoji.isEmpty && !allPresetEmojis.contains(selectedEmoji) {
                    customInput = selectedEmoji
                }
            }
        }
    }

    // MARK: - Custom Section

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CUSTOM")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)
                .padding(.horizontal, 4)

            HStack(spacing: 10) {
                TextField("Type an emoji…", text: $customInput)
                    .font(.system(size: 24))
                    .frame(height: 48)
                    .padding(.horizontal, 14)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: customInput) { _, newValue in
                        if let first = newValue.first {
                            customInput = String(first)
                        }
                    }

                if !customInput.isEmpty {
                    Button {
                        selectedEmoji = customInput
                        dismiss()
                    } label: {
                        Text(customInput)
                            .font(.system(size: 28))
                            .frame(width: 56, height: 48)
                            .background(
                                selectedEmoji == customInput
                                    ? Color.appTabSelected.opacity(0.35)
                                    : Color.appAccent.opacity(0.1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.appAccent.opacity(0.45), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: customInput.isEmpty)

            Text("Switch to the emoji keyboard (🌐) to enter any emoji")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .padding(.horizontal, 4)
        }
    }
}

#Preview {
    @State var dummyEmoji = ""
    return EmojiPickerSheet(selectedEmoji: $dummyEmoji)
}
