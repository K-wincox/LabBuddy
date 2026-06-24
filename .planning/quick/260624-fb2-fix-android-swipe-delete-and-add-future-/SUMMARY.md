---
quick_id: 260624-fb2
status: complete
completed: 2026-06-24
---

# Summary

Implemented Android swipe-delete hit testing fix and added cross-platform future-date calendar planning.

## Changes

- Android `IosSwipeDelete` now sizes the foreground card against the row's actual width when revealed, so the red delete target remains tappable.
- Added Android widget coverage for Protocol swipe-delete confirmation and removal.
- Android future planning now exposes the selected future date summary and add action below the calendar.
- iOS future planning now has a calendar view for selecting any future date, filtering plans by selected date and project.
- iOS `LabRun` stores optional `planDateKey`, and old saved future runs are normalized to the next-day date key for compatibility.
- Rollover now promotes only the selected target future date instead of clearing every future plan.

## Verification

- `cd android && flutter analyze` passed.
- `cd android && flutter test test/widget_test.dart` passed.
- `./scripts/check-ios-local.sh` passed.
