# Time My Life - watchOS Time Tracking App Implementation Plan

## Project Overview

Time My Life is a watchOS app that quantifies a person's life activities. Users can set different activities for each day of the week, track time spent on each activity, and gain insights into their productivity patterns.

## Technology Stack

- **SwiftUI** for all UI components
- **SwiftData** for data persistence (local watch storage)
- **Background Tasks** for timer continuation
- **watchOS 10.0+** minimum deployment target

## Data Models (SwiftData)

### 1. Activity Model
- Properties:
  - `id: UUID`
  - `name: String` (max ~25 characters for watch display)
  - `colorHex: String` (for visual identification)
  - `category: String` (tag/category like "music", "social", "reading")
  - `scheduledDays: [Int]` (Set of weekdays, 1=Sunday, 2=Monday, ..., 7=Saturday)
  - `createdAt: Date`
- Validation: Maximum 30 activities total
- Helper methods:
  - Check if scheduled for specific weekday
  - Convert hex to Color

### 2. TimeEntry Model
- Properties:
  - `id: UUID`
  - `activityID: UUID` (reference to Activity)
  - `date: Date` (normalized to start of day)
  - `totalDuration: TimeInterval` (in seconds)
- One entry per activity per day
- Accumulates multiple sessions into single duration
- Methods:
  - Add duration to existing entry
  - Format duration as HH:MM:SS

### 3. ActiveTimer Model
- Properties:
  - `id: UUID`
  - `activityID: UUID?` (currently running activity)
  - `startTime: Date?`
  - `isRunning: Bool`
- Singleton-like behavior (only one timer active at a time)
- Methods:
  - Start timer for activity
  - Stop timer and return elapsed duration
  - Get current elapsed time without stopping

## Views Architecture

### 1. MainView - Activity List for Current Day
**Purpose**: Display activities scheduled for today

**UI Elements**:
- Navigation bar with:
  - Settings button (top left)
  - Add button (top right, "+" icon)
- List of activities filtered by current weekday
- Each activity row shows:
  - Color indicator (circle or vertical bar)
  - Activity name
  - Today's accumulated time (if any)
- Tap activity → navigate to ActivityTimerView

**Data Requirements**:
- Query activities where `scheduledDays` contains current weekday
- Query today's TimeEntry for each activity to show accumulated time

### 2. AddActivityView - Create New Activity
**Purpose**: Form to create new activity

**UI Elements**:
- Text field for activity name (limit ~25 chars)
- Color picker (SwiftUI ColorPicker)
- Text field or picker for category/tag
- Multi-select toggle for days of week (Sun-Sat)
- Save button
- Cancel button

**Validation**:
- Check total activity count < 30
- Require name to be non-empty
- At least one day must be selected

**Behavior**:
- Create new Activity model and save to SwiftData
- Navigate back to previous view on save

### 3. SettingsView - Manage Existing Activities
**Purpose**: View and edit all created activities

**UI Elements**:
- List of all activities (regardless of schedule)
- Optional: Group by category or alphabetical
- Each row shows activity name and color
- Tap activity → navigate to EditActivityView
- Swipe to delete activity

**Behavior**:
- Delete activity → also delete associated TimeEntries (cascade)
- Show confirmation before deletion

### 4. EditActivityView
**Purpose**: Modify existing activity

**UI Elements**:
- Reuse AddActivityView form structure
- Pre-populate fields with existing activity data
- Save changes or Cancel

**Behavior**:
- Update Activity model in SwiftData
- Navigate back on save

### 5. ActivityTimerView - Timer Interface
**Purpose**: Start/stop timer for specific activity

**UI Elements**:
- Activity name at top
- Large, prominent timer display (HH:MM:SS or MM:SS)
- Start/Stop button (large, center of screen)
- Display today's accumulated time below timer
- Activity color as background accent or border

**Behavior**:
- Start: Check no other timer is running, create/update ActiveTimer
- Stop: Calculate duration, update/create TimeEntry for today
- Timer updates every second while running
- Background execution continues timer

## Core Functionality

### 1. SwiftData Setup
- Configure ModelContainer in `Time_My_LifeApp.swift`
- Register all three models: Activity, TimeEntry, ActiveTimer
- Set up ModelContext for CRUD operations
- Ensure ActiveTimer singleton exists on first launch

