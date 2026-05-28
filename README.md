# LabBuddy

LabBuddy is a local-first iOS app prototype for wet-lab researchers. The first usable build focuses on a today-first bench workflow: scheduled runs, step completion, protocol scaling previews, and quick calculator examples.

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

If Xcode is installed but the checker still points at Command Line Tools, run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then run the checker again. With full Xcode available, the script validates the project and builds the app for iOS Simulator.

Detailed local acceptance steps live in [docs/PHASE1_ACCEPTANCE.md](docs/PHASE1_ACCEPTANCE.md).

## Package the prototype

Create a portable local zip with the Xcode project, source, docs, and scripts:

```sh
./scripts/package-ios-prototype.sh
```

The package is written to `dist/LabBuddy-iOS-prototype-<commit>.zip`, with a convenience copy at `dist/LabBuddy-iOS-prototype-latest.zip` and SHA-256 checksums in `dist/LabBuddy-iOS-prototype-latest.zip.sha256`.

Each zip includes `PACKAGE_MANIFEST.txt` with the package version, open command, and verification command.

## Current prototype

- Native SwiftUI app, iOS 17.0 target.
- No sign-in, cloud sync, account system, AI provider, or external dependency.
- Today tab with seeded cell experiment, plasmid prep, and Western blot/gel work.
- Step completion state persists locally with `@AppStorage`.
- App-local labeled timers can be started from experiment cards and persist between launches.
- Bench Mode opens a focused, large-control execution view for one active experiment.
- Protocol tab previews proportional recipe scaling and imports scaled runs into Today.
- Imported runs can be removed from Today so repeated demos stay tidy.
- Tools tab has interactive mass, dilution, and percentage calculators plus clipboard copy.
- Inventory tab tracks local reagent/material quantities with low-stock warnings and quick adjustments.
- Inventory includes a local demo reset action for repeated Xcode testing.
- Bench completion can generate a first Data Card preview with run metadata and LabBuddy branding.
- Data Cards include a local mentor-report summary draft with clipboard copy.

## First walkthrough

1. Start on the Today tab.
2. Tap `实验台` on any run to enter the focused bench-side view.
3. Mark steps complete with the large check controls.
4. Start a timer from the bench view or experiment card.
5. Open the Protocol tab, adjust the target volume, and tap `导入今日安排`.
6. Return to Today to see the newly imported scaled run.
7. Open Tools, calculate a mass/dilution/percentage recipe, and copy the result.
8. Open Inventory and try quick deduct/restock on a low-stock item.
9. Finish a run in Bench Mode or tap the share button to preview the first Data Card.
10. Copy the local report summary draft from the Data Card.
11. Use Inventory's reset action if you want to replay the demo from a clean local state.

## Verification status

The repository currently has Swift source type-checking and project-file validation through `./scripts/check-ios-local.sh`. Full `xcodebuild` verification requires full Xcode; this machine currently only has Command Line Tools.
