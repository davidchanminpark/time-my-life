# Issue #9: Create weekday breakdown bar chart for yearly stats page

**Link:** https://github.com/davidchanminpark/time-my-life/issues/9

## Summary
Add a stacked bar chart to the yearly stats page showing average hours per weekday, broken down by activity. This shows which days users are most productive and which activities dominate each day.

## Plan

### Step 1: Add weekday bar data to ViewModel
**File:** `TimeMyLifeApp/ViewModels/YearlyStatsViewModel.swift`

Add:
- `WeekdayBarSegment` struct: `weekday: Int` (1-7), `activityID: UUID`, `averageHours: Double`, `color: Color`, `stackOrder: Int`
- `weekdayBarSegments: [WeekdayBarSegment]` state
- `maxWeekdayBarHours: Double` computed property (max stacked total per weekday)
- `buildWeekdayBreakdown()` method: group entries by weekday + activity, count weeks per weekday in the year, compute averages, produce stacked segments matching activityStats order

### Step 2: Add bar chart card to View
**File:** `TimeMyLifeApp/Views/Statistics/YearlyStatsView.swift`

Add `weekdayBreakdownCard` — stacked BarMark per weekday (Sun-Sat), same style as StatsView's bar chart. Place between pie chart and top activities.

### Step 3: Add test
**File:** `TimeMyLifeAppTests/Unit/ViewModels/YearlyStatsViewModelTests.swift`

Add `testWeekdayBreakdown_calculatesAverageHours` — seed entries on known weekdays, verify segments have correct average hours.

## Files Touched
- `TimeMyLifeApp/ViewModels/YearlyStatsViewModel.swift`
- `TimeMyLifeApp/Views/Statistics/YearlyStatsView.swift`
- `TimeMyLifeAppTests/Unit/ViewModels/YearlyStatsViewModelTests.swift`
