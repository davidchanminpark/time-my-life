//
//  ActivityStatsDetailView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import Charts

struct ActivityStatsDetailView: View {
    let activity: Activity
    let dataService: DataService

    @State private var viewModel: ActivityStatsViewModel

    init(activity: Activity, dataService: DataService) {
        self.activity = activity
        self.dataService = dataService
        _viewModel = State(wrappedValue: ActivityStatsViewModel(activity: activity, dataService: dataService))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.isLoading {
                        ProgressView().padding(.top, 60)
                    } else if let metrics = viewModel.metrics {
                        headerCard
                        metricsCard(metrics: metrics)
                        streaksCard(metrics: metrics)
                        trendsCard
                        periodBarCard
                        recentSessionsCard
                    } else {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("No sessions tracked yet.")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 110)
            }
        }
        .foregroundStyle(Color.appPrimaryText)
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadStats() }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ActivityAvatarView(activity: activity)

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.name)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                if !activity.category.isEmpty {
                    Text(activity.category)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: "\(Calendar.current.component(.year, from: Date())) statistics")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(16)
        .appCard()
    }

    // MARK: - Metrics

    private func metricsCard(metrics: ActivityStatsViewModel.Metrics) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Key Metrics")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            metricRow(label: "Total Time", value: metrics.totalDuration.formattedDuration(style: .compactNoSeconds))
            Divider().padding(.leading, 16)
            metricRow(label: "Daily Average", value: metrics.dailyAverage.formattedDuration(style: .compactNoSeconds))
            Divider().padding(.leading, 16)
            metricRow(label: "Weekly Average", value: metrics.weeklyAverage.formattedDuration(style: .compactNoSeconds))
            Divider().padding(.leading, 16)
            metricRow(
                label: "Consistency (30d)",
                value: String(format: "%.0f%%", metrics.consistency * 100),
                valueColor: metrics.consistency >= 0.8 ? .green : metrics.consistency >= 0.5 ? .orange : .red
            )

            if let rate = metrics.goalSuccessRate {
                Divider().padding(.leading, 16)
                metricRow(
                    label: "Goal Success Rate (30d)",
                    value: String(format: "%.0f%%", rate * 100),
                    valueColor: rate >= 0.8 ? .green : rate >= 0.5 ? .orange : .red
                )
            }

            Spacer(minLength: 12)
        }
        .appCard()
    }

    // MARK: - Streaks

    private func streaksCard(metrics: ActivityStatsViewModel.Metrics) -> some View {
        let hasDaily = metrics.longestDailyStreakCount > 0
        let hasWeekly = metrics.longestWeeklyStreakCount > 0

        return Group {
            if hasDaily || hasWeekly {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Longest Streaks")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    Divider()

                    if hasDaily {
                        streakRow(
                            label: "Daily",
                            count: metrics.longestDailyStreakCount,
                            startDate: metrics.longestDailyStreakStartDate,
                            endDate: metrics.longestDailyStreakEndDate,
                            unit: "day"
                        )
                    }

                    if hasDaily && hasWeekly {
                        Divider().padding(.leading, 16)
                    }

                    if hasWeekly {
                        streakRow(
                            label: "Weekly",
                            count: metrics.longestWeeklyStreakCount,
                            startDate: metrics.longestWeeklyStreakStartDate,
                            endDate: metrics.longestWeeklyStreakEndDate,
                            unit: "week"
                        )
                    }

                    Spacer(minLength: 12)
                }
                .appCard()
            }
        }
    }

    private func streakRow(label: String, count: Int, startDate: Date?, endDate: Date?, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(count) \(count == 1 ? unit : unit + "s")")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
            }

            if let start = startDate, let end = endDate {
                Text(formatDateRange(start: start, end: end))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func metricRow(label: String, value: String, valueColor: Color = Color.appPrimaryText) -> some View {
        HStack {
            Text(label)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Trend Chart

    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Trend")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if viewModel.trendData.isEmpty {
                Text("No data")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                Chart(viewModel.trendData) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Hours", point.hours)
                    )
                    .foregroundStyle(activity.color())
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Hours", point.hours)
                    )
                    .foregroundStyle(activity.color().opacity(0.12))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: viewModel.trendChartYAxisTickHours) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let h = value.as(Double.self) {
                                Text(StatsChartYAxis.yAxisLabel(
                                    hours: h,
                                    useMinuteLabels: viewModel.trendChartUseMinuteYAxis
                                ))
                                .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .appCard()
    }

    // MARK: - Period Bar Chart

    private var periodBarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.periodBarUsesWeeks ? "Weekly Trend" : "Monthly Trend")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if viewModel.periodBarData.isEmpty {
                Text("No data")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                Chart(viewModel.periodBarData) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: viewModel.periodBarUsesWeeks ? .weekOfYear : .month),
                        y: .value("Hours", point.hours)
                    )
                    .foregroundStyle(activity.color())
                    .cornerRadius(4)
                }
                .chartXAxis {
                    if viewModel.periodBarUsesWeeks {
                        AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    } else {
                        AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: viewModel.periodBarChartYAxisTickHours) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let h = value.as(Double.self) {
                                Text(StatsChartYAxis.yAxisLabel(
                                    hours: h,
                                    useMinuteLabels: viewModel.periodBarChartUseMinuteYAxis
                                ))
                                .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 160)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .appCard()
    }

    // MARK: - Recent Sessions

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Recent Sessions")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if viewModel.recentEntries.isEmpty {
                Text("No sessions yet")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            } else {
                Divider()
                ForEach(viewModel.recentEntries) { entry in
                    HStack {
                        Text(entry.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(entry.totalDuration.formattedDuration(style: .compactNoSeconds))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)

                    if entry.id != viewModel.recentEntries.last?.id {
                        Divider().padding(.leading, 16)
                    }
                }
                Spacer(minLength: 8)
            }
        }
        .appCard()
    }

    // MARK: - Helpers

    private func formatDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)
        if startStr == endStr { return startStr }
        return "\(startStr) – \(endStr)"
    }
}

#Preview {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    let activity = IOSViewPreviewSupport.firstActivity(in: container.mainContext)
        ?? (try! Activity.validated(name: "Activity", colorHex: "#BFC8FF", category: "Cat", scheduledDays: [2]))
    NavigationStack {
        ActivityStatsDetailView(activity: activity, dataService: dataService)
    }
    .modelContainer(container)
}
