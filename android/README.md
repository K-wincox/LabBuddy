# LabBuddy Android

This directory contains the Android client for LabBuddy. The iOS app remains the native SwiftUI implementation in the repository root; this client mirrors the same local-first bench workflow in Flutter for Android.

## Current Scope

- Local workspace gate with local-only profile data.
- Four bottom tabs: Today, Protocol, Tools, and My.
- Visual styling follows the iOS LabBuddy language: labBackground / labPanel / labInset surfaces, Apple-like teal accent, 8px cards, low elevation, and bottom inline actions instead of Android-only floating actions.
- Today supports Past / Today / Tomorrow views, editable runs, day rollover, active timers, Bench Mode, and Data Card preview.
- Bench timers schedule Android local notifications when started, and cancel/reschedule those notifications when stopped, paused, or resumed.
- Protocol includes built-in and user-created wet-lab templates, favorites, recents, source notes, and template-to-run creation.
- Tools includes mass, dilution, percentage, PEI transfection, buffer/medium template scaling, saved custom formulas, and local calculation history.
- My includes editable profile details, local avatar import, preferences, project management, custom units/types, local inventory, low-stock warnings, quick stock adjustments, transaction history, and demo reset.
- My supports local JSON backup export and restore for the Android workspace.
- Data Card preview can copy structured text, save a PNG card, and open the Android share sheet.
- Protocol extraction can build a draft from pasted or imported local text files.
- Data is stored locally through `shared_preferences`.

## Commands

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

The debug APK is written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

The release APK is written to:

```text
build/app/outputs/flutter-apk/app-release.apk
```

## Local Release Signing

Release signing is configured from `android/key.properties`, which is ignored by Git. Use `android/key.properties.example` as the template:

```text
storePassword=...
keyPassword=...
keyAlias=labbuddy
storeFile=../../release/labbuddy-release.jks
```

This workspace has a local keystore at `release/labbuddy-release.jks`, also ignored by Git. Rebuild the signed local release APK with:

```sh
flutter build apk --release
```

Verify the APK signature with the Android SDK `apksigner`:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
  "$HOME/Library/Android/sdk/build-tools/36.1.0/apksigner" verify \
  --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The current local release APK is signed by `CN=LabBuddy Local Release`.

## APK Verification

Run the repeatable verification script:

```sh
scripts/verify-android-apk.sh
```

The script runs analyze, tests, debug/release builds, APK signature verification, and, when an Android device or emulator is connected, installs and launches the release APK.

Latest local verification passed analyze, widget tests, debug/release APK builds, and release APK signature verification. Device install and launch smoke testing still requires a connected Android phone or emulator.

## Product Boundary

This Android client follows the current LabBuddy v1 boundary: local-first, personal workspace, no cloud sync, no team collaboration, no AI provider dependency, and no backend requirement for the current APK.
