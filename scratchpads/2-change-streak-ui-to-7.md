# Issue #2: Change streak UI to 7

**Link**: https://github.com/davidchanminpark/time-my-life/issues/2

## Problem
Streak history shows 6 previous periods — should show 7 for a more intuitive display.

## Plan

### Files to touch
1. `TimeMyLifeApp/ViewModels/GoalsViewModel.swift` — change history from 6 → 7 periods
2. `TimeMyLifeApp/Views/Goals/GoalCardView.swift` — update preview data to 7 elements
3. `TimeMyLifeAppTests/Unit/ViewModels/GoalsViewModelTests.swift` — update tests for 7 elements

### Changes
1. **GoalsViewModel.swift**:
   - Line 22: Update comment "last 6 periods" → "last 7 periods"
   - Line 198: `while history.count < 6` → `< 7` (dailyHistory)
   - Line 238-240: `stride(from: 5, ...)` → `stride(from: 6, ...)` (weeklyStreakAndHistory)
   - Line 238: Update comment "last-6-weeks" → "last-7-weeks"

2. **GoalCardView.swift**:
   - Line 84: Add one more element to preview history array

3. **GoalsViewModelTests.swift**:
   - `testDailyHistory_alwaysSixElements` → rename + assert count == 7
   - `testDailyHistory_reflectsMetDays` → adjust for 7 elements (seed 6 days ago instead of 5)
   - `testWeeklyHistory_alwaysSixElements` → rename + assert count == 7

### TDD approach
- Update tests first to expect 7
- Then update implementation
- Run full test suite
