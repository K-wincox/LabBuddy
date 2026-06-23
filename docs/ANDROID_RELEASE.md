# LabBuddy Android APK Release

LabBuddy Android currently ships as a local demo APK. It does not require a server login.

## Current Download

Latest dual-platform release:

```text
https://github.com/K-wincox/LabBuddy/releases/tag/v1.0.1
```

Direct Android APK:

```text
https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-android.apk
```

Optional checksum:

```text
https://github.com/K-wincox/LabBuddy/releases/download/v1.0.1/LabBuddy-v1.0.1-android.apk.sha256
```

Install the APK on an Android phone. If Android blocks the install, allow the browser or file manager to install apps from unknown sources.

## Demo Login

Use the preset local account on the login screen:

- Email: `demo@labbuddy.app`
- Password: `labbuddy2026`

The app stores experiments, protocols, projects, timers, inventory, and preferences on the device only.

## Local Release Build

From the repository root:

```bash
cd android
flutter pub get
flutter analyze
flutter test test/widget_test.dart
flutter build apk --release
```

The APK is generated at:

```text
android/build/app/outputs/flutter-apk/app-release.apk
```

## GitHub Actions Release Build

The workflow `.github/workflows/mobile-release.yml` runs analyze, widget tests, and `flutter build apk --release`. Tagged releases also publish the Android APK and the iOS prototype package separately.

For signed release APKs, add these repository secrets in GitHub:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded `labbuddy-release.jks`
- `ANDROID_STORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`
- `ANDROID_KEY_ALIAS`

Create the base64 value locally with:

```bash
base64 -i android/release/labbuddy-release.jks | pbcopy
```

If signing secrets are missing, GitHub Actions still builds an APK using the fallback debug signing config. Use signed builds for public release.

## Publish a GitHub Release

Tag and push a version:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The workflow attaches:

- `LabBuddy-v1.0.1-android.apk`
- `LabBuddy-v1.0.1-android.apk.sha256`

Users can download the APK from GitHub Releases and install it on Android after allowing installs from unknown sources.
