# Issue #7: Monthly/weekly hours bar chart in activity stats view

**Link:** https://github.com/davidchanminpark/time-my-life/issues/7

## Problem
Users need a longer-range view showing productive vs slow periods. The existing daily trend only covers 30 days.

## Behavior
- **Default**: Show last 12 months as bars (one bar per month)
- **Fallback**: If fewer than 3 months of data exist (activity created recently), show last 12 weeks instead
- "Months of data" = months between yearStart and today (inclusive). Jan–Mar = 3 months, so the fallback kicks in only for Jan–Feb.

## Plan

### Step 1: Replace cumulative data with monthly/weekly bar data in ViewModel
- Replace `cumulativeData: [TrendPoint]` with `periodBarData: [TrendPoint]`
- Add `periodBarUsesWeeks: Bool` to indicate which mode is active
- Compute from already-fetched `yearNonZero`:
  - Count months from yearStart to today. If >= 3, group by month start → one bar per month (last 12 months)
  - If < 3, group by week start → one bar per week (last 12 weeks)
  - Include zero-value periods so chart has no gaps
- Replace cumulative Y-axis computed properties with period bar ones (use `.weekly` period kind for both since totals can be large)

**File:** `TimeMyLifeApp/ViewModels/ActivityStatsViewModel.swift`

### Step 2: Replace cumulative chart with bar chart in View
- Replace `cumulativeCard` with `periodBarCard`
- Use `BarMark` with activity color
- Title: "Monthly Hours" or "Weekly Hours" based on `periodBarUsesWeeks`
- X-axis: month labels (monthly mode) or week-start dates (weekly mode)
- Y-axis: `StatsChartYAxis` with `.weekly` period

**File:** `TimeMyLifeApp/Views/Statistics/ActivityStatsDetailView.swift`

### Step 3: Update tests
- Replace cumulative tests with:
  - `test_periodBarData_groupsByMonth` — entries in same month summed, shown as monthly bars
  - `test_periodBarData_fallsBackToWeeksWhenLessThan3Months` — early in year shows weekly bars
  - `test_periodBarData_emptyWhenNoEntries`

**File:** `TimeMyLifeAppTests/Unit/ViewModels/ActivityStatsViewModelTests.swift`

## Files to touch
- `TimeMyLifeApp/ViewModels/ActivityStatsViewModel.swift`
- `TimeMyLifeApp/Views/Statistics/ActivityStatsDetailView.swift`
- `TimeMyLifeAppTests/Unit/ViewModels/ActivityStatsViewModelTests.swift`
