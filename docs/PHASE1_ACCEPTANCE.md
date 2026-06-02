# Phase 1 Local Acceptance

This checklist proves the first local iOS experience is ready to try in Xcode.

## Preflight

Run:

```sh
./scripts/check-ios-local.sh
```

or:

```sh
make preflight
```

Expected result before Xcode is installed or selected:

- Xcode project, scheme, assets, and AppIcon checks pass.
- Script stops with the Xcode setup instruction.
- `make preflight` exits with status 2 in this state; that is expected before full Xcode is selected.

Expected result after Xcode is installed:

- The script builds `LabBuddy` for iOS Simulator.
- `Open-LabBuddy.command` or `LabBuddy.xcodeproj` opens the project in Xcode.
- The `LabBuddy` scheme can launch on an iPhone simulator.

## Local Package

Run:

```sh
./scripts/package-ios-prototype.sh
```

or:

```sh
make package
```

Expected result:

- `dist/LabBuddy-iOS-prototype-<commit>.zip` is created.
- `dist/LabBuddy-iOS-prototype-latest.zip` is created as a stable convenience copy.
- `dist/LabBuddy-iOS-prototype-latest.zip.sha256` records SHA-256 checksums.
- The zip includes `LabBuddy.xcodeproj`, Swift source, assets, README, acceptance docs, and scripts.
- The zip includes `Makefile` shortcuts for preflight, package, open, and clean-demo-package.
- The zip includes `Open-LabBuddy.command` for double-click opening after Xcode is installed.
- The zip includes `PACKAGE_MANIFEST.txt` with package version and verification commands.

## First Experience Checklist

- App launches without sign-in.
- Today is the first tab and shows Past / Today / Tomorrow.
- Today shows wet-lab runs as duration events on a calendar-like timeline with collapsed empty time.
- Runs show visible start/end time rules; each run card sits between its time boundaries.
- Tapping a run opens the detail editor.
- Detail and Bench Mode can switch back and forth.
- Bench Mode opens a large-control execution view for one active experiment.
- Step numbers and lab quantities are highlighted where they are operationally important.
- Step completion circles can be tapped; completed step title and detail are struck through.
- Steps can be marked complete and stay complete after relaunch.
- A labeled timer can be started from a run.
- Today can add a run from a protocol template, a manual experiment, or a carryover placeholder.
- Added Today/Tomorrow runs can be edited and removed where allowed.
- Past can show archived experiment records by date.
- Tools calculates mass, dilution, and percentage concentration results and copies the result.
- My contains profile/preferences and opens Inventory.
- Inventory shows seeded reagents, low-stock warning, deduct/restock controls, transaction history, and reset.
- Completing a run opens a Data Card.
- Data Card shows result media/preview, experiment conditions, run metadata, optional `Powered by LabBuddy` watermark, save, copy, and share actions.

## Persistence Checklist

These checks are local-only and should be verified by killing and relaunching the app on the same simulator or device:

- Completed step IDs remain checked.
- Active timers reload from local storage.
- Added Today runs remain in Today.
- Added Tomorrow runs remain in Tomorrow.
- Ending the day archives runs into Past records.
- Inventory item edits and quantity changes remain.
- Inventory transaction history remains.
- User projects remain.
- Calculator history remains.
- Custom buffer templates remain.
- Saved custom formulas remain.
- Protocol favorites, recent protocols, and saved protocols remain.
- My profile/preferences remain.

## Current Limitation

v1 has no backend, account system, cloud sync, shared workspace, or AI provider integration. Internal testing should treat all data as device-local app data. Removing the app or clearing simulator data will remove local data.
