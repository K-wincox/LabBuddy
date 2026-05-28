# Phase 1 Execution Notes

## 2026-05-28

- Created a native SwiftUI iOS project at `LabBuddy.xcodeproj`.
- Added a first local-only LabBuddy experience:
  - Today-first bench workflow with three seeded wet-lab runs.
  - Large step controls with persisted completion state via `@AppStorage`.
  - Protocol browser with scale-factor recipe preview.
  - Calculator toolbox examples for dilution, mass, and percentage concentration.
- Kept scope local-first with no account, network, cloud sync, AI provider, or external dependency.

## 2026-05-28 follow-up

- Added app-local labeled timers launched from experiment cards.
- Persisted active timers in `UserDefaults` so the initial prototype survives app relaunches.
- Added a running-timer dock and urgent timer summary on the Today header.
- Added a first Data Card preview sheet with run metadata and subtle `Powered by LabBuddy` branding.

## 2026-05-28 bench-mode follow-up

- Added a focused Bench Mode sheet for one active experiment.
- Bench Mode uses larger typography, larger tap targets, current-step emphasis, and timer visibility.
- Added a README first walkthrough so the first local Xcode run has an obvious experience path.

## 2026-05-28 protocol-import follow-up

- Lifted imported run state to the app root.
- Protocol cards now import a scaled local run into Today.
- Imported runs persist in `UserDefaults` and are included in Today counts, timers, Bench Mode, and Data Card preview.

## 2026-05-28 calculator follow-up

- Replaced the static Tools-only calculator examples with interactive calculators.
- Added mass concentration, liquid dilution, and percentage concentration modes.
- Calculator results update locally and expose a first copy-ready interaction state.

## 2026-05-28 report-loop follow-up

- Added a Bench Mode completion action that marks all run steps complete, clears the run timer, and opens the Data Card.
- Data Card preview now includes a local report-summary draft based on run metadata.
- The report action now changes state locally instead of acting as a placeholder close button.

## 2026-05-28 inventory follow-up

- Added a local Inventory tab with seeded wet-lab reagents and consumables.
- Inventory quantities persist in `UserDefaults`.
- Low-stock items are visually marked and can be quickly deducted or restocked.

## 2026-05-28 demo-reset follow-up

- Imported Today runs can be removed individually.
- Inventory now exposes a reset action to clear imported runs, step completion, active timers, and inventory edits.
- The reset path keeps repeated local Xcode demos from accumulating stale prototype state.

## 2026-05-28 local-preflight follow-up

- Added `scripts/check-ios-local.sh` for local source, project, scheme, asset, and Xcode environment checks.
- The script builds the app for iOS Simulator when full Xcode is available.
- In the current Command Line Tools-only environment, the script exits with an explicit Xcode setup instruction after passing static checks.

## 2026-05-28 acceptance follow-up

- Added `docs/PHASE1_ACCEPTANCE.md` to make local Xcode acceptance explicit.
- Expanded preflight checks for required files, shared scheme identity, and AppIcon dimensions.

## Verification

- Swift toolchain exists: Swift 6.3.2.
- `swiftc -typecheck LabBuddy/LabBuddyApp.swift LabBuddy/Models.swift LabBuddy/SampleData.swift LabBuddy/ContentView.swift` passes.
- Xcode project, scheme, and asset JSON files validate structurally.
- `./scripts/check-ios-local.sh` passes required-file, Swift source, project, scheme, asset JSON, and AppIcon dimension checks, then exits at the expected Xcode-not-installed gate in this environment.
- Full `xcodebuild` verification is blocked until Xcode is installed. Current active developer directory only provides Command Line Tools.
