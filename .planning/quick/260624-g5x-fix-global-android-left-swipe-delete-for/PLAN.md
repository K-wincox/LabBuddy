---
quick_id: 260624-g5x
status: complete
created: 2026-06-24
---

# Fix Global Android Left-Swipe Delete

## Scope

- Fix the shared Android `IosSwipeDelete` component so the revealed red delete target is tappable globally.
- Ensure Today run deletion refreshes the visible timeline immediately after the store deletes the run.
- Remove the extra Protocol card delete button so Protocol deletion is left-swipe based.
- Add tests covering Today and Protocol left-swipe deletion through the shared delete action.

## Verification

- `cd android && flutter analyze`
- `cd android && flutter test test/widget_test.dart`
