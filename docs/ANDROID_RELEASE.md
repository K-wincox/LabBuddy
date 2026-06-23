# LabBuddy Android APK Release

LabBuddy Android currently ships as a local demo APK. It does not require a server login.

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

The workflow `.github/workflows/android-apk.yml` runs analyze, widget tests, and `flutter build apk --release`.

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
git tag v1.0.0
git push origin v1.0.0
```

The workflow attaches:

- `LabBuddy-v1.0.0.apk`
- `LabBuddy-v1.0.0.apk.sha256`

Users can download the APK from GitHub Releases and install it on Android after allowing installs from unknown sources.