### 2. Timer Management
**Active Timer**:
- Use Combine `Timer.publish()` or async `Task` for UI updates (every 1 second)
- Store start timestamp in ActiveTimer model
- Calculate elapsed time on-the-fly: `Date() - startTime`
- On stop:
  - Calculate total elapsed duration
  - Query for existing TimeEntry (activityID + today's date)
  - If exists: add duration to existing entry
  - If not: create new TimeEntry
  - Reset ActiveTimer state

**Background Execution**:
- Use `WKExtendedRuntimeSession` to keep timer running when app is backgrounded
- Save timer state to SwiftData so it persists across app terminations
- On app relaunch: check if ActiveTimer.isRunning == true, resume timer display

### 3. Business Logic

**Weekday Filtering**:
- Use `Calendar.current.component(.weekday, from: Date())` to get current day (1-7)
- Filter activities where `scheduledDays.contains(currentWeekday)`

**Single Timer Constraint**:
- Before starting new timer, check `ActiveTimer.isRunning`
- If another timer is running, show alert or automatically stop it first
- UI layer enforces constraint

**Duration Accumulation**:
- When stopping timer, query: `TimeEntry where activityID == X AND date == today`
- If found: `existingEntry.totalDuration += newDuration`
- If not found: Create new TimeEntry with `totalDuration = newDuration`

**Activity Limit Validation**:
- In AddActivityView, query total count of Activity models
- If count >= 30, disable save button and show message

## Implementation Order

### Phase 1: Data Layer
1. ✅ Create SwiftData models: Activity, TimeEntry, ActiveTimer
2. ✅ Set up ModelContainer in app entry point
3. ✅ Test CRUD operations with sample data

### Phase 2: Basic UI
4. ✅ Create MainView with hardcoded mock activities
5. ✅ Implement navigation structure (NavigationStack)
6. ✅ Create AddActivityView form
7. ✅ Connect AddActivityView to create real activities
8. ✅ Connect MainView with real activities

### Phase 3: Activity Management
9. ✅ Implement SettingsView to list all activities
10. ✅ Add edit functionality (EditActivityView reusing form)
11. ✅ Add delete functionality with confirmation

### Phase 4: Timer Core
12. ✅ Create ActivityTimerView with static UI
13. ✅ Implement basic start/stop timer logic
14. ✅ Connect timer to TimeEntry persistence
15. ✅ Implement duration accumulation for same day

### Phase 5: Background Support
16. ✅ Add WKExtendedRuntimeSession for background timers
17. ✅ Handle app termination/resume scenarios
18. Test timer continuity across app states (test on actual apple watch)

### Phase 6: Polish
19. Refine UI/UX (colors, spacing, watchOS best practices)
20. Add error handling and user feedback
21. Add loading states and empty states
22. Write unit tests for core logic

### Phase 7: Testing
23. Manual testing on simulator and device
24. Test edge cases (max activities, long durations, date changes)
25. Performance testing

## Technical Decisions & Tradeoffs

### SwiftData vs Core Data
**Choice**: SwiftData

**Pros**:
- Native SwiftUI integration with `@Query` property wrapper
- Less boilerplate code
- Modern Swift-first API
- Easier iCloud sync setup (future iOS app integration)

**Cons**:
- Requires watchOS 10.0+ (acceptable for new project)
- Fewer community resources/Stack Overflow answers
- Newer, potentially more bugs

**Tradeoff**: Chosen for future-proofing and cleaner code

### Timer Implementation
**Choice**: Combine Timer + WKExtendedRuntimeSession

**Alternatives considered**:
- Pure async/await with Task.sleep
- Background refresh tasks only

**Rationale**:
- Combine Timer provides reliable UI updates
- WKExtendedRuntimeSession allows true background execution
- Storing startTime (not duration) prevents drift on background/resume

### Color Storage
**Choice**: Store hex strings, convert to Color on-the-fly

**Rationale**:
- SwiftData doesn't natively support Color type
- Hex strings are lightweight and portable
- Easy to extend for future iOS app

### Weekday Representation
**Choice**: Array of integers (1-7)

**Alternatives**:
- Bitmask/OptionSet
- Array of string names

**Rationale**:
- Simple and readable
- Works well with SwiftData
- Easy to query and filter

## Future Enhancements (Not in Scope)

- iCloud sync with iOS companion app
- Data visualization (charts, insights)
- Notifications/reminders for scheduled activities
- Apple Watch complications
- Export data (CSV, JSON)
- Activity templates
- Goal setting per activity

## UI/UX Design Notes

### watchOS Best Practices
- Keep text short and scannable
- Use Digital Crown where appropriate
- Optimize for small screen (38mm-49mm)
- High contrast colors for readability
- Large, tappable buttons (min 44pt)

### Color Palette
- Use system colors as defaults (blue, green, orange, red, purple, pink)
- Allow custom colors via ColorPicker
- Ensure sufficient contrast for accessibility

### Typography
- System font for consistency
- Bold for emphasis (activity names, timer)
- Regular weight for secondary info

### Animation
- Smooth transitions between views
- Subtle animations for timer updates
- No distracting motion

## Testing Strategy

### Unit Tests
- Activity validation (name length, day selection)
- TimeEntry accumulation logic
- Timer start/stop calculations
- Weekday filtering

### UI Tests
- Create activity flow
- Edit/delete activity flow
- Start/stop timer flow
- Navigation between views

### Manual Testing Scenarios
- Create 30 activities (limit test)
- Start timer, background app, resume
- Start timer, force quit, relaunch
- Multiple sessions same activity same day
- Date rollover during active timer
- Empty states (no activities, no time entries)

## Questions Resolved

1. **Data Persistence**: Local watch storage only (iCloud sync deferred)
2. **Multiple Timers**: Only one timer at a time
3. **Background Timers**: Yes, using WKExtendedRuntimeSession
4. **Pause/Resume**: No, just start/stop
5. **Main Page Activities**: Only show today's scheduled activities
6. **Time Tracking**: Total duration per day (multiple sessions combined)
7. **Historical Data**: Store forever
8. **Activity Limits**: 30 max activities, ~25 char max name
