import SwiftUI
import Charts

struct YearShareCard: View {
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
