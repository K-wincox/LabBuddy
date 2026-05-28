# Architecture Research: LabBuddy

**Date:** 2026-05-28
**Scope:** Product and data architecture for v1.

## Recommended Component Boundaries

| Component | Responsibility |
|-----------|----------------|
| Protocol Library | Store reusable Protocols, structured steps, reagent recipes, timing metadata, and domain tags. |
| Scaling Engine | Convert base recipe quantities to run-specific quantities by target volume, sample count, or scale factor. |
| Schedule Engine | Turn Protocol runs into dated tasks and step instances; place carry-over steps across days. |
| Timer Engine | Manage active timers, local notification scheduling, Live Activity state, and timer completion records. |
| Experiment Record Store | Persist actual run metadata, step completion, notes, images, and Data Card inputs. |
| Inventory Engine | Store personal inventory and apply deduction transactions from completed run usage. |
| Calculator Toolkit | Pure calculation services for mass concentration, dilution, and percent concentration. |
| Data Card Composer | Compose annotated image(s) plus structured run metadata into an exportable share card. |

## Core Data Model Sketch

- `ProtocolTemplate`
  - title, domain, baseScale, notes, version
  - steps: `[ProtocolStepTemplate]`
  - reagents: `[RecipeItemTemplate]`
- `ProtocolStepTemplate`
  - order, title, instruction, expectedDuration, timerPreset, metadataFields, carryOverRule
- `RecipeItemTemplate`
  - reagentName, baseAmount, unit, concentration, inventoryLinkCandidate
- `ExperimentRun`
  - protocolTemplate, runDate, targetScale, status, scaledRecipeSnapshot
- `ScheduledStep`
  - experimentRun, plannedStart, plannedEnd, actualStart, actualEnd, status
- `LabTimer`
  - scheduledStep, label, duration, startedAt, endsAt, status
- `InventoryItem`
  - name, category, unit, currentQuantity, lowStockThreshold, storage, lot, vendor
- `InventoryTransaction`
  - item, experimentRun, amount, type, timestamp, note
- `ExperimentAsset`
  - experimentRun, imageReference, annotations, caption
- `DataCard`
  - experimentRun, assets, includedMetadata, style, exportedAt

## Data Flow

1. User creates or selects a Protocol.
2. User inputs target volume/sample count/scale.
3. Scaling Engine creates a scaled recipe snapshot.
4. User imports the run into Daily Schedule.
5. Schedule Engine creates step instances and carry-over placeholders.
6. User executes steps and starts timers.
7. Timer Engine schedules notifications and updates Live Activity state.
8. Completion records save actual timings and metadata.
9. Inventory Engine deducts usage from the scaled recipe snapshot.
10. User attaches/annotates images.
11. Data Card Composer exports a shareable image using run metadata.

## Build Order Implications

1. Local data model and Protocol/scaling foundation must come before scheduling, timers, inventory deduction, and Data Cards.
2. Timer/notification reliability should be validated before polishing schedule UI.
3. Data Cards require stable experiment metadata snapshots; avoid building them as freeform image templates disconnected from Protocol runs.
4. Inventory deduction should be transaction-based so users can inspect or undo deductions.
5. Carry-over scheduling should start simple: explicit next-step placeholders before full optimization.

## Local-First Constraints

- All user data should remain on device in v1.
- Images should be stored as local file references or app-managed assets, not embedded blindly into every SwiftData object.
- Exported Data Cards should be shareable through iOS share sheet without cloud dependency.
- Backups/import/export can be deferred, but the data model should not prevent future export.

## Sources

- Apple SwiftData documentation: https://developer.apple.com/documentation/SwiftData
- Apple ActivityKit documentation: https://developer.apple.com/documentation/ActivityKit/
- Apple local notifications guide: https://developer.apple.com/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app
- Benchling Inventory: https://www.benchling.com/inventory
- LabArchives Inventory List: https://help.labarchives.com/hc/en-us/articles/16361218867988-Inventory-List
