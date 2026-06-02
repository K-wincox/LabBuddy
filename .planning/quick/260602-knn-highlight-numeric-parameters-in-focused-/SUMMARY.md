# Summary

## Changed

- Added a shared `highlightedLabParameters` helper for numeric experiment parameters.
- Applied parameter highlighting to focused timeline cards, run detail steps, and step rows.
- Removed the duplicate detail-only highlighter from `RunDetailSheet`.

## Verification

- `make preflight` passed.
- `git diff --check` passed.
- XcodeBuildMCP simulator build and launch passed on iPhone 17.
