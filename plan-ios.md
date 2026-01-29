# iOS App Implementation Plan - Time My Life

## Overview
Build iOS companion app with enhanced features: goals tracking, comprehensive statistics, calendar views, and yearly summaries. Syncs with watchOS via CloudKit + SwiftData.

## Navigation Structure (4 Tabs)
```
TabView:
├── Home (house icon)
├── Goals (target icon)
├── Stats (chart icon)
└── Settings (gear icon)
```

## New Data Models

### Goal (SwiftData)
```swift
@Model
final class Goal {
    var id: UUID
    var activityID: UUID  // Reference to Activity
    var frequency: GoalFrequency  // .daily or .weekly
    var targetSeconds: Int  // Target duration in seconds
    var isActive: Bool
    var createdDate: Date

    // Computed properties (not stored)
    // - currentProgress (from TimeEntry calculations)
    // - currentStreak
    // - streakHistory (last 30 days for visualization)
}

enum GoalFrequency: String, Codable {
    case daily
    case weekly
}
```

### Data Model Extensions
- **Activity**: No changes needed, already supports all features
- **TimeEntry**: No changes needed, already tracks daily durations
- **ActiveTimer**: No changes needed

## Page 1: Home (Reuses Watch Functionality)

### Features
- Activity list filtered by current weekday (same as watchOS)
- Today's total time per activity
- Tap activity → Timer view (start/stop/pause)
- "+" button → Create new activity
- Long press activity → Edit/Delete options

### Views (Reuse Existing)
- `MainView` (iOS version)
- `ActivityTimerView` (adapt from watch)
- `ActivityFormView` (adapt from watch)

### Enhancements Over Watch
- Larger screen: Show more details (category, color)
- Swipe actions for quick edit/delete
- Pull-to-refresh to trigger sync check

## Page 2: Goals

### Layout
```
GoalsView
├── Segmented Control: [Daily Goals | Weekly Goals]
├── ScrollView
│   ├── Goal Cards (one per active goal)
│   │   ├── Activity name + color
│   │   ├── Circular progress indicator (clockwise fill)
│   │   ├── "2.5h / 4.0h" (current / target)
│   │   ├── Streak: 🔥 4
│   │   └── Last 6 days: ✓ ✓ ✗ ✓ ✓ ✓
│   └── "+ Add Goal" button
```

### Goal Card Components
- **CircularProgressView**: Custom circular progress (0-100%, clockwise fill)
- **StreakIndicatorView**: Fire emoji + streak count
- **StreakHistoryView**: 6 squares (checkmark if goal met, X if not)

### Goal Management
- Tap card → Edit goal (change target, deactivate)
- Add goal → Select activity, set frequency, set target duration
- Auto-calculate progress from TimeEntry data
- Streak logic: Consecutive days/weeks meeting goal

### New ViewModels
- `GoalsViewModel`: Fetch goals, calculate progress/streaks, CRUD operations

## Page 3: Statistics

### Navigation Structure
```
StatsView (Main Hub)
├── Time Period Selector: [7 Days | 30 Days | 60 Days | 90 Days]
├── Overview Section
│   ├── Pie Chart (time distribution by activity)
│   ├── Bar Chart (daily/weekly totals)
│   └── Total hours tracked
├── Activity List (tap for details)
└── Additional Views (buttons)
    ├── Calendar View
    └── Yearly Stats (2026)
```

### Overview Charts
- **Pie Chart**: Shows percentage of time per activity for selected period
- **Bar Chart**: Shows daily or weekly totals (grouped by activity)
- Use Swift Charts framework

### Activity Detail View (Tap Activity)
```
ActivityStatsDetailView
├── Header (Activity name, color, category)
├── Key Metrics
│   ├── Daily Average: 2.3h
│   ├── Weekly Average: 16.1h
│   ├── Goal Completion: 85% (if goal exists)
│   ├── Total Time (selected period): 67.5h
│   ├── Longest Session: 4.2h
│   └── Shortest Session: 0.3h
├── Trends Chart (line chart over time)
└── Recent Sessions (list of time entries)
```

### Calendar View
- Month view (FSCalendar or custom)
- Days with tracked activities: colored dots (multiple colors if multiple activities)
- Tap day → Day detail sheet showing activities + durations
- Navigate months (< Previous | Current | Next >)

