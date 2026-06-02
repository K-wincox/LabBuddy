# Quick Summary

## Result

- Added shared helpers for parsing and formatting `HH:mm` labels.
- Added derived `LabRun` schedule properties for start minute, inferred duration, end minute, and display range.
- Updated the Today timeline so experiment cards behave as time-range events instead of single time-node entries.
- Replaced inline `09:00-09:15` labels with start/end endpoint markers; the end marker includes the end time and a horizontal line.
- Wired focused timeline step circles to the existing step-completion state so tapping a circle toggles the strikethrough completion state.
- Kept empty hours collapsed and kept full step cards visible in focused mode.

## Verification

- `make preflight` passed.
- `git diff --check` passed.
- XcodeBuildMCP simulator build and launch passed on iPhone 17.
- Captured and inspected Today screenshots after launch; visible run shows endpoint time markers without expanding the full day into large blank space.
