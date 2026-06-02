# Summary

## Changed

- Added a bench-mode entry button to the run detail sheet.
- Replaced the old nested full-screen sheet with an internal `BenchModeView` detail/full mode toggle.
- Added mode-toggle buttons so bench detail mode and full-screen mode can switch back and forth directly.
- Constrained full-screen mode text to a safe content width with wrapping and scale limits to prevent off-screen overflow.
- Removed the old unused `FullBenchModeView` implementation.

## Verification

- `make preflight` passed.
- `git diff --check` passed.
- XcodeBuildMCP simulator build/run and UI snapshot succeeded.
- XcodeBuildMCP stop reported the simulator was already shut down.
