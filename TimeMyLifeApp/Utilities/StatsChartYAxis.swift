//
//  StatsChartYAxis.swift
//  TimeMyLifeApp
//

import Foundation

/// Shared Y-axis tick positions and labels for statistics charts. Chart **Y values are in hours**.
enum StatsChartYAxis {

    enum PeriodKind {
        /// Per-day buckets (stacked daily bars, 30-day trend, etc.).
        case daily
        /// Per-week buckets (weekly stacked bars).
        case weekly
    }

    /// Use `Xm` labels instead of `Nh` when the peak is under 2 hours (daily-style charts only).
    static func useMinuteLabels(maxHours: Double, period: PeriodKind) -> Bool {
        period == .daily && maxHours > 0 && maxHours < 2
    }

    /// Explicit tick positions in **hours** so Swift Charts doesn’t emit marks that round to duplicate labels.
    static func yTickHours(maxHours: Double, period: PeriodKind, hasData: Bool) -> [Double] {
        guard hasData else { return [0, 1] }

        let maxH = max(maxHours, 1.0 / 120.0)

        if useMinuteLabels(maxHours: maxHours, period: period) {
            let maxMin = max(1, Int(ceil(maxH * 60 - 1e-9)))
            let step = niceMinuteStep(upperBoundMinutes: maxMin)
            var minutes: [Int] = []
            var m = 0
            while m <= maxMin {
                minutes.append(m)
                m += step
            }
            if minutes.last != maxMin {
                minutes.append(maxMin)
            }
            return minutes.map { Double($0) / 60.0 }
        }

        if period == .daily {
            let top = max(1, Int(ceil(maxH)))
            return (0...top).map { Double($0) }
        }

        let top = max(1, Int(ceil(maxH)))
        if top <= 10 {
            return (0...top).map { Double($0) }
        }
        let hourStep = max(1, top / 5)
        var hours: [Double] = [0]
        var h = hourStep
        while h <= top {
            hours.append(Double(h))
            h += hourStep
        }
        return hours
    }

    static func yAxisLabel(hours: Double, useMinuteLabels: Bool) -> String {
        if useMinuteLabels {
            let m = Int(round(hours * 60))
            return "\(m)m"
        }
        return String(format: "%.0fh", hours)
    }

    private static func niceMinuteStep(upperBoundMinutes maxMin: Int) -> Int {
        if maxMin <= 10 { return 1 }
        if maxMin <= 30 { return 5 }
        if maxMin <= 60 { return 10 }
        if maxMin <= 90 { return 15 }
        return 20
    }
}
