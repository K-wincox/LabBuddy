---
status: complete
completed: 2026-06-23
slug: android-delete-future-calendar
---

# Summary

Implemented Android Protocol deletion hardening and future-date planning.

## Changes

- Added an explicit red `删除 Protocol` button on Android Protocol cards, using the same confirmation and store deletion path as swipe delete.
- Added `planDateKey` to `LabRun` for future planned experiments.
- Converted the Tomorrow tab into a future planning calendar that can select future dates and show/add runs for the selected day.
- Updated end-day rollover to move only tomorrow's runs into today and keep later future plans.
- Added widget tests for explicit Protocol deletion and future planning calendar behavior.

## Verification

- `cd android && flutter analyze`
- `cd android && flutter test test/widget_test.dart`
- `cd android && flutter build apk --release`
