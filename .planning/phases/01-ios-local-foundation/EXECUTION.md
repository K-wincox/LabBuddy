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

## 2026-05-28 clipboard follow-up

- Added a platform-aware clipboard helper for iOS and macOS type-checking.
- Calculator results and Data Card report summaries now write to the clipboard instead of only changing local button state.

## 2026-05-28 package follow-up

- Added `scripts/package-ios-prototype.sh` to create a portable local Xcode prototype zip.
- Added `.gitignore` entries for `dist/`, `DerivedData/`, and user-specific Xcode state.
- Verified the package contains the Xcode project, Swift source, assets, README, acceptance doc, and helper scripts.

## 2026-05-28 package-alias follow-up

- Packaging now also creates `dist/LabBuddy-iOS-prototype-latest.zip` as a stable convenience copy.
- Verified the commit-specific package and latest package are byte-identical.

## 2026-05-28 open-launcher follow-up

- Added `Open-LabBuddy.command` as a double-click launcher for the Xcode project.
- The launcher gives Xcode setup guidance when only Command Line Tools are selected.
- Packaging now includes the launcher.

## 2026-05-28 package-checksum follow-up

- Packaging now emits `dist/LabBuddy-iOS-prototype-latest.zip.sha256`.
- Verified the commit-specific zip and latest zip are byte-identical and pass SHA-256 checks.

## 2026-05-28 package-manifest follow-up

- Packaging now includes `PACKAGE_MANIFEST.txt` at the zip root.
- The manifest records package version, open command, verification command, package names, and the Xcode requirement.

## 2026-05-28 makefile follow-up

- Added a root `Makefile` with `preflight`, `package`, `open`, `clean-demo-package`, and `help` commands.
- Packaging now includes the `Makefile`.
- The package manifest now mentions `make preflight`.

## Verification

- Swift toolchain exists: Swift 6.3.2.
- `swiftc -typecheck LabBuddy/LabBuddyApp.swift LabBuddy/Models.swift LabBuddy/SampleData.swift LabBuddy/ContentView.swift` passes.
- Xcode project, scheme, and asset JSON files validate structurally.
- `./scripts/check-ios-local.sh` passes required-file, Swift source, project, scheme, asset JSON, and AppIcon dimension checks, then exits at the expected Xcode-not-installed gate in this environment.
- `./scripts/package-ios-prototype.sh` creates `dist/LabBuddy-iOS-prototype-<commit>.zip`.
- `dist/LabBuddy-iOS-prototype-latest.zip` matches the commit-specific zip.
- `Open-LabBuddy.command` exits with the expected Xcode setup prompt in the current environment.
- `shasum -a 256 -c dist/LabBuddy-iOS-prototype-latest.zip.sha256` passes after packaging.
- `PACKAGE_MANIFEST.txt` is present at the root of `dist/LabBuddy-iOS-prototype-latest.zip`.
- `make package` creates the latest package and includes `Makefile`, `Open-LabBuddy.command`, and `PACKAGE_MANIFEST.txt`.
- Full `xcodebuild` verification is blocked until Xcode is installed. Current active developer directory only provides Command Line Tools.
