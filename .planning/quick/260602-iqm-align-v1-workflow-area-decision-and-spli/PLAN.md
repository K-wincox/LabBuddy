# Quick Plan: align workflow areas and split ContentView

## Scope
- Update planning context so v1 workflow areas reflect the current accepted scope: cell, animal, nucleic, and protein experiments, with custom areas still supported by the model.
- Split Today-related SwiftUI code out of `ContentView.swift` without changing behavior.
- Keep `ContentView.swift` focused on app root tabs, global local state, rollover, and persistence.

## Non-goals
- No UI redesign in this step.
- No persistence migration in this step.
- No behavior changes to schedule, Protocol, tools, inventory, or Data Card flows.

## Verification
- Run `make preflight`.
- Build/run on simulator with XcodeBuildMCP if preflight passes.
