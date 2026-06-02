# Summary

## Changed

- Aligned the run detail header cards by using matching vertical spacing and comparable text sizing for experiment info and time.
- Changed Protocol import so existing step timers are preserved only when the Protocol step explicitly has `durationMinutes`.
- Added a lightweight UserDefaults compatibility normalization for existing imported/tomorrow runs so old default timer values are removed according to the source Protocol.

## Verification

- `make preflight` passed.
- `git diff --check` passed.
- XcodeBuildMCP simulator build/run succeeded.
- A follow-up screenshot attempt failed because the simulator reported `Shutdown`; no compile or launch error was reported by build/run.
