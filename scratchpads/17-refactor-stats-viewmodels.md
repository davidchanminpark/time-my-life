# Issue #17: Refactor yearly stats, activity stats, stats view models

**Issue**: https://github.com/davidchanminpark/time-my-life/issues/17

## Problem

The three stats view models share duplicated code:

1. **`ActivityStat` struct** — identical in `StatsViewModel` and `YearlyStatsViewModel` (id, activity, totalDuration, percentage, color, hours)
2. **`weekStart(for:)` helper** — duplicated in `StatsViewModel` and `ActivityStatsViewModel` (same logic, slightly different param names)
3. **Activity totals aggregation** — same pattern in `StatsViewModel.loadStats()` and `YearlyStatsViewModel.loadYear()`: iterate entries → build `[UUID: TimeInterval]` → compute grandTotal → build sorted `[ActivityStat]`

## Plan

### Step 1: Extract shared types to `StatsShared.swift`

Create `TimeMyLifeApp/Utilities/StatsShared.swift` with:

- **`ActivityStat`** struct (currently duplicated in StatsViewModel + YearlyStatsViewModel)
- **`weekStart(for:calendar:)`** free function (currently duplicated in StatsViewModel + ActivityStatsViewModel)
- **`buildActivityStats(from:activities:)`** static helper that takes `[TimeEntry]` + `[Activity]` and returns `(stats: [ActivityStat], totalHours: Double, trackedDays: Int)` — the shared aggregation logic

### Step 2: Update `StatsViewModel` to use shared code

- Remove nested `ActivityStat` type, use shared one
- Remove `weekStart` helper, use shared function
- Replace aggregation logic in `loadStats()` with `buildActivityStats()`

### Step 3: Update `YearlyStatsViewModel` to use shared code

- Remove nested `ActivityStat` type, use shared one
- Replace aggregation logic in `loadYear()` with `buildActivityStats()`

### Step 4: Update `ActivityStatsViewModel` to use shared code

- Remove `weekStart` helper, use shared function

### Step 5: Update views that reference namespaced types

- `StatsView.swift` line 265: `StatsViewModel.ActivityStat` → `ActivityStat`

### Step 6: Update and run tests

- Existing tests should pass unchanged (public API stays the same)
- Add unit tests for the shared helpers in a new `StatsSharedTests.swift`

## Files to touch

- `TimeMyLifeApp/Utilities/StatsShared.swift` (NEW)
- `TimeMyLifeApp/ViewModels/StatsViewModel.swift`
- `TimeMyLifeApp/ViewModels/YearlyStatsViewModel.swift`
- `TimeMyLifeApp/ViewModels/ActivityStatsViewModel.swift`
- `TimeMyLifeApp/Views/Statistics/StatsView.swift` (type reference)
- `TimeMyLifeAppTests/Unit/Utilities/StatsSharedTests.swift` (NEW)

## What does NOT change

- All existing functionality, graphs, and stats remain identical
- All existing tests continue to pass
