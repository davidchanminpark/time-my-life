# Issue #3: Add Large Dataset into Simulator

**Link:** https://github.com/davidchanminpark/time-my-life/issues/3

## Problem
Need a way to populate the simulator with a year's worth of realistic activity data to test UI rendering and performance (especially stats pages).

## Plan

### Step 1: Add `seedYearOfData` to `SampleData.swift`
- Create a method that generates ~10 realistic activities with a full year (365 days) of time entries
- Include goals for some activities
- Use realistic activity names/categories/colors (not "Activity 1")
- Use varying durations to create interesting stats patterns (weekday vs weekend, some gaps)
- Use bulk insert (direct ModelContext insert + single save) like PerformanceTests for speed

### Step 2: Add DEBUG-only "Populate Sample Data" button in `SettingsView.swift`
- Add a new section visible only in `#if DEBUG` builds
- "Load Year of Sample Data" button with confirmation alert
- Shows a progress indicator while seeding
- Calls `SampleData.seedYearOfData(in:)` on the DataService's modelContext

### Step 3: Support launch argument for auto-seeding
- In `TimeMyLifeAppApp.swift`, check for `-seedLargeDataset` launch argument
- If present and DB is empty, auto-seed on first launch
- This allows setting up Xcode scheme for quick testing

### Step 4: Test
- Run the app in simulator, trigger the seed
- Navigate through Stats, Calendar, YearlyStats views
- Verify data renders correctly and performance is acceptable

## Files to Touch
- `TimeMyLifeApp/Utilities/Helpers/SampleData.swift` — add `seedYearOfData`
- `TimeMyLifeApp/Views/Settings/SettingsView.swift` — add DEBUG section
- `TimeMyLifeApp/TimeMyLifeAppApp.swift` — add launch argument support
