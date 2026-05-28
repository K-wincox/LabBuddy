# Pitfalls Research: LabBuddy

**Date:** 2026-05-28
**Scope:** Common failure modes for v1 planning.

## Pitfall 1: Becoming a Heavy ELN/LIMS

**Risk:** The product absorbs notebook authoring, team permissions, compliance, barcode workflows, and lab management until the bench-side mobile value disappears.

**Prevention:** Keep v1 centered on execution and reporting loops. Records are structured run metadata plus images, not full notebook pages.

**Phase impact:** Requirements and roadmap must explicitly exclude full ELN/LIMS behavior.

## Pitfall 2: Treating Timers as Simple UI State

**Risk:** Timers fail when the app backgrounds, the phone locks, or multiple timers overlap.

**Prevention:** Timer state must be persisted. Completion alerts must use UserNotifications. Live Activities are presentation, not the only timer mechanism.

**Phase impact:** Timer reliability should be a dedicated phase with manual device testing.

## Pitfall 3: Overtrusting Live Activities

**Risk:** Live Activities have duration, payload, presentation, and availability constraints. They are not a full always-on dashboard for every overnight lab task.

**Prevention:** Use Live Activities for currently active bench work and urgent timers; use scheduled notifications and schedule state for long carry-over tasks.

**Phase impact:** The lock-screen feature should be scoped to active timers, not every scheduled experiment.

## Pitfall 4: Recipe Scaling Without Units Discipline

**Risk:** Automatic scaling becomes dangerous if units, concentrations, final volumes, and sample counts are ambiguous.

**Prevention:** v1 should support a controlled set of units and scaling modes, show the scale factor, and store the scaled snapshot used for a run.

**Phase impact:** Calculator/scaling services need tests before UI polish.

## Pitfall 5: Inventory Deductions That Users Cannot Trust

**Risk:** Automatic deduction annoys users if they cannot inspect, adjust, or undo it.

**Prevention:** Deduct through explicit transactions, show the amount, and allow correction.

**Phase impact:** Inventory can start with simple personal stock and transaction history; avoid team purchasing logic.

## Pitfall 6: Data Cards Detached from Real Metadata

**Risk:** Data Cards become pretty image templates but do not answer mentor follow-up questions.

**Prevention:** Cards must pull from the actual run snapshot: Protocol name, date/time, key conditions, scaled reagent usage, and notes.

**Phase impact:** Data Card work depends on experiment record metadata.

## Pitfall 7: Too Much Typing at the Bench

**Risk:** Researchers wearing gloves will abandon workflows that require long forms during execution.

**Prevention:** Use templates, defaults, large controls, quick completion, optional later editing, and minimal mandatory fields.

**Phase impact:** Every phase with UI must include bench-side ergonomics as success criteria.

## Sources

- Apple Live Activities guide: https://developer.apple.com/documentation/ActivityKit/displaying-live-data-with-live-activities
- Apple local notifications guide: https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app
- LabArchives Inventory List: https://help.labarchives.com/hc/en-us/articles/16361218867988-Inventory-List
- protocols.io features: https://www.protocols.io/features
