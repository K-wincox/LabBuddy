---
status: in_progress
created: 2026-06-23
---

# Android Local Demo Login and GitHub APK Release

## Goal
Make the Android APK distributable without any server login: users can sign in with a preset local demo email/password, and GitHub can build/publish release APKs for download.

## Scope
- Replace free-form Android auth gate with preset local demo email/password validation.
- Keep all session data local and preserve existing LabStore auth persistence.
- Remove misleading server-login affordances from the Android preferences surface where practical.
- Add GitHub Actions workflow to analyze, test, build APK, and upload/publish release artifacts.
- Add release/download documentation with demo credentials and signing secret setup.
- Verify with format, analyze, widget tests, and release APK build.

## Verification
- `dart format android/lib/main.dart android/test/widget_test.dart`
- `flutter analyze`
- `flutter test test/widget_test.dart`
- `flutter build apk --release`
