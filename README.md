# LabBuddy

LabBuddy is a local-first iOS app prototype for wet-lab researchers. The current build focuses on a today-first bench workflow: calendar-like daily scheduling, protocol-based run creation, focused bench execution, step completion, local timers, calculators, inventory in the personal workspace, and shareable result cards.

## Download and test

GitHub repository:

https://github.com/K-wincox/LabBuddy

Latest dual-platform release:

https://github.com/K-wincox/LabBuddy/releases/tag/v1.0.1

Android users can download and install the APK directly:

https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-android.apk

iOS users can download the Xcode prototype package:

https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-ios-prototype.zip

Demo login for Android local test builds:

- Email: `demo@labbuddy.app`
- Password: `labbuddy2026`

Android installation: download the APK on an Android phone, open it, and allow installation from the browser or file manager if Android asks for permission to install apps from unknown sources.

iOS usage: download and unzip the iOS prototype package on a Mac with Xcode, then open `LabBuddy.xcodeproj` or double-click `Open-LabBuddy.command`, choose an iPhone Simulator, and run the app. The current iOS package is not a directly installable iPhone `.ipa`; direct iPhone installation requires Apple signing/provisioning, TestFlight, App Store distribution, or ad hoc device registration.

More detailed tester instructions are in [docs/USER_DOWNLOAD.md](docs/USER_DOWNLOAD.md).

## Open locally

1. Install Xcode from the Mac App Store.
2. Double-click `Open-LabBuddy.command`, or open `LabBuddy.xcodeproj` directly.
3. Select an iPhone simulator.
4. Run the `LabBuddy` scheme.

## Local preflight

Run the local checker before opening Xcode:

```sh
./scripts/check-ios-local.sh
```

or:

```sh
make preflight
```

If Xcode is installed but the checker still points at Command Line Tools, run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then run the checker again. With full Xcode available, the script validates the project and builds the app for iOS Simulator.

Detailed local acceptance steps live in [docs/PHASE1_ACCEPTANCE.md](docs/PHASE1_ACCEPTANCE.md).

Common local commands are also available through `make`:

```sh
make help
make preflight
make package
make open
```

## Package the prototype

Create a portable local zip with the Xcode project, source, docs, and scripts:

```sh
./scripts/package-ios-prototype.sh
```

or:

```sh
make package
```

The package is written to `dist/LabBuddy-iOS-prototype-<commit>.zip`, with a convenience copy at `dist/LabBuddy-iOS-prototype-latest.zip` and SHA-256 checksums in `dist/LabBuddy-iOS-prototype-latest.zip.sha256`.

Each zip includes `PACKAGE_MANIFEST.txt` with the package version, open command, and verification command.

## Current prototype

- Native SwiftUI app, iOS-only, local-first.
- Bundle ID `com.kongweikang.LabBuddy`, version `0.1.0`, build `1`.
- Xcode project currently targets iOS `18.6`.
- No sign-in, cloud sync, account system, backend service, AI provider, or external dependency.
- Four bottom tabs: Today, Protocol, Tools, and My.
- Today supports Past / Today / Tomorrow views. Past shows archived experiment days; Today and Tomorrow are editable plans.
- Daily runs are displayed as calendar-like duration events with collapsed empty time and visible start/end time rules.
- Runs can be created from Today using a protocol template, a manual experiment, or a carryover placeholder.
- Step completion state persists locally with `@AppStorage`.
- App-local labeled timers can be started from experiment cards and persist between launches.
- Bench Mode opens a focused, large-control execution view for one active experiment and can switch back to detail.
- Protocol manages local method templates, variables, ingredients, steps, source notes, favorites, recents, and consistency checks.
- Tools has interactive mass, dilution, percentage, custom formula, history, and buffer template workflows.
- My contains profile/preferences plus personal inventory with low-stock warnings, quick adjustments, and transaction history.
- Bench completion or sharing can generate a Data Card preview with image/metadata, experiment conditions, optional watermark, save, copy, and share actions.

## First walkthrough

1. Start on the Today tab.
2. Tap `实验台` on any run to enter the focused bench-side view.
3. Mark steps complete with the large check controls.
4. Start a timer from the bench view or experiment card.
5. In Today, add an experiment from an empty insertion point and choose a protocol template or manual experiment.
6. Confirm the time and details, then return to the timeline to see the new run.
7. Open Tools, calculate a mass/dilution/percentage recipe, and copy the result.
8. Open My, enter Inventory, and try quick deduct/restock on a low-stock item.
9. Finish a run in Bench Mode or tap the share button to preview the first Data Card.
10. Attach or preview a result image, then copy/share the Data Card conditions.
11. Use My's local demo reset action if you want to replay the demo from a clean local state.

## Verification status

The repository currently has project-file validation and iOS Simulator build verification through `./scripts/check-ios-local.sh` / `make preflight`. Full Xcode is available in the current development environment.

## Persistence model

v1 is intentionally local-only. Current state is stored with `UserDefaults`, `@AppStorage`, and `Codable` JSON payloads for imported Today runs, Tomorrow runs, Past records, inventory, projects, timers, calculator history, custom buffer/formula data, protocol favorites/recents/saved protocols, preferences, and completed step IDs.

There is no backend in v1. A backend should only be introduced when the product needs account login, multi-device sync, cloud backup, shared lab/team collaboration, cross-device protocol libraries, subscription entitlement validation, or server-side AI workflows. Until then, local persistence is the correct scope for internal testing.
