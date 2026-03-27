# Issue #5: Edit fields for activity specific stats

**Link:** https://github.com/davidchanminpark/time-my-life/issues/5

## Problem
Current ActivityStatsDetailView shows 30-day-only metrics that aren't very meaningful (e.g., "Days Tracked" isn't insightful). Need all-time stats, consistency %, goal success rate, longest streaks with date ranges, and a cumulative hours graph.

## Plan

### Step 1: Add cached fields to Activity model
Add to `Activity.swift`:
- `allTimeTotalSeconds: Double` (default 0)
- `longestDailyStreakCount: Int` (default 0)
- `longestDailyStreakStartDate: Date?`
- `longestDailyStreakEndDate: Date?`
- `longestWeeklyStreakCount: Int` (default 0)
- `longestWeeklyStreakStartDate: Date?`
- `longestWeeklyStreakEndDate: Date?`

Update Codable extension to encode/decode new fields (with backward compat via `decodeIfPresent`).

### Step 2: Update DataService to maintain cached fields
In `createOrUpdateTimeEntry()`:
- After saving, fetch the Activity and update `allTimeTotalSeconds += duration`

### Step 3: Add backfill method to DataService
Add `backfillActivityStats(for:)` that recalculates `allTimeTotalSeconds` from all time entries. Called on first load / migration.

### Step 4: Update GoalsViewModel to update longest streak on Activity
After calculating daily/weekly streaks in `buildGoalWithProgress()`:
- Compare computed streak with activity's `longestDailyStreakCount` / `longestWeeklyStreakCount`
- If current streak is longer, update the activity fields with count + date range

### Step 5: Rewrite ActivityStatsViewModel
New metrics:
- **Total Time** (all-time) — from `activity.allTimeTotalSeconds`
- **Daily Average** (all-time) — total / all tracked days count
- **Weekly Average** (all-time) — total / weeks since first entry
- **Consistency** — tracked days / scheduled days over last 30 days
- **Goal Success Rate** — goal met days / tracked days over last 30 days (only if daily goal exists)
- **Longest Daily Streak** — from activity cached fields (count + date range)
- **Longest Weekly Streak** — from activity cached fields (count + date range)

Keep 30-day trend chart. Add cumulative hours chart (all-time or 30-day cumulative).

### Step 6: Update ActivityStatsDetailView UI
- Replace old metric rows with new fields
- Add cumulative hours chart below daily trend chart
- Show streak date ranges (e.g., "5 days (Mar 1 – Mar 5)")
- Hide streak rows if count is 0

### Step 7: Write tests
Create `TimeMyLifeAppTests/Unit/ViewModels/ActivityStatsViewModelTests.swift`:
- Test all-time total, daily/weekly averages
- Test consistency calculation
- Test goal success rate
- Test longest streak caching on Activity
- Test cumulative trend data

Update existing GoalsViewModelTests if needed for streak-on-activity logic.

## Files to touch
- `TimeMyLifeApp/Models/Activity.swift` — new cached fields + Codable
- `TimeMyLifeApp/Services/DataService.swift` — update createOrUpdateTimeEntry, add backfill
- `TimeMyLifeApp/ViewModels/GoalsViewModel.swift` — update longest streak on activity
- `TimeMyLifeApp/ViewModels/ActivityStatsViewModel.swift` — rewrite metrics
- `TimeMyLifeApp/Views/Statistics/ActivityStatsDetailView.swift` — new UI
- `TimeMyLifeAppTests/Unit/ViewModels/ActivityStatsViewModelTests.swift` — new test file
