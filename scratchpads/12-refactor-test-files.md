# Issue #12 — Refactor test files

**Link:** https://github.com/davidchanminpark/time-my-life/issues/12

## Problem
All tests live in 2 flat files (`TimeMyLifeAppTests.swift`, `PerformanceTests.swift`). Convention requires one file per ViewModel/Service under `TimeMyLifeAppTests/Unit/`.

## Plan

### Step 1: Create directory structure
```
TimeMyLifeAppTests/
├── Helpers/
│   └── TestHelpers.swift          # shared makeTestDependencies()
├── Unit/
│   ├── Services/
│   │   └── DataServiceTests.swift
│   └── ViewModels/
│       ├── GoalsViewModelTests.swift    # was GoalProgressTests class
│       └── YearlyStatsViewModelTests.swift  # was YearlyStatsTests class
└── Performance/
    └── PerformanceTests.swift
```

### Step 2: Extract shared helper
Move `makeTestDependencies()` to `Helpers/TestHelpers.swift` (make it `internal` instead of `private`).

### Step 3: Split TimeMyLifeAppTests.swift into 3 files
- `DataServiceTests` class → `Unit/Services/DataServiceTests.swift`
- `GoalProgressTests` class → `Unit/ViewModels/GoalsViewModelTests.swift` (rename class to `GoalsViewModelTests`)
- `YearlyStatsTests` class → `Unit/ViewModels/YearlyStatsViewModelTests.swift` (rename class to `YearlyStatsViewModelTests`)

### Step 4: Move PerformanceTests.swift
Move to `Performance/PerformanceTests.swift`. Update its setup to use shared `makeTestDependencies()`.

### Step 5: Delete original files
Remove `TimeMyLifeAppTests.swift` and root `PerformanceTests.swift`.

### Step 6: Update PerformanceTests setup
Replace inline setup with shared `makeTestDependencies()`.

## Files touched
- **Delete:** `TimeMyLifeAppTests/TimeMyLifeAppTests.swift`, `TimeMyLifeAppTests/PerformanceTests.swift`
- **Create:** `TestHelpers.swift`, `DataServiceTests.swift`, `GoalsViewModelTests.swift`, `YearlyStatsViewModelTests.swift`, `Performance/PerformanceTests.swift`

## What does NOT change
- Test method bodies / assertions (per issue requirement)
- Test logic / seed helpers within each class
