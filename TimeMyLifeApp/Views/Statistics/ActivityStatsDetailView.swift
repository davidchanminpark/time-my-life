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
                        trendsCard
                        recentSessionsCard
                    } else {
                        ContentUnavailableView(
                            "No Data",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: Text("No sessions tracked in the last 30 days.")
                        )
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle(activity.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadStats() }
    }

    // MARK: - Header

    private var headerCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13)
                    .fill(
                        activity.emoji.isEmpty
                            ? activity.color()
                            : activity.color().opacity(0.18)
                    )
                    .frame(width: 48, height: 48)
                if activity.emoji.isEmpty {
                    Text(String(activity.name.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.18))
                } else {
                    Text(activity.emoji)
                        .font(.system(size: 24))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.name)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                if !activity.category.isEmpty {
                    Text(activity.category)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text("Last 30 days")
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

            metricRow(label: "Total Time", value: formatDuration(metrics.totalDuration))
            Divider().padding(.leading, 16)
            metricRow(label: "Daily Average", value: formatDuration(metrics.dailyAverage))
            Divider().padding(.leading, 16)
            metricRow(label: "Weekly Average", value: formatDuration(metrics.weeklyAverage))
            Divider().padding(.leading, 16)
            metricRow(label: "Longest Session", value: formatDuration(metrics.longestSession))
            Divider().padding(.leading, 16)
            metricRow(label: "Shortest Session", value: formatDuration(metrics.shortestSession))
            Divider().padding(.leading, 16)
            metricRow(label: "Days Tracked", value: "\(metrics.trackedDays) / 30")

            if let pct = metrics.goalCompletionPct {
                Divider().padding(.leading, 16)
                metricRow(
                    label: "Goal Completion",
                    value: String(format: "%.0f%%", pct * 100),
                    valueColor: pct >= 0.8 ? .green : pct >= 0.5 ? .orange : .red
                )
            }

            Spacer(minLength: 12)
        }
        .appCard()
    }

    private func metricRow(label: String, value: String, valueColor: Color = .primary) -> some View {
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
                        Text(formatDuration(entry.totalDuration))
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

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        if m > 0 { return "\(m)m" }
        return "—"
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
