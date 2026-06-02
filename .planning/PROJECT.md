# LabBuddy

## What This Is

LabBuddy is an iOS-first, local-first mobile productivity app for wet-lab researchers working at the bench. It is not a heavy desktop LIMS or ELN; it focuses on the high-frequency moments when a researcher is wearing gloves, juggling steps, timers, calculations, and quick reporting.

The product connects Protocol preparation, automatic recipe scaling, daily scheduling, multi-channel timers, lightweight execution records, inventory-aware consumption, buffer calculations, and shareable result cards into one bench-side loop: prepare -> execute -> record -> report.

## Core Value

Wet-lab researchers can reliably execute and report daily experiments from their phone without losing track of protocols, timings, scaled reagent amounts, or key experimental metadata.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] User can store reusable wet-lab Protocols for the current v1 supported experiment families: cell experiments, animal experiments, nucleic-acid experiments, and protein experiments.
- [ ] User can call a Protocol with a different target volume or scale and automatically calculate adjusted reagent amounts from the standard recipe.
- [ ] User can import a scaled Protocol into a daily experiment schedule.
- [ ] Daily Schedule can show planned experiments on a timeline or board, including carried-over operations from previous or future days.
- [ ] User can start labeled timers directly from scheduled experiment steps.
- [ ] Multiple timers can run in parallel and remain understandable when the phone is locked or in a bench-side always-on view.
- [ ] User can mark experiment steps or experiments complete and retain structured metadata such as time, temperature, centrifuge speed, duration, and actual reagent usage.
- [ ] User can generate a result Data Card that combines experiment images, annotations, timestamps, conditions, and scaled usage metadata.
- [ ] User can use a built-in calculator for mass concentration, liquid dilution, and percentage concentration calculations.
- [ ] User can manage personal reagent and consumable inventory locally, with low-stock warnings.
- [ ] User can deduct inventory consumption from completed experiments based on the actual scaled reagent amounts.
- [ ] v1 runs as a pure local personal tool with no account requirement and no cloud sync.
- [ ] v1 targets iOS only.

### Out of Scope

- Android app — iOS-only first version keeps the lock-screen, Live Activity/Dynamic Island, and always-on timer experience focused.
- Account system and cloud sync — first version is a local personal tool; sync and collaboration add privacy, infrastructure, and subscription complexity.
- Desktop-first LIMS/ELN workflows — LabBuddy is intentionally bench-side and lightweight rather than a full lab management platform.
- Broad support for every wet-lab domain — v1 is limited to cell experiments, animal experiments, nucleic-acid experiments, and protein experiments, with custom local areas available for personalization.
- AI voice scheduling in v1 — valuable Pro capability, but deferred until the manual scheduling loop is proven.
- AI mentor-report assistant in v1 — valuable Pro capability, but deferred until Data Cards and metadata capture are proven.
- Team inventory, shared lab purchasing, and admin approval flows — v1 focuses on the individual researcher's personal bench workflow.

## Context

Wet-lab researchers often use fragmented tools at the bench: paper or PDF Protocols, phone alarms, calculator apps, notes, camera roll images, WeChat messages to mentors, and separate reagent tracking. The highest-friction moments happen during execution rather than long-form writing: scaling recipes, remembering overlapping timers, checking what step comes next, recording conditions, and sending enough context with a result image.

LabBuddy should treat the phone as the first production tool for bench-side work. The experience should be quick, glanceable, and forgiving when the user is wearing gloves or switching between experiments. The product should avoid turning into a slow form-heavy system.

The current v1 supported experiment families are:

- Cell experiments, such as culture media preparation, passaging, treatment schedules, incubation, and carry-over reminders.
- Animal experiments, such as dosing, sampling, observation, and multi-day carry-over operations.
- Nucleic-acid experiments, such as extraction, digestion/ligation, transformation, PCR, and sequencing-prep style steps.
- Protein experiments, such as gel running, transfer, blocking, antibody incubation, washing, imaging, and gel result sharing.

The v1 product intentionally includes both loops:

- Execution loop: Protocol -> automatic scaling -> Daily Schedule -> Timer -> completion record.
- Reporting loop: Protocol/metadata -> image capture and annotation -> Data Card -> shareable mentor update.

## Constraints

- **Platform**: iOS only for v1 — lock-screen timers, Live Activities/Dynamic Island, notification behavior, camera annotation, and local storage can be designed deeply for one platform first.
- **Data model**: Local-first personal data — no account, cloud sync, or team collaboration in v1.
- **AI scope**: AI features are Pro and post-v1 — manual scheduling and template-based reporting must work before AI voice scheduling or AI report generation.
- **Domain scope**: First release supports the current v1 experiment families — cell experiments, animal experiments, nucleic-acid experiments, and protein experiments.
- **Interaction design**: Bench-side mobile use — core actions must be fast, large enough for gloved use, and readable under time pressure.
- **Business model**: Free/Pro split should preserve basic utility while reserving high-intensity workflow accelerators for Pro.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Build LabBuddy as a mobile bench-side tool, not a desktop LIMS/ELN | The key user pain is high-frequency wet-lab execution while standing at the bench | — Pending |
| Support both execution and reporting loops in v1 | The product needs both daily utility and the viral Data Card sharing hook | — Pending |
| Limit first supported domains to cell experiments, animal experiments, nucleic-acid experiments, and protein experiments | The app has converged on these v1 workflow families after iteration; custom areas remain available for local personalization | — Pending |
| Make v1 iOS only | iOS enables a strong lock-screen, Live Activity/Dynamic Island, notification, and camera workflow | — Pending |
| Keep first version local-only | Avoids account, sync, privacy, and infrastructure complexity while validating personal workflow value | — Pending |
| Defer AI voice scheduling and AI mentor reports to Pro/post-v1 | AI is compelling but should not block validation of manual scheduling, timers, metadata, and Data Cards | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `$gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `$gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-05-28 after initialization*