### Yearly Stats View (2026)
```
YearlyStatsView
├── Year Selector: [2025 | 2026 | 2027]
├── Hero Numbers
│   ├── Total Hours Tracked: 1,247h
│   ├── Most Active Day: March 15 (18.5h)
│   └── Activities Tracked: 12
├── Top Activities
│   ├── #1 Running - 482h
│   ├── #2 Reading - 293h
│   ├── #3 Coding - 187h
├── Longest Streaks
│   ├── Reading: 45 days 🔥
│   ├── Running: 32 days 🔥
│   └── Meditation: 28 days 🔥
├── Monthly Heatmap (12 months, color intensity = hours)
└── Share Button (generate shareable image)
```

### Share Functionality
- Generate image with yearly summary
- Use SwiftUI → UIImage rendering
- Share sheet with options: Save to Photos, Instagram, Messages, etc.

### New ViewModels
- `StatsViewModel`: Aggregate statistics, chart data
- `CalendarViewModel`: Daily activity data for calendar
- `YearlyStatsViewModel`: Yearly aggregations, streak calculations
- `ActivityStatsViewModel`: Individual activity statistics

## Page 4: Settings

### Settings Sections
```
SettingsView
├── General
│   ├── Midnight Mode (toggle) - continue yesterday's activities
│   └── First Day of Week (Picker: Sunday/Monday)
├── Activities
│   ├── Manage All Activities (navigate to list)
│   └── Default Activity Duration Goal (1h, 2h, etc.)
├── Goals
│   ├── Default Daily Goal Duration
│   └── Default Weekly Goal Duration
├── Notifications (future)
│   ├── Goal Reminders
│   └── Streak Warnings (about to break)
├── Data
│   ├── Export Data (CSV/JSON)
│   ├── Import Data
│   ├── Clear All Data (with confirmation)
│   └── Storage Used: 2.3 MB
├── Sync
│   ├── Watch Connection Status (Connected/Disconnected)
│   ├── Last Synced: 2 minutes ago
│   └── Force Sync Now (button)
├── Appearance (future)
│   ├── Color Scheme (System/Light/Dark)
│   └── App Icon Selection
└── About
    ├── Version: 1.0.0
    ├── Privacy Policy
    ├── Terms of Service
    └── Contact Support
```

## Sync Strategy: WatchConnectivity + Local SwiftData

### Why WatchConnectivity (Not CloudKit)?
- **Free**: No paid subscription required
- **Direct communication**: iOS ↔ watchOS without cloud infrastructure
- **Easy CloudKit upgrade**: Clean abstraction layer for future migration
- **Privacy**: Data stays on user's devices only

### Architecture
```
┌────────────────────────────────────────────────┐
│  Sync Abstraction Layer                       │
│  ├─ SyncService (protocol)                    │
│  ├─ WatchConnectivitySyncService (current)    │
│  └─ CloudKitSyncService (future upgrade)      │
└────────────────────────────────────────────────┘
         ↓                           ↓
    iOS App                    watchOS App
    (Local SwiftData)          (Local SwiftData)
         ↓                           ↓
    WatchConnectivity ←────────→ WatchConnectivity
```

### Setup
1. **Remove CloudKit configuration** (no paid subscription needed)
2. **Configure SwiftData** for local-only storage:
   ```swift
   let container = try ModelContainer(
       for: Activity.self, TimeEntry.self, ActiveTimer.self, Goal.self,
       configurations: ModelConfiguration(
           schema: schema,
           isStoredInMemoryOnly: false  // Local persistence only
       )
   )
   ```
3. **Initialize WatchConnectivity sync service**:
   ```swift
   let syncService = WatchConnectivitySyncService()
   let dataService = DataService(
       modelContext: container.mainContext,
       syncService: syncService
   )
   ```

### Sync Behavior
- **Message Passing**: Real-time sync when both devices active and reachable
- **Background Transfers**: Queued updates when counterpart unavailable
- **File Transfer**: Bulk historical data (initial sync, large datasets)
- **Conflict Resolution**: Last-write-wins based on timestamp
- **Timer Sync**: Async approach
  - Timer completes → TimeEntry created → Syncs to counterpart
  - Devices may show different active timers (acceptable trade-off)
  - No real-time active timer sync (keeps complexity low)

