# Summary

## Changed

- Split Today tab code into focused SwiftUI files without changing the current UI design or persistence model.
- Kept `TodayView.swift` as the orchestration layer for selected mode, timers, sheets, and shared bindings.
- Added focused files for scheduling sheets, past records, timers, timeline/run editing, bench mode, and shared helpers.
- Added the new Swift files to the Xcode project target.

## Resulting Files

- `LabBuddy/TodayView.swift`
- `LabBuddy/TodayScheduleSheet.swift`
- `LabBuddy/TodayRecordsView.swift`
- `LabBuddy/TodayTimerViews.swift`
- `LabBuddy/TodayTimelineView.swift`
- `LabBuddy/BenchModeView.swift`
- `LabBuddy/TodayShared.swift`

## Verification

- `make preflight` passed.
- `git diff --check` passed.
- XcodeBuildMCP simulator build, install, launch, UI snapshot, and stop succeeded.
