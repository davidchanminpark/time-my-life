# Issue #5: Edit fields for activity specific stats

**Link:** https://github.com/davidchanminpark/time-my-life/issues/5

## Problem
Current implementation caches stats on Activity model and updates incrementally. This is complex, stale for sample data, and makes future time entry editing difficult. Stats should be year-scoped and computed on the fly.

**PR comment:** Daily average should divide by all calendar days, not tracked days.

## Plan: Year-scoped stats & remove cached fields

### Step 1: Rewrite `ActivityStatsViewModel.loadStats()` — year-scoped
Fetch entries for `activity.id` from Jan 1 of current year to today. Compute in one pass:
- **Total Time**: sum of durations
- **Daily Average**: total / calendar days elapsed in year
- **Weekly Average**: total / (days elapsed / 7.0)
- **Consistency (30d)**: tracked days / scheduled days (unchanged, but capped to yearStart if in January)
- **Goal Success Rate (30d)**: met days / tracked days (unchanged, capped to yearStart)
- **Longest Daily Streak**: walk Jan 1→today, consecutive scheduled days meeting daily goal. Only if daily goal exists.
- **Longest Weekly Streak**: group by week, scan chronologically. Only if weekly goal exists.
- Add private `weekStart(for:cal:)` helper
- Edge case: Jan 1-29, 30d window → clamp to yearStart (don't look at previous year)

**File:** `TimeMyLifeApp/ViewModels/ActivityStatsViewModel.swift`

### Step 2: Simplify `GoalsViewModel` — remove peak tracking & Activity updates
- `updateDailyStreak()`: return `Void`, remove peak tracking vars
- `weeklyStreakAndHistory()`: return `(streak: Int, history: [Bool])`, remove peak scan + `streakEndWeekStart`
- `buildGoalWithProgress()`: remove bestCount/bestStart/bestEnd logic and `updateLongestDailyStreak`/`updateLongestWeeklyStreak` calls
- Delete `updateLongestDailyStreak()`, `updateLongestWeeklyStreak()`, `walkBackScheduledDays()`

**File:** `TimeMyLifeApp/ViewModels/GoalsViewModel.swift`

### Step 3: Clean up `DataService`
- `createOrUpdateTimeEntry()`: remove `allTimeTotalSeconds` increment block
- Delete `backfillAllActivityStats()`
- `handleActivitySync()`: remove 7 cached stat field assignments

**File:** `TimeMyLifeApp/Services/DataService.swift`

### Step 4: Remove cached fields from `Activity` model
- Delete 7 properties: `allTimeTotalSeconds`, `longestDaily/WeeklyStreakCount/StartDate/EndDate`
- Update `CodingKeys`, `encode(to:)`, `init(from:)` to remove these fields

**File:** `TimeMyLifeApp/Models/Activity.swift`

### Step 5: Update `ActivityStatsDetailView`
- Header: `"All-time statistics"` → dynamic `"2026 statistics"`
- Recent entries: scoped to current year

**File:** `TimeMyLifeApp/Views/Statistics/ActivityStatsDetailView.swift`

### Step 6: Update tests
**Delete:** cached field tests (allTimeTotalSeconds increments, GoalsVM-updating-Activity streaks, backfill)

**Update:** totalDuration (year-scoped), dailyAverage (÷ calendar days), weeklyAverage (÷ weeks elapsed)

**Add:**
- `test_totalDuration_scopedToCurrentYear` — previous year entries excluded
- `test_longestDailyStreak_computedFromYearEntries`
- `test_longestDailyStreak_zeroWhenNoDailyGoal`
- `test_longestWeeklyStreak_computedFromYearEntries`
- `test_longestDailyStreak_findsHistoricalBest` — past streak > current streak

**File:** `TimeMyLifeAppTests/Unit/ViewModels/ActivityStatsViewModelTests.swift`

### Step 7: Grep for stale references
Search for `allTimeTotalSeconds`, `longestDailyStreakCount`, `backfillAllActivityStats`, `updateLongestDailyStreak`, `walkBackScheduledDays` — should all be zero hits.

## Verification
1. Build iOS target
2. Run full test suite
3. Run GoalsViewModelTests specifically to verify streak display still works
4. Grep for removed field names

## Files to touch
- `TimeMyLifeApp/Models/Activity.swift` — remove cached fields + Codable cleanup
- `TimeMyLifeApp/Services/DataService.swift` — remove incremental updates + backfill
- `TimeMyLifeApp/ViewModels/GoalsViewModel.swift` — simplify streak tracking
- `TimeMyLifeApp/ViewModels/ActivityStatsViewModel.swift` — rewrite year-scoped
- `TimeMyLifeApp/Views/Statistics/ActivityStatsDetailView.swift` — header text
- `TimeMyLifeAppTests/Unit/ViewModels/ActivityStatsViewModelTests.swift` — update tests