### Sync Protocol
```swift
protocol SyncService {
    func syncModel<T: Codable>(_ model: T, type: SyncModelType) async throws
    func syncDelete(id: UUID, type: SyncModelType) async throws
    func requestFullSync() async throws
    var onModelReceived: ((Data, SyncModelType) -> Void)? { get set }
    var onDeleteReceived: ((UUID, SyncModelType) -> Void)? { get set }
    var isCounterpartReachable: Bool { get }
}

enum SyncModelType: String, Codable {
    case activity, timeEntry, activeTimer, goal
}
```

### Edge Cases
- **Watch Not Paired**: App works in local-only mode, syncs when paired
- **One Device Offline**: Messages queued, transferred on reconnection
- **Simultaneous Edits**: Last-write-wins conflict resolution
- **Initial Sync**: Full data transfer on first pairing
- **Data Integrity**: Checksums and validation on receive

### Future CloudKit Upgrade Path
When ready to add CloudKit (requires paid subscription):
1. Implement `CloudKitSyncService` conforming to `SyncService` protocol
2. Add CloudKit entitlements and configuration
3. Swap sync service in app initialization
4. **No changes needed** to ViewModels, Views, or DataService!
5. Gains multi-device sync (iPad, multiple watches, Mac)

## Implementation Phases

### Phase 1: Foundation & Home (Week 1)
- [✅] Remove CloudKit configuration from both iOS and watchOS
- [ ] Configure SwiftData for local-only storage
- [ ] Create SyncService protocol abstraction layer
- [ ] Implement WatchConnectivitySyncService
- [ ] Integrate sync service into DataService
- [ ] Build iOS Home view (activity list, timer, add/edit forms)
- [ ] Test basic sync between iOS and watchOS via WatchConnectivity

### Phase 2: Goals System (Week 2)
- [ ] Create Goal model (SwiftData only, syncs via WatchConnectivity)
- [ ] Build GoalsViewModel with progress/streak calculations
- [ ] Implement GoalsView with daily/weekly tabs
- [ ] Build CircularProgressView component
- [ ] Build StreakIndicatorView and StreakHistoryView components
- [ ] Implement goal creation/editing flow
- [ ] Test goal sync between iOS and watchOS

### Phase 3: Statistics - Overview (Week 3)
- [ ] Create StatsViewModel (aggregate calculations)
- [ ] Build StatsView main hub with time period selector
- [ ] Implement Pie Chart (Swift Charts)
- [ ] Implement Bar Chart (Swift Charts)
- [ ] Build activity list with tap-to-detail navigation

### Phase 4: Statistics - Detail Views (Week 4)
- [ ] Build ActivityStatsDetailView
- [ ] Create ActivityStatsViewModel
- [ ] Implement calendar view (month view, day details)
- [ ] Create CalendarViewModel
- [ ] Build yearly stats view with shareable image generation
- [ ] Create YearlyStatsViewModel

### Phase 5: Settings & Polish (Week 5)
- [ ] Build SettingsView with all sections
- [ ] Implement export/import functionality (CSV/JSON)
- [ ] Add WatchConnectivity sync status monitoring
- [ ] Implement force sync button (request full sync from counterpart)
- [ ] Add app icons and launch screen
- [ ] Polish UI/UX across all views

### Phase 6: Testing & Optimization (Week 6)
- [ ] Test WatchConnectivity sync across devices (iOS ↔ watchOS)
- [ ] Test offline mode and message queuing
- [ ] Test reconnection sync and background transfers
- [ ] Test simultaneous edits and conflict resolution
- [ ] Test large data sets (100+ activities, 10,000+ time entries)
- [ ] Performance optimization (lazy loading, caching)
- [ ] Bug fixes and edge case handling
- [ ] User acceptance testing

## Technical Considerations

### Shared Code (iOS + watchOS)
- Models: Activity, TimeEntry, ActiveTimer, Goal
- Services: DataService, TimerService (extend for Goal operations)
- ViewModels: Shared where possible, platform-specific extensions
- Utilities: Date helpers, formatting, calculations

### iOS-Specific Code
- TabView navigation
- Swift Charts (pie, bar, line charts)
- Calendar view
- Image generation for sharing
- Export/import functionality

