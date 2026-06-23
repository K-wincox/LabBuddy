---
status: complete
created: 2026-06-23
slug: android-delete-future-calendar
---

# Quick Task: Android delete actions and future planning calendar

## Scope

- Fix Android Protocol deletion so users have a visible delete control in addition to swipe delete.
- Audit existing delete surfaces for store-level delete behavior.
- Change the Tomorrow tab into a calendar-style future planning view.
- Preserve old `tomorrowRuns` data by defaulting it to tomorrow.

## Verification

- `flutter analyze`
- `flutter test test/widget_test.dart`
- `flutter build apk --release`
