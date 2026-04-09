# Issue #23 — Set Up Dynamic Island & Live Activities

**Issue**: https://github.com/davidchanminpark/TimeMyLifeApp/issues/23

## Problem
When a timer is running, the user has no visibility outside the app. They should see the running timer on the Dynamic Island and Lock Screen via Live Activities, and tap it to return to the app.

## Approach

Live Activities require **ActivityKit** and a **Widget Extension** target. The widget extension provides the UI for the Lock Screen banner, and the Dynamic Island (compact, expanded, minimal views).

### Architecture

1. **Shared `ActivityAttributes`** — defines static (activity name, color, emoji) and dynamic (start time, elapsed seconds) content state. This struct must be accessible from both the main app and the widget extension.
2. **Widget Extension** — new target `TimeMyLifeWidgets` containing the Live Activity widget views (Lock Screen, Dynamic Island compact/expanded/minimal).
3. **`LiveActivityService`** — new service in the iOS app that manages starting/stopping/updating the Live Activity via `ActivityKit`. Integrated into `TimerService`.
4. **Info.plist** — add `NSSupportsLiveActivities = YES` to the main app target.

### Key Design Decisions
- Use `Date.now...` timer style in the widget so the system auto-updates the elapsed time without push updates
- Keep it simple: show activity name, emoji, color, and a live-counting timer
- Tapping the Live Activity deep-links back to the app (default behavior)
- No push token updates needed — timer counts locally via `Text(.timerInterval:)`

## Files to Create
- `TimeMyLifeWidgets/` — new widget extension directory
  - `TimeMyLifeWidgets.swift` — `@main` widget bundle entry point
  - `TimerLiveActivity.swift` — Live Activity widget views (lock screen + dynamic island)
  - `Info.plist` — widget extension plist
- `TimeMyLifeApp/Models/TimerActivityAttributes.swift` — shared `ActivityAttributes` struct
- `TimeMyLifeApp/Services/LiveActivityService.swift` — manages Live Activity lifecycle

## Files to Modify
- `TimeMyLifeApp/Info.plist` — add `NSSupportsLiveActivities`
- `TimeMyLifeApp/Services/TimerService.swift` — call LiveActivityService on start/stop
- `TimeMyLifeApp.xcodeproj/project.pbxproj` — add widget extension target

## Implementation Steps

### Step 1: Create `TimerActivityAttributes` model
Shared struct defining the Live Activity data.

### Step 2: Create Widget Extension target
Use Xcode CLI or manual pbxproj edits to add the widget extension with Live Activity support.

### Step 3: Build Live Activity widget views
- Lock Screen: activity name, emoji, color accent, timer counting up
- Dynamic Island Expanded: activity name + timer
- Dynamic Island Compact (leading/trailing): emoji + timer
- Dynamic Island Minimal: emoji or color dot

### Step 4: Create `LiveActivityService`
Service to request/update/end Live Activities via `ActivityKit.Activity`.

### Step 5: Integrate with `TimerService`
Call LiveActivityService from TimerService's start/stop/resume methods.

### Step 6: Update Info.plist
Add `NSSupportsLiveActivities = true`.

### Step 7: Test
- Verify Live Activity appears on Lock Screen when timer starts
- Verify Dynamic Island shows timer on supported devices
- Verify tapping returns to app
- Verify Live Activity ends when timer stops
- Verify Live Activity persists across app backgrounding
