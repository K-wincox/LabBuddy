# Plan

## Scope

- Fix the bench full-screen mode text overflow.
- Replace nested full-screen sheet behavior with an in-view detail/full-screen mode toggle.
- Add a clear bench-mode entry button from the run detail sheet.
- Keep persistence and broader visual redesign out of scope.

## Verification

- `make preflight`
- `git diff --check`
- XcodeBuildMCP simulator build/run and UI snapshot
