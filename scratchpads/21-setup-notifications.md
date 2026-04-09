# Issue #21 — Set Up Notifications

**Link:** https://github.com/davidchanminpark/TimeMyLifeApp/issues/21

## Summary
Add configurable daily goal progress notifications. Users pick times (e.g., 12 PM, 3 PM, 6 PM) in Settings. At each scheduled time, a local notification fires showing a summary of daily goal progress.

## Approach

### 1. NotificationService (new)
- `@Observable @MainActor` class, follows existing service pattern
- Wraps `UNUserNotificationCenter`
- Methods:
  - `requestPermission()` — asks user for notification permission
  - `scheduleProgressNotifications(dataService:)` — builds notification content from daily goals, schedules at each selected time via `UNCalendarNotificationTrigger`
  - `cancelAllNotifications()` — removes all pending notifications
  - `reschedule(dataService:)` — cancel + re-schedule (called when settings change or app becomes active)
- Notification content: "Daily Goals: 2/3 completed — Keep going!" or "All 3 daily goals met today!"
- Identifier prefix: `"goal-progress-"` + hour, so each time slot has one notification

### 2. Settings UI — Notifications Section (in SettingsView)
- New section "Notifications" between General and Activities
- Toggle: Enable/disable notifications (`@AppStorage("notificationsEnabled")`)
- Multi-select time picker: predefined times (9 AM, 12 PM, 3 PM, 6 PM, 9 PM)
  - Store as comma-separated hours string in `@AppStorage("notificationHours")`, default "12,18" (noon + 6 PM)
  - Each time shown as a chip/button, tappable to toggle
- When toggle turns on → request permission, schedule
- When toggle turns off → cancel all
- When times change → reschedule

### 3. App Integration
- Create `NotificationService` in `TimeMyLifeAppApp.init()`
- Pass to `ContentView` → `SettingsView`
- On `.active` scene phase: reschedule notifications (updates content with latest progress)

### 4. Tests
- `NotificationServiceTests.swift` — test notification content generation, scheduling logic
- Use protocol/mock for `UNUserNotificationCenter` to test without real notifications

## Files to Create
- `TimeMyLifeApp/Services/NotificationService.swift`
- `TimeMyLifeAppTests/Unit/Services/NotificationServiceTests.swift`

## Files to Modify
- `TimeMyLifeApp/Views/Settings/SettingsView.swift` — add Notifications section
- `TimeMyLifeApp/TimeMyLifeAppApp.swift` — init NotificationService, pass it, reschedule on active
- `TimeMyLifeApp/Views/ContentView.swift` — pass NotificationService to SettingsView

## Implementation Steps
1. Create `NotificationService` with permission + scheduling logic
2. Write tests for notification content generation
3. Add notifications section to SettingsView
4. Wire up NotificationService in app entry point and ContentView
5. Reschedule on app active + settings changes
6. Test end-to-end on simulator
