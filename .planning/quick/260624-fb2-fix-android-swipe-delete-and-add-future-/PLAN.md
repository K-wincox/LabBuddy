---
quick_id: 260624-fb2
status: complete
created: 2026-06-24
---

# Fix Android Swipe Delete And Add Future Calendar Planning

## Scope

- Fix Android left-swipe delete so tapping the revealed delete button actually reaches the delete action.
- Keep Protocol deletion covered by widget tests.
- Convert future planning from a single Tomorrow bucket into a calendar-selectable future date planner on Android and iOS.
- Preserve existing local-first storage and backward compatibility for runs that were saved without a future date key.

## Verification

- `cd android && flutter analyze`
- `cd android && flutter test test/widget_test.dart`
- `./scripts/check-ios-local.sh`
