# Issue #8: Edit fields for yearly stats page

**Link:** https://github.com/davidchanminpark/TimeMyLifeApp/issues/8

## Summary
Replace unnecessary stats (best day, most active day, monthly activity heatmap) with meaningful ones:
1. **Pie chart** showing time distribution for the entire year (same donut style as StatsView)
2. **Cumulative hours line chart** overlaying all activities across the year
3. Remove: `mostActiveDay`, monthly heatmap, `ActivityStreak`/streaks card

## Plan

### Step 1: Update ViewModel — remove old fields, add new data structures
**File:** `TimeMyLifeApp/ViewModels/YearlyStatsViewModel.swift`

Remove:
- `mostActiveDay` property
- `monthlyTotals` array + `maxMonthlyHours`
- `dailyTotals` computation

Keep:
- `ActivityStreak` struct + `activityStreaks` array + `longestStreak()` helper
- `entriesByActivity` (needed for streaks)

Add:
- `ActivityStat` struct (same shape as `StatsViewModel.ActivityStat`: id, activity, totalDuration, percentage, color, hours)
- `activityStats: [ActivityStat]` — all activities with yearly totals, sorted by duration desc (for pie chart + legend)
- `CumulativePoint` struct: `date: Date, activityID: UUID, hours: Double, color: Color, activityName: String`
- `cumulativeData: [CumulativePoint]` — daily cumulative hours per activity across the year (for line chart)

Keep:
- `totalHours`, `activitiesCount`, `topActivities` (used in share card)
- `selectedYear`, `availableYears`, `isLoading`
- Year loading/validation logic

### Step 2: Update View — replace cards
**File:** `TimeMyLifeApp/Views/Statistics/YearlyStatsView.swift`

Remove:
- `streaksCard`
- `heatmapCard`
- `mostActiveDay` display in heroCard

Add:
- `pieChartCard` — donut chart + legend (reuse same pattern from StatsView)
- `cumulativeChartCard` — LineMark overlaying cumulative hours per activity

Update:
- `heroCard` — keep Total Hours + Activities, remove Best Day
- `YearShareCard` — remove Best Streak, keep Total Hours / Activities / top activities

### Step 3: Update Tests
**File:** `TimeMyLifeAppTests/Unit/ViewModels/YearlyStatsViewModelTests.swift`

Remove:
- `testMostActiveDay_identifiedCorrectly`
- `testLongestStreak_singleConsecutiveRun`
- `testLongestStreak_picksLongestRun`

Add:
- `testActivityStats_calculatesPercentages` — verify percentage sums to ~1.0
- `testActivityStats_sortedByDuration` — verify descending order
- `testCumulativeData_accumulatesCorrectly` — verify cumulative hours grow over days

Update:
- `testEmptyYear_showsZeros` — remove streak/mostActiveDay assertions, add activityStats.isEmpty

## Files Touched
- `TimeMyLifeApp/ViewModels/YearlyStatsViewModel.swift`
- `TimeMyLifeApp/Views/Statistics/YearlyStatsView.swift`
- `TimeMyLifeAppTests/Unit/ViewModels/YearlyStatsViewModelTests.swift`
