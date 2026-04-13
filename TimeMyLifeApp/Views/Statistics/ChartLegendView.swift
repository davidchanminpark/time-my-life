import SwiftUI

struct ChartLegendView: View {
    let stats: [ActivityStat]
    var maxItems: Int = 7

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(stats.prefix(maxItems)) { stat in
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
            if stats.count > maxItems {
                Text("+\(stats.count - maxItems) more")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
