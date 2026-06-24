---
quick_id: 260624-g5x
status: complete
completed: 2026-06-24
---

# Summary

Fixed Android left-swipe deletion globally by changing the shared swipe component and ensuring affected screens refresh after deletion.

## Changes

- Reworked `IosSwipeDelete` so the foreground card translates away and the red delete area remains the actual tappable target.
- Added a stable key for the swipe delete action and test coverage that taps the revealed delete target directly.
- Made Today and future-plan delete callbacks async and refreshed the screen after store deletion.
- Removed the standalone Protocol card delete button; Protocol deletion now uses the global left-swipe delete flow.

## Verification

- `cd android && flutter analyze` passed.
- `cd android && flutter test test/widget_test.dart` passed.
