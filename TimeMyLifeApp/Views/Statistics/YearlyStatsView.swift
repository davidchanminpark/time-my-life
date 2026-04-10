//
//  YearlyStatsView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import UIKit
import Charts

struct YearlyStatsView: View {
    let dataService: DataService

    @State private var viewModel: YearlyStatsViewModel
    @State private var cachedShareImage: UIImage?
    @State private var cachedShareURL: URL?
    @State private var showAllActivities = false

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
                        pieChartCard
                        weekdayBreakdownCard
                        topActivitiesCard
                        if !viewModel.activityStreaks.isEmpty {
                            streaksCard
                        }
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
                if let url = cachedShareURL, let image = cachedShareImage {
                    ShareLink(
                        item: url,
                        preview: SharePreview(
                            String(viewModel.selectedYear) + " in Review",
                            image: Image(uiImage: image)
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .offset(y: -3)
                    }
                    .foregroundStyle(Color.appAccent)
                } else {
                    Button { } label: {
                        Image(systemName: "square.and.arrow.up")
                            .offset(y: -3)
                    }
                    .disabled(true)
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
        .task {
            await viewModel.loadYear(viewModel.selectedYear)
            guard viewModel.totalHours > 0 else { return }
            // Let the navigation animation settle before blocking the main thread
            try? await Task.sleep(for: .milliseconds(400))
            prerenderShareCard()
        }
    }

    // MARK: - Year Picker

    private var yearPicker: some View {
        Picker("Year", selection: Binding(
            get: { viewModel.selectedYear },
            set: { (year: Int) in
                cachedShareImage = nil
                cachedShareURL = nil
                Task {
                    await viewModel.loadYear(year)
                    guard viewModel.totalHours > 0 else { return }
                    try? await Task.sleep(for: .milliseconds(400))
                    prerenderShareCard()
                }
            }
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
        HStack(spacing: 0) {
            heroItem(value: String(format: "%.0f", viewModel.totalHours), label: "Total Hours")
            Divider().frame(height: 40)
            heroItem(value: "\(viewModel.activitiesCount)", label: "Activities")
        }
        .padding(.vertical, 14)
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

    // MARK: - Pie (Donut) Chart

    private var pieChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Distribution")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            HStack(alignment: .center, spacing: 16) {
                Chart(viewModel.activityStats) { stat in
                    SectorMark(
                        angle: .value("Duration", stat.totalDuration),
                        innerRadius: .ratio(0.54),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(stat.color)
                }
                .frame(width: 140, height: 140)
                .chartLegend(.hidden)

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(viewModel.activityStats.prefix(7)) { stat in
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(stat.color)
                                .frame(width: 11, height: 11)
                            Text(stat.activity.name)
                                .font(.system(.caption, design: .rounded))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(String(format: "%.0f%%", stat.percentage * 100))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    if viewModel.activityStats.count > 7 {
                        Text("+\(viewModel.activityStats.count - 7) more")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .appCard()
    }

    // MARK: - Weekday Breakdown

    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var weekdayBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekday Averages")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            Chart(viewModel.weekdayBarSegments) { seg in
                BarMark(
                    x: .value("Weekday", weekdayLabels[seg.weekday - 1]),
                    y: .value("Hours", seg.averageHours)
                )
                .foregroundStyle(seg.color)
                .cornerRadius(2)
            }
            .chartXScale(domain: weekdayLabels)
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(values: viewModel.weekdayBarYAxisTickHours) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = value.as(Double.self) {
                            Text(StatsChartYAxis.yAxisLabel(
                                hours: h,
                                useMinuteLabels: viewModel.weekdayBarUseMinuteYAxis
                            ))
                            .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 180)
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.activityStats.prefix(5)) { stat in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(stat.color)
                                .frame(width: 9, height: 9)
                            Text(stat.activity.name)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 16)
        .appCard()
    }

    // MARK: - Top Activities

    private var topActivitiesCard: some View {
        let displayedStats = showAllActivities
            ? viewModel.activityStats
            : Array(viewModel.activityStats.prefix(5))

        return VStack(alignment: .leading, spacing: 0) {
            Text("Top Activities")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ForEach(displayedStats.indices, id: \.self) { i in
                let stat = displayedStats[i]
                HStack(spacing: 12) {
                    Text("\(i + 1)")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                        .padding(.leading, 8)

                    Circle()
                        .fill(stat.color)
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

                if i < displayedStats.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }

            if viewModel.activityStats.count > 5 {
                Divider()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showAllActivities.toggle()
                    }
                } label: {
                    HStack {
                        Text(showAllActivities ? "Show Less" : "Show All (\(viewModel.activityStats.count))")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                        Image(systemName: showAllActivities ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
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

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Data for \(String(viewModel.selectedYear))",
            systemImage: "calendar",
            description: Text("Start tracking activities to see your yearly summary.")
        )
        .padding(.top, 40)
    }

    // MARK: - Share

    private func prerenderShareCard() {
        cachedShareImage = nil
        cachedShareURL = nil
        Task { @MainActor in
            let card = YearShareCard(viewModel: viewModel)
            let renderer = ImageRenderer(content: card.frame(width: 360))
            renderer.scale = 3.0
            guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("year-in-review-\(viewModel.selectedYear).png")
            try? data.write(to: url)
            cachedShareImage = uiImage
            cachedShareURL = url
        }
    }
}

// MARK: - Share Card (rendered to image)

private struct YearShareCard: View {
    let viewModel: YearlyStatsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(viewModel.selectedYear) + " in Review")
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
            }

            // Pie chart + top activities side by side
            if !viewModel.activityStats.isEmpty {
                HStack(alignment: .top, spacing: 16) {
                    Chart(viewModel.activityStats) { stat in
                        SectorMark(
                            angle: .value("Duration", stat.totalDuration),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.2
                        )
                        .cornerRadius(3)
                        .foregroundStyle(stat.color)
                    }
                    .frame(width: 90, height: 90)
                    .chartLegend(.hidden)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Top Activities")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        ForEach(viewModel.activityStats.prefix(5)) { stat in
                            HStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(stat.color)
                                    .frame(width: 8, height: 8)
                                Text(stat.activity.name)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                Text(String(format: "%.0fh", stat.hours))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            // Top 3 longest streaks
            if !viewModel.activityStreaks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Longest Streaks")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.activityStreaks.prefix(3)) { streak in
                        HStack(spacing: 6) {
                            Text("🔥").font(.caption)
                            Circle()
                                .fill(streak.activity.color())
                                .frame(width: 8, height: 8)
                            Text(streak.activity.name).font(.caption).lineLimit(1)
                            Spacer()
                            Text("\(streak.longestStreak) days")
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
