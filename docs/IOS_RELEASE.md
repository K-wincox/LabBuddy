# LabBuddy iOS Release

LabBuddy iOS is distributed here as an Xcode prototype/source package.

## Download

From GitHub Releases, download:

- `LabBuddy-<version>-ios-prototype.zip`
- `LabBuddy-<version>-ios-prototype.zip.sha256`

## Run on macOS with Xcode

Unzip the package, then either:

- double-click `Open-LabBuddy.command`, or
- open `LabBuddy.xcodeproj` in Xcode and run the `LabBuddy` scheme on an iOS Simulator.

You can verify locally with:

```bash
./scripts/check-ios-local.sh
```

## Important Distribution Note

This package is not a universal installable iPhone `.ipa`.

Apple requires code signing and provisioning for direct device installation. To distribute an iPhone-installable build, use one of these routes:

- TestFlight
- App Store
- Apple Developer ad hoc distribution with registered device UDIDs
- Enterprise distribution if you have the required Apple program

The GitHub Release also includes the Android APK as a separate asset so users can choose Android or iOS separately.
