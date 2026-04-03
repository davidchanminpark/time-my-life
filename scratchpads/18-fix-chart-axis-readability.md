# Issue #18: Fix x and y axis of graphs

**Link:** https://github.com/davidchanminpark/time-my-life/issues/18

## Problem
X and Y axis values are squished on several chart views, hurting readability. Issue 7 previously fixed this for the Monthly Trend chart by introducing `StatsChartYAxis` and using stride-based X-axis marks with every-2nd-label spacing.

## Charts to fix

### 1. StatsView — barChartCard (stacked bar chart)
- **X-axis**: Currently uses `.automatic` values. For 7-day (daily) bars, 7 labels are tight. For 30/60/90-day (weekly) bars, many week labels will squish.
- **Fix**: Use stride-based marks — daily: every 2 days; weekly: every 2 weeks. Format: weekday abbrev (daily) or month+day (weekly).

### 2. YearlyStatsView — weekdayBreakdownCard
- **Y-axis**: Uses default `AxisMarks` (auto ticks) instead of `StatsChartYAxis`. Can produce overlapping tick labels.
- **Fix**: Add Y-axis tick helpers to `YearlyStatsViewModel` using `StatsChartYAxis`, then use explicit tick values in the chart view.

## Files to touch
- `TimeMyLifeApp/Views/Statistics/StatsView.swift` — fix bar chart X-axis stride
- `TimeMyLifeApp/Views/Statistics/YearlyStatsView.swift` — fix weekday breakdown Y-axis
- `TimeMyLifeApp/ViewModels/YearlyStatsViewModel.swift` — add Y-axis tick helpers
