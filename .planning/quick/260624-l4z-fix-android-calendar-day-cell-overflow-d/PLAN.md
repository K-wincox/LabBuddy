---
quick_id: 260624-l4z
status: complete
created: 2026-06-24
---

# Fix Android Calendar Day Cell Overflow

## Scope

- Remove Flutter debug overflow text from the Android calendar date cells.
- Keep the future planning calendar visually stable on small screens.

## Verification

- `cd android && flutter analyze`
- `cd android && flutter test test/widget_test.dart --plain-name "Tomorrow tab uses calendar planning for future dates"`
