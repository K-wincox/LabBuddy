---
status: complete
completed: 2026-05-29
---

# Summary

Removed the Today tab navigation title so the segmented control is the first visible page element.

## Verification

- `make preflight` passed with Xcode 26.5.
- XcodeBuildMCP `build_run_sim` passed on iPhone 17 Pro Simulator.
- XcodeBuildMCP `snapshot_ui` confirmed the top element is the segmented tab group and the large "今日" heading is gone.
