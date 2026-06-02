# Plan

## Scope

- Split `LabBuddy/TodayView.swift` into focused SwiftUI source files.
- Keep current UI behavior and visual design unchanged.
- Do not implement SwiftData or persistence changes in this step.

## Target Files

- `TodayView.swift`: top-level Today tab state and orchestration.
- `TodayScheduleSheet.swift`: target day, schedule request, add experiment sheet.
- `TodayRecordsView.swift`: past records calendar/list/detail views.
- `TodayTimelineView.swift`: day timeline, run chips, expanded run card, edit sheets.
- `TodayTimerViews.swift`: timer dock and timer display.
- `BenchModeView.swift`: bench execution modes.

## Verification

- `make preflight`
- `git diff --check`
- XcodeBuildMCP simulator build/run smoke test
