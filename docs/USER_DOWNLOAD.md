# LabBuddy Download and Test Guide

This guide is for test users who want to download LabBuddy from GitHub.

## GitHub Links

Project homepage:

https://github.com/K-wincox/LabBuddy

Latest dual-platform release:

https://github.com/K-wincox/LabBuddy/releases/tag/v1.0.1

## Android Download

Download the Android APK:

https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-android.apk

Optional checksum:

https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-android.apk.sha256

### Android Installation

1. Open the APK download link on an Android phone.
2. Download `LabBuddy-v1.0.1-android.apk`.
3. Tap the downloaded APK to install it.
4. If Android blocks the install, allow the current browser or file manager to install apps from unknown sources.
5. Open LabBuddy after installation.

## iOS Download

Download the iOS prototype package:

https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-ios-prototype.zip

Optional checksum:

https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-ios-prototype.zip.sha256

### iOS Usage

1. Download the iOS zip on a Mac with Xcode installed.
2. Unzip `LabBuddy-v1.0.1-ios-prototype.zip`.
3. Open `LabBuddy.xcodeproj`, or double-click `Open-LabBuddy.command`.
4. Select an iPhone Simulator in Xcode.
5. Click Run.

The current iOS package is an Xcode/iOS Simulator prototype package. It is not a universal installable iPhone `.ipa`.

Direct iPhone installation requires Apple code signing and one of these distribution routes:

- TestFlight
- App Store
- Apple Developer ad hoc distribution with registered device UDIDs
- Enterprise distribution, if the required Apple program is available

## Demo Login

Use this preset local test account in the Android app:

- Email: `demo@labbuddy.app`
- Password: `labbuddy2026`

This account does not use a server login. LabBuddy stores the demo data locally on the device.

## Copyable Tester Message

You can send this message to a test user:

```text
LabBuddy download page:
https://github.com/K-wincox/LabBuddy/releases/tag/v1.0.1

Android APK:
https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-android.apk

iOS Xcode prototype:
https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-ios-prototype.zip

Demo login:
Email: demo@labbuddy.app
Password: labbuddy2026

Android can install the APK directly. iOS currently needs a Mac with Xcode and runs through an iPhone Simulator.
```
