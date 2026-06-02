# Plan

## Scope

- Align the run detail header cards so experiment info and time use matching vertical layout.
- Preserve step timers only when a Protocol step explicitly defines `durationMinutes`.
- Keep persistence and broader UI redesign out of scope.

## Verification

- `make preflight`
- `git diff --check`
- XcodeBuildMCP simulator build/run and screenshot check
