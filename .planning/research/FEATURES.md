# Feature Research: LabBuddy

**Date:** 2026-05-28
**Scope:** v1 feature expectations for a bench-side wet-lab iOS app.

## Table Stakes for v1

### Protocol Execution

- Reusable Protocol templates with structured steps, reagents, expected durations, and metadata fields.
- Step checklist/run mode so a Protocol can be executed rather than merely read.
- Protocol scaling from a standard recipe to a run-specific target volume, sample count, or scale factor.
- Domain-aware starter templates for cell, animal, nucleic-acid, and protein workflows.

### Daily Schedule

- Today-first timeline or board showing active, upcoming, blocked, and completed experiment work.
- Ability to import a scaled Protocol into today's plan.
- Carry-over placeholders for multi-day steps such as overnight incubation, cell passaging, antibody incubation, or next-day imaging.
- Manual conflict visibility when two steps overlap or a timer would end during a blocked time window.

### Timers

- One-tap timer start from a scheduled step.
- Multiple labeled timers at once.
- Lock-screen/Dynamic Island presentation for the most urgent active timer.
- Local notifications for timer completion with experiment/step name included.

### Records and Data Cards

- Completion records that capture actual start/end time, duration, temperature, speed, volume, and notes.
- Attach photo evidence such as gel, blot, fluorescence, or culture images.
- Finger annotation and text labels on images.
- Data Card export that combines image, core conditions, timestamps, and Protocol/scaling metadata into a shareable image.

### Inventory and Calculators

- Personal local inventory items with name, unit, current quantity, low-stock threshold, and optional lot/vendor/storage notes.
- Inventory deduction from completed runs based on actual scaled usage.
- Buffer/calculation toolbox for mass concentration, C1V1 dilution, and percentage concentration.
- Ability to save a calculated recipe as a Protocol or copy/share calculation text.

## Differentiators

- Bench-first interaction design: large touch targets, fast step/timer access, minimal typing.
- Data Card as a viral and practical reporting artifact.
- Protocol scaling connected to inventory deduction and Data Card metadata, not isolated calculators.
- Multi-day dependency placeholders for wet-lab reality.

## Deferred / Pro

- AI voice schedule parsing.
- AI mentor-report copy generation.
- Cloud storage and cross-device sync.
- Unlimited Protocol storage and advanced asset management.
- Team/lab inventory or shared ordering workflow.

## Anti-Features

- Full electronic lab notebook authoring in v1.
- Full LIMS/sample lineage/compliance audit trails.
- Team permission models.
- Barcode/scanner/instrument integrations.
- Deep regulatory compliance workflows.

## Competitive/Adjacent Product Notes

Protocols.io emphasizes protocol creation, sharing, and running protocols as checklists. LabBuddy should borrow the run/checklist mental model but avoid becoming a protocol publication platform.

LabArchives and Benchling connect inventory usage to experiment context and usage history. LabBuddy should keep that linkage at personal-local scale: "this experiment used these quantities" rather than enterprise sample management.

## Sources

- protocols.io features: https://www.protocols.io/features
- Benchling Inventory: https://www.benchling.com/inventory
- LabArchives Inventory List: https://help.labarchives.com/hc/en-us/articles/16361218867988-Inventory-List
- LabArchives product overview: https://www.labarchives.com/
