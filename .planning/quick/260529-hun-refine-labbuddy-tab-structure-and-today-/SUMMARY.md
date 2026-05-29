---
status: complete
completed: 2026-05-29
---

# Summary

Implemented navigation and Today-page refinements:

- Kept the app at four tabs by moving Inventory into "我的".
- Changed Protocol imports to create "明天" plans by default.
- Reworked Today into a segmented surface ordered "实验记录 / 今天 / 明天".
- Made "实验记录" the default Today landing view.
- Added a calendar-like experiment record visualization with zoom controls and selectable day cells.
- Added a dedicated tomorrow planning view for Protocol-imported experiments.
- Removed the previous LabBuddy/local-mode header card from the Today page.

## Verification

- `make preflight` passed with Xcode 26.5.
- XcodeBuildMCP `build_run_sim` passed on iPhone 17 Pro Simulator.
- XcodeBuildMCP `snapshot_ui` confirmed the default experiment-record view with zoom slider and day cells.
