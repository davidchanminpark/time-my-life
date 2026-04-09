# Issue #1: Change daily goal streak to respect scheduled days

**Issue:** https://github.com/davidchanminpark/TimeMyLifeApp/issues/1

## Problem
Daily streak breaks on days the activity isn't even scheduled. E.g., "running" scheduled Mon/Tue/Thu — if user meets goal Mon+Tue, the streak should survive Wed (unscheduled) and count Thu as day 3 if met.

## Plan

### 1. Modify `GoalsViewModel.dailyStreakAndHistory`
- Accept `scheduledWeekdays: Set<Int>` parameter
- **Streak**: Skip non-scheduled days when walking backwards (don't break on them)
- **History**: Show last 6 *scheduled* days, not last 6 calendar days

### 2. Update `buildGoalWithProgress`
- Fetch the activity's `scheduledDayInts` and pass to `dailyStreakAndHistory`

### 3. Update tests in `TimeMyLifeAppTests.swift`
- Existing tests use all-days-scheduled activities → should still pass with same logic
- Add new test: activity scheduled specific days, streak survives unscheduled gaps
- Add new test: activity scheduled specific days, streak breaks on missed *scheduled* day

### Files to touch
- `TimeMyLifeApp/ViewModels/GoalsViewModel.swift` (lines ~87-167)
- `TimeMyLifeAppTests/TimeMyLifeAppTests.swift` (streak tests ~190-253)
