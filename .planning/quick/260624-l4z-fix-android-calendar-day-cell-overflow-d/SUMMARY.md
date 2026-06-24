---
quick_id: 260624-l4z
status: complete
completed: 2026-06-24
---

# Summary

Fixed Android calendar day cell overflow by giving the calendar grid a stable row extent and tightening selected-day marker spacing.

## Verification

- `cd android && flutter analyze` passed.
- `cd android && flutter test test/widget_test.dart --plain-name "Tomorrow tab uses calendar planning for future dates"` passed.
