---
status: complete
completed: 2026-05-29
---

# Summary

Implemented Protocol-library and Today-scheduling refinements:

- Removed direct schedule/import actions from the Protocol page.
- Reduced Protocol page title weight by removing the large navigation title.
- Added Protocol source extraction entry points for literature, kit manuals, and SOPs.
- Added editable formula variables and step-variable associations.
- Added local consistency checks for ingredient totals, undefined step variables, duplicate variables, and duration-backed variables.
- Added Protocol sharing affordance.
- Moved scheduling into Today empty time slots with a Protocol scheduling sheet.

## Verification

- `make preflight` passed with Xcode 26.5.
- XcodeBuildMCP `build_run_sim` passed on iPhone 17 Pro Simulator.
- XcodeBuildMCP `snapshot_ui` confirmed Today empty time slots and running UI.
