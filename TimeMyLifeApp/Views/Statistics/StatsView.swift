//
//  StatsView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    let dataService: DataService

    @State private var viewModel: StatsViewModel

    init(dataService: DataService) {
        self.dataService = dataService
        _viewModel = State(wrappedValue: StatsViewModel(dataService: dataService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    mainContent
                }
            }
            .foregroundStyle(Color.appPrimaryText)
            .task { await viewModel.loadStats() }
        }
    }

    // MARK: - Layout

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text("Statistics")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.appPrimaryText)
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 10)

                periodPicker
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                if viewModel.activityStats.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 16) {
                        summaryCard
                        pieChartCard
                        barChartCard
                        activityListCard
                        additionalViewsCard
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 110)
                }
            }
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $viewModel.selectedPeriod) {
            ForEach(StatsViewModel.TimePeriod.allCases) { period in
                Text(period.label).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? .tertiarySystemFill
                    : UIColor(red: 1.0, green: 0.973, blue: 0.941, alpha: 1)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryItem(value: String(format: "%.1fh", viewModel.totalHours), label: "Total")
            Divider().frame(height: 36)
            summaryItem(value: "\(viewModel.trackedDays)", label: "Days Active")
            Divider().frame(height: 36)
            summaryItem(value: "\(viewModel.activityStats.count)", label: "Activities")
        }
        .padding(.vertical, 14)
        .appCard()
    }

    private func summaryItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
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

                ChartLegendView(stats: viewModel.activityStats)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .appCard()
    }

    // MARK: - Bar Chart

    private var barChartCard: some View {
        let isWeekly = viewModel.selectedPeriod.useWeeklyBars
        let title = isWeekly ? "Weekly Totals" : "Daily Totals"
        let unit: Calendar.Component = isWeekly ? .weekOfYear : .day
        let axisFormat: Date.FormatStyle = isWeekly
            ? .dateTime.month(.abbreviated).day()
            : .dateTime.weekday(.abbreviated)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Chart(viewModel.stackedBarSegments) { seg in
                BarMark(
                    x: .value("Period", seg.periodStart, unit: unit),
                    y: .value("Hours", seg.hours)
                )
                .foregroundStyle(seg.color)
                .cornerRadius(2)
            }
            .chartLegend(.hidden)
            .chartXAxis {
                if isWeekly {
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: axisFormat)
                    }
                } else {
                    AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: axisFormat)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: viewModel.barChartYAxisTickHours) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = value.as(Double.self) {
                            Text(StatsChartYAxis.yAxisLabel(
                                hours: h,
                                useMinuteLabels: viewModel.useMinuteAxisForDailyBarChart
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
                    ForEach(viewModel.activityStats) { stat in
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

    // MARK: - Activity List

    private var activityListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Breakdown")
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            ForEach(viewModel.activityStats.indices, id: \.self) { index in
                let stat = viewModel.activityStats[index]
                NavigationLink {
                    ActivityStatsDetailView(
                        activity: stat.activity,
                        dataService: dataService
                    )
                } label: {
                    activityRow(stat: stat, rank: index + 1)
                }
                .buttonStyle(.plain)

                if index < viewModel.activityStats.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }

            Spacer(minLength: 8)
        }
        .appCard()
    }

    private func activityRow(stat: ActivityStat, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)
                .padding(.leading, 12)

            Circle()
                .fill(stat.color)
                .frame(width: 11, height: 11)

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.activity.name)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                if !stat.activity.category.isEmpty {
                    Text(stat.activity.category)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatHours(stat.totalDuration))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                Text(String(format: "%.0f%%", stat.percentage * 100))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.trailing, 4)

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    // MARK: - Additional Views Card

    private var additionalViewsCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                CalendarView(dataService: dataService)
            } label: {
                additionalRow(icon: "calendar", label: "Calendar", subtitle: "View activity by day")
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            NavigationLink {
                YearlyStatsView(dataService: dataService)
            } label: {
                additionalRow(icon: "chart.bar.doc.horizontal", label: "Year in Review", subtitle: "Yearly summary & streaks")
            }
            .buttonStyle(.plain)
        }
        .appCard()
    }

    private func additionalRow(icon: String, label: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.appAccent)
                .frame(width: 36, height: 36)
                .background(Color.appAccent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.leading, 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Data",
            systemImage: "chart.bar.fill",
            description: Text("Start tracking activities to see statistics here.")
        )
        .padding(.top, 60)
    }

    // MARK: - Helpers

    private func formatHours(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}

#Preview {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    StatsView(dataService: dataService)
        .modelContainer(container)
}

#Preview("Empty") {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies(seedSample: false)
    StatsView(dataService: dataService)
        .modelContainer(container)
}