### SwiftData Predicate Workaround
- **watchOS**: Continue using fetch-all-then-filter approach (existing workaround)
- **iOS**: Can use `#Predicate` directly (no reflection metadata issues)
- Keep DataServiceWatchExtensions.swift for watchOS compatibility

### Performance Optimizations
- **Lazy Loading**: Use `@Query` with pagination for large lists
- **Caching**: Cache calculated statistics (daily/weekly/yearly aggregates)
- **Background Calculation**: Use Task { } for heavy calculations (streaks, stats)
- **Chart Sampling**: For large datasets, sample data points for charts

### Testing Strategy
- **Unit Tests**: ViewModels, calculation logic (streaks, aggregates)
- **Integration Tests**: WatchConnectivity sync, DataService CRUD
- **UI Tests**: Critical flows (create activity, start timer, create goal)
- **Manual Testing**: Device sync, offline mode, reconnection, edge cases
- **Sync Tests**: Message passing, background transfers, conflict resolution

## File Structure (New iOS Files)

```
TimeMyLifeApp/ (iOS target)
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift (tab container)
│   │   ├── ActivityListView.swift
│   │   └── ActivityTimerView.swift (adapted from watch)
│   ├── Goals/
│   │   ├── GoalsView.swift
│   │   ├── GoalCardView.swift
│   │   ├── CircularProgressView.swift
│   │   ├── StreakIndicatorView.swift
│   │   └── GoalFormView.swift
│   ├── Statistics/
│   │   ├── StatsView.swift (main hub)
│   │   ├── OverviewChartsView.swift (pie + bar)
│   │   ├── ActivityStatsDetailView.swift
│   │   ├── CalendarView.swift
│   │   ├── DayDetailView.swift
│   │   └── YearlyStatsView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── ExportImportView.swift
│   └── Shared/
│       ├── ActivityFormView.swift (create/edit)
│       └── ActivityRowView.swift
├── ViewModels/
│   ├── GoalsViewModel.swift
│   ├── StatsViewModel.swift
│   ├── CalendarViewModel.swift
│   ├── YearlyStatsViewModel.swift
│   └── ActivityStatsViewModel.swift
├── Services/
│   ├── SyncService.swift (protocol)
│   ├── WatchConnectivitySyncService.swift (implementation)
│   ├── CloudKitSyncService.swift (stub for future)
│   └── GoalService.swift (goal-specific operations)
├── Utilities/
│   ├── ChartDataHelpers.swift
│   ├── StreakCalculator.swift
│   ├── StatisticsCalculator.swift
│   └── ImageRenderer.swift (for sharing)
└── TimeMyLifeApp.swift (iOS entry point with CloudKit setup)
```

## Open Questions / Future Enhancements

1. **Notifications**: Remind users about goals, warn about breaking streaks
2. **Widgets**: iOS home screen widgets showing daily progress
3. **Complications**: watchOS complications for quick timer access
4. **Themes**: Custom color schemes beyond system light/dark
5. **Tags/Categories**: Enhanced filtering and grouping
6. **CSV Import**: Import historical data from other apps
7. **Multi-Device Active Timer**: Real-time sync (complex, future enhancement)
8. **Apple Health Integration**: Export activity time to Health app
9. **Siri Shortcuts**: Voice commands to start/stop timers
10. **Family Sharing**: Share activities/goals with family members

## Success Metrics

- [ ] All watchOS features work on iOS
- [ ] WatchConnectivity sync works reliably between iOS and watchOS
- [ ] Sync latency < 2 seconds when devices reachable
- [ ] Background transfers work when devices not active
- [ ] Charts render smoothly with up to 10,000 time entries
- [ ] App launches in < 2 seconds on iPhone 12+
- [ ] Zero data loss during sync conflicts
- [ ] Yearly stats image generates in < 1 second
- [ ] Clean abstraction allows CloudKit upgrade in < 1 day

---

**Estimated Total Lines of Code**: ~4,000 new lines (iOS-specific + sync layer)
**Timeline**: 6 weeks (with 1 developer)
**Dependencies**: Swift Charts, WatchConnectivity, SwiftData, SwiftUI
**Cost**: Free (no subscription required)
