# Phase 1 Local Acceptance

This checklist proves the first local iOS experience is ready to try in Xcode.

## Preflight

Run:

```sh
./scripts/check-ios-local.sh
```

Expected result before Xcode is installed:

- Swift source type-check passes.
- Xcode project, scheme, assets, and AppIcon checks pass.
- Script stops with the Xcode setup instruction.

Expected result after Xcode is installed:

- The script builds `LabBuddy` for iOS Simulator.
- `Open-LabBuddy.command` or `LabBuddy.xcodeproj` opens the project in Xcode.
- The `LabBuddy` scheme can launch on an iPhone simulator.

## Local Package

Run:

```sh
./scripts/package-ios-prototype.sh
```

Expected result:

- `dist/LabBuddy-iOS-prototype-<commit>.zip` is created.
- `dist/LabBuddy-iOS-prototype-latest.zip` is created as a stable convenience copy.
- The zip includes `LabBuddy.xcodeproj`, Swift source, assets, README, acceptance docs, and scripts.
- The zip includes `Open-LabBuddy.command` for double-click opening after Xcode is installed.

## First Experience Checklist

- App launches without sign-in.
- Today is the first tab and shows wet-lab runs.
- `实验台` opens a large-control bench execution view.
- Steps can be marked complete and stay complete after relaunch.
- A labeled timer can be started from a run.
- Protocol target volume can be changed and imported into Today.
- Imported runs can be removed.
- Tools calculates mass, dilution, and percentage concentration results and copies the result.
- Inventory shows seeded reagents, low-stock warning, deduct/restock controls, and reset.
- Completing a run opens a Data Card.
- Data Card shows run metadata, `Powered by LabBuddy`, and a local report-summary draft that can be copied.

## Current Limitation

Full runtime acceptance still requires full Xcode. The current development machine only has Command Line Tools, so `xcodebuild` cannot run here yet.
