//
//  YearlyStatsView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import UIKit

struct YearlyStatsView: View {
    let dataService: DataService

    @State private var viewModel: YearlyStatsViewModel
    @State private var shareItem: ShareableImage?
    @State private var isRendering = false

    init(dataService: DataService) {
        self.dataService = dataService
        _viewModel = State(wrappedValue: YearlyStatsViewModel(dataService: dataService))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    yearPicker

                    if viewModel.isLoading {
                        ProgressView().padding(.top, 40)
                    } else if viewModel.totalHours == 0 {
                        emptyState
                    } else {
                        heroCard
                        topActivitiesCard
                        if !viewModel.activityStreaks.isEmpty {
                            streaksCard
                        }
                        heatmapCard
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("Year in Review")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { renderAndShare() } label: {
                    if isRendering {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(viewModel.totalHours == 0 || isRendering)
                .foregroundStyle(Color.appAccent)
            }
        }
        .task { await viewModel.loadYear(viewModel.selectedYear) }
        .sheet(item: $shareItem) { item in
            ShareSheet(image: item.image)
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        Picker("Year", selection: Binding(
            get: { viewModel.selectedYear },
            set: { (year: Int) in Task { await viewModel.loadYear(year) } }
        )) {
            ForEach(viewModel.availableYears, id: \.self) { year in
                Text(String(year)).tag(year)
            }
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                heroItem(value: String(format: "%.0f", viewModel.totalHours), label: "Total Hours")
                Divider().frame(height: 40)
                heroItem(value: "\(viewModel.activitiesCount)", label: "Activities")
                if let most = viewModel.mostActiveDay {
                    Divider().frame(height: 40)
                    heroItem(
                        value: String(format: "%.1fh", most.hours),
                        label: "Best Day"
                    )
                }
            }
            .padding(.vertical, 14)

            if let most = viewModel.mostActiveDay {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(.caption, design: .rounded))
                    Text("Most active: \(most.date.formatted(.dateTime.month(.wide).day()))")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .appCard()
    }

    private func heroItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Top Activities

    private var topActivitiesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Top Activities")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ForEach(viewModel.topActivities.indices, id: \.self) { i in
                let stat = viewModel.topActivities[i]
                HStack(spacing: 12) {
                    Text("#\(i + 1)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, alignment: .center)
                        .padding(.leading, 8)

                    Circle()
                        .fill(stat.activity.color())
                        .frame(width: 11, height: 11)

                    Text(stat.activity.name)
                        .font(.system(.subheadline, design: .rounded))

                    Spacer()

                    Text(String(format: "%.0fh", stat.hours))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .padding(.trailing, 16)
                }
                .padding(.vertical, 11)

                if i < viewModel.topActivities.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }

            Spacer(minLength: 8)
        }
        .appCard()
    }

    // MARK: - Streaks

    private var streaksCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Longest Streaks")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ForEach(viewModel.activityStreaks.indices, id: \.self) { i in
                let streak = viewModel.activityStreaks[i]
                HStack(spacing: 12) {
                    Text("🔥")
                        .font(.system(.subheadline, design: .rounded))
                        .frame(width: 28, alignment: .center)
                        .padding(.leading, 8)

                    Circle()
                        .fill(streak.activity.color())
                        .frame(width: 11, height: 11)

                    Text(streak.activity.name)
                        .font(.system(.subheadline, design: .rounded))

                    Spacer()

                    Text("\(streak.longestStreak) days")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .padding(.trailing, 16)
                }
                .padding(.vertical, 11)

                if i < viewModel.activityStreaks.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }

            Spacer(minLength: 8)
        }
        .appCard()
    }

    // MARK: - Monthly Heatmap

    private var heatmapCard: some View {
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let maxH = max(viewModel.maxMonthlyHours, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Activity")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 12) {
                ForEach(0..<12, id: \.self) { month in
                    let hours = viewModel.monthlyTotals[month]
                    let intensity = hours / maxH

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appAccent.opacity(max(0.08, intensity * 0.85)))
                            .frame(height: 48)
                            .overlay {
                                if hours > 0 {
                                    Text(String(format: "%.0fh", hours))
                                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                                        .foregroundStyle(intensity > 0.5 ? .white : Color.appAccent)
                                }
                            }

                        Text(monthNames[month])
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .appCard()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Data for \(viewModel.selectedYear)",
            systemImage: "calendar",
            description: Text("Start tracking activities to see your yearly summary.")
        )
        .padding(.top, 40)
    }

    // MARK: - Share

    private func renderAndShare() {
        guard !isRendering else { return }
        isRendering = true
        Task { @MainActor in
            defer { isRendering = false }
            let card = YearShareCard(viewModel: viewModel)
            let renderer = ImageRenderer(content: card.frame(width: 360))
            renderer.scale = 3.0
            if let uiImage = renderer.uiImage {
                shareItem = ShareableImage(image: uiImage)
            }
        }
    }
}

// MARK: - Share Support Types

struct ShareableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ShareSheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Share Card (rendered to image)

private struct YearShareCard: View {
    let viewModel: YearlyStatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.selectedYear) in Review")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Time My Life")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(Color.appAccent)
            }

            Divider()

            // Hero numbers
            HStack(spacing: 0) {
                shareHeroItem(value: String(format: "%.0fh", viewModel.totalHours), label: "Total Hours")
                shareHeroItem(value: "\(viewModel.activitiesCount)", label: "Activities")
                shareHeroItem(value: "\(viewModel.activityStreaks.first?.longestStreak ?? 0)d", label: "Best Streak")
            }

            // Top 3 activities
            if !viewModel.topActivities.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Activities")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.topActivities.prefix(3)) { stat in
                        HStack {
                            Circle().fill(stat.activity.color()).frame(width: 8, height: 8)
                            Text(stat.activity.name).font(.caption)
                            Spacer()
                            Text(String(format: "%.0fh", stat.hours))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 4)
        .padding(16)
        .background(Color(.systemGroupedBackground))
    }

    private func shareHeroItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title3).fontWeight(.bold).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    NavigationStack {
        YearlyStatsView(dataService: dataService)
    }
    .modelContainer(container)
}
