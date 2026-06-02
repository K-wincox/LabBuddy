# Summary

## Changed

- Updated v1 planning decisions so the built-in workflow families are cell, animal, nucleic-acid, and protein experiments.
- Split the Today screen implementation out of `ContentView.swift` into `TodayView.swift`.
- Kept `ContentView.swift` focused on root tab composition, shared prototype state, UserDefaults persistence, and day rollover.
- Added `TodayView.swift` to the Xcode project target.

## Verification

- `make preflight` passed.
- `git diff --check` passed.
- XcodeBuildMCP simulator build, install, launch, and UI snapshot succeeded.
