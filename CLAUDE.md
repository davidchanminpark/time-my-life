# Time My Life - watchOS Time Tracking App

## Overview
watchOS app for quantifying life activities. Track time spent on daily activities, filtered by weekday schedules.

## Status
- **Current Phase**: Phase 7 (Testing) - completed through plan.md
- **Platform**: watchOS 10.0+, iOS companion
- **Architecture**: SwiftUI + SwiftData

## Tech Stack
- SwiftUI for all UI
- SwiftData for local persistence
- WKExtendedRuntimeSession for background timers
- Shared codebase (iOS + watchOS targets)

## Core Features
- **Activity Management**: Create up to 30 activities with colors, categories, weekday schedules
- **Time Tracking**: Single active timer, accumulates duration per day
- **Background Support**: Timers continue when app backgrounded
- **Daily View**: Shows only activities scheduled for current weekday

## Data Models
### Activity
- Name, color, category, scheduled days (1=Sun...7=Sat)
- Max 30 activities, ~25 char names
- Validation enforced at creation

### TimeEntry
- One per activity per day
- Accumulates multiple timer sessions
- Duration stored in seconds

### ActiveTimer
- Singleton pattern
- Tracks current running timer
- Persists across app restarts

## Architecture

### Service Layer
- **DataService**: All SwiftData CRUD operations
- **TimerService**: Timer state management, start/stop/resume logic

### ViewModels (MVVM)
- MainViewModel, ActivityFormViewModel, SettingsViewModel, TimerViewModel, CRUDTestViewModel
- Platform-agnostic business logic
- Shared between iOS and watchOS

### Views
- **MainView**: Activity list filtered by current weekday
- **ActivityTimerView**: Timer UI with start/stop
- **ActivityFormView**: Create/edit activities
- **SettingsView**: Manage all activities
- **CRUDTestView**: Testing utility

## Key Implementation Details

### Dependency Injection Pattern
Services passed via init parameters (not @Environment) to avoid SwiftData reflection metadata issues on watchOS.

```swift
struct MainView: View {
    @State private var viewModel: MainViewModel

    init(dataService: DataService, timerService: TimerService) {
        _viewModel = State(wrappedValue: MainViewModel(
            dataService: dataService,
            timerService: timerService
        ))
    }
}
```

### SwiftData Predicate Workaround (watchOS)
watchOS has reflection metadata issues with `#Predicate` macro across module boundaries.

**Solution**: Fetch all data, filter in memory
```swift
// DataServiceWatchExtensions.swift
func fetchActivitiesForWatch(scheduledFor weekday: Int?) throws -> [Activity] {
    let descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.name)])
    let allActivities = try modelContext.fetch(descriptor)
    return weekday != nil ? allActivities.filter { $0.scheduledDays.contains(weekday!) } : allActivities
}
```

Conditional compilation in ViewModels:
```swift
#if os(watchOS)
activities = try dataService.fetchActivitiesForWatch(scheduledFor: weekday)
#else
activities = try dataService.fetchActivities(scheduledFor: weekday)
#endif
```

### Timer Background Execution
- Uses `WKExtendedRuntimeSession` on watchOS
- Stores `startTime` (not duration) to prevent drift
- Automatically resumes on app relaunch if `isRunning == true`

### Midnight Mode
Optional feature to continue "yesterday's" activities past midnight. User prompted on first midnight crossing, preference stored in `@AppStorage`.

## Project Structure
```
TimeMyLifeApp/
├── Models/           # SwiftData models (shared)
├── Services/         # DataService, TimerService (shared)
├── ViewModels/       # Business logic (shared)
├── Utilities/        # Helpers, extensions (shared)
├── TimeMyLifeApp/    # iOS app target
└── TimeMyLifeWatch Watch App/
    ├── Views/        # watchOS-specific views
    └── Utilities/    # DataServiceWatchExtensions.swift
```

## Known Issues & Solutions

### 1. SwiftData Predicate Reflection Metadata
**Issue**: `#Predicate<Activity>` fails on watchOS with "Could not find reflection metadata"

**Root Cause**: SwiftData models shared across targets don't expose proper reflection metadata to watchOS module

**Solution**: Created `DataServiceWatchExtensions.swift` with predicate-free methods:
- Fetch all items with simple `FetchDescriptor` (no predicate)
- Filter results in Swift using `.filter()`, `.first()`, `.contains()`
- Trade-off: Less efficient, but acceptable for watchOS data volumes

### 2. Environment Object Injection
**Issue**: `.environment()` with `@Observable` types unreliable on watchOS

**Solution**: Use explicit dependency injection via init parameters
- Pass services through view initializers
- Store in `@State` property
- Re-inject into child views via `.environment()` if needed

## Development Notes

### Testing
- Use CRUDTestView for manual data testing
- Tests create/read/update/delete operations
- Includes large time value testing (10h, 24h, 50h)

### Git
- `.gitignore` configured for Xcode projects
- Excludes `xcuserdata/`, `DerivedData/`, build artifacts

### Future Considerations
- iOS app with data visualization
- iCloud sync between iOS/watchOS
- Watch complications
- Export functionality (CSV/JSON)
- Activity templates and goals

## Quick Start
1. Open `TimeMyLifeApp.xcodeproj`
2. Select "TimeMyLifeWatch Watch App" scheme
3. Build and run on watchOS simulator or device
4. Create activities via "+" button
5. Tap activity to start timer

## Lessons Learned
- SwiftData `#Predicate` macro unreliable across watchOS module boundaries
- Explicit dependency injection more reliable than SwiftUI environment system for complex types
- Fetch-all-then-filter viable pattern for small datasets (< 100 items)
- watchOS requires special consideration for background task continuity
