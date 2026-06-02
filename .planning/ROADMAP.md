# Roadmap: LabBuddy

## Overview

LabBuddy v1 builds from a native local iOS foundation into the core bench-side loop: reusable Protocols, automatic scaling, daily scheduling, reliable multi-timers, completion records, inventory deduction, and shareable Data Cards. The roadmap deliberately avoids accounts, cloud sync, Android, AI, and full ELN/LIMS scope so the first milestone can validate the mobile wet-lab execution experience.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [ ] **Phase 1: iOS Local Foundation** - Native app shell, local data foundation, and bench-first navigation.
- [ ] **Phase 2: Protocol Library** - Reusable structured Protocol templates and starter templates for the first wet-lab domains.
- [ ] **Phase 3: Scaling and Calculator Toolkit** - Scaled experiment runs, recipe snapshots, and scientific calculator tools.
- [ ] **Phase 4: Daily Schedule** - Today-focused schedule, step planning, carry-over placeholders, and conflict visibility.
- [ ] **Phase 5: Timer Execution** - Multi-channel labeled timers with local notifications and iOS Lock Screen/Dynamic Island support.
- [ ] **Phase 6: Experiment Records** - Completion metadata, run history, and post-bench editing.
- [ ] **Phase 7: Personal Inventory** - Local inventory, low-stock warnings, and transaction-based experiment deductions.
- [ ] **Phase 8: Data Cards and Share Flow** - Image attachment, annotation, academic card composition, export, and final usability polish.

## Phase Details

### Phase 1: iOS Local Foundation
**Goal**: Establish the native iOS app foundation, local data model, and today-first bench workflow shell.
**Depends on**: Nothing (first phase)
**Requirements**: [PLAT-01, PLAT-02, PLAT-03, UX-01]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can launch LabBuddy on iOS without sign-in.
  2. User data persists locally between app launches.
  3. The first screen is a today-focused bench workflow, not a desktop-style project dashboard.
  4. Core navigation and controls are large and glanceable enough for bench-side use.
**Plans**: 3 plans

Plans:
- [ ] 01-01: Create native iOS app shell and local persistence foundation.
- [ ] 01-02: Define core domain models and seed local storage.
- [ ] 01-03: Build today-first navigation and bench-side UI primitives.

### Phase 2: Protocol Library
**Goal**: Let users create reusable wet-lab Protocol templates with structured steps, recipes, tags, and starter templates.
**Depends on**: Phase 1
**Requirements**: [PROT-01, PROT-02, PROT-03, PROT-04, PROT-05]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can create, edit, duplicate, and delete Protocol templates.
  2. Protocols support ordered steps, expected durations, timer presets, metadata fields, and recipe items.
  3. User can classify Protocols by the current v1 workflow families: cell, animal, nucleic-acid, and protein experiments.
  4. User can start from starter templates for cell, animal, nucleic-acid, and protein workflows.
**Plans**: 3 plans

Plans:
- [ ] 02-01: Build Protocol CRUD and library browsing.
- [ ] 02-02: Add structured step, metadata, recipe, and domain tagging support.
- [ ] 02-03: Add starter templates for the current v1 workflow families.

### Phase 3: Scaling and Calculator Toolkit
**Goal**: Convert Protocol templates into scaled experiment runs and provide core bench calculation tools.
**Depends on**: Phase 2
**Requirements**: [SCAL-01, SCAL-02, SCAL-03, SCAL-04, CALC-01, CALC-02, CALC-03, CALC-04]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can create a run from a Protocol using target volume, sample count, or scale factor.
  2. User can review scale factor and scaled recipe quantities before scheduling.
  3. Scaled recipe snapshots are preserved with the run.
  4. User can complete mass, dilution, and percent concentration calculations and reuse or copy results.
**Plans**: 4 plans

Plans:
- [ ] 03-01: Implement deterministic scaling and unit calculation services.
- [ ] 03-02: Build scaled run creation and review UI.
- [ ] 03-03: Persist scaled recipe snapshots with experiment runs.
- [ ] 03-04: Build calculator toolkit and save/copy result flows.

### Phase 4: Daily Schedule
**Goal**: Turn scaled runs into a phone-optimized daily execution plan with carry-over placeholders and conflict visibility.
**Depends on**: Phase 3
**Requirements**: [SCHD-01, SCHD-02, SCHD-03, SCHD-04, SCHD-05, SCHD-06]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can import a scaled Protocol run into a selected day.
  2. User can view planned steps with time, duration, experiment label, and status.
  3. User can manually reorder or move scheduled steps.
  4. Carry-over placeholders and visible schedule conflicts help the user plan multi-day lab work.
**Plans**: 3 plans

Plans:
- [ ] 04-01: Build schedule data model and run import flow.
- [ ] 04-02: Build timeline/board daily schedule UI.
- [ ] 04-03: Add carry-over placeholders, manual reordering, and conflict visibility.

### Phase 5: Timer Execution
**Goal**: Provide reliable multi-channel bench timers connected to scheduled steps and visible through iOS timer surfaces.
**Depends on**: Phase 4
**Requirements**: [TIME-01, TIME-02, TIME-03, TIME-04, TIME-05, TIME-06, UX-02]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can start a labeled timer from a scheduled step with one tap.
  2. Multiple timers can run in parallel with the most urgent timer prioritized.
  3. Timer completion alerts work when the app is backgrounded or locked.
  4. Supported devices show active timer state on Lock Screen/Dynamic Island.
  5. Timer-linked steps preserve actual start/end time when completed.
**Plans**: 4 plans

Plans:
- [ ] 05-01: Implement persistent multi-timer engine.
- [ ] 05-02: Connect scheduled steps to one-tap labeled timers.
- [ ] 05-03: Add local notification completion alerts.
- [ ] 05-04: Add Live Activity/Dynamic Island support and timer completion flow.

### Phase 6: Experiment Records
**Goal**: Capture completion state, key wet-lab metadata, and run history without slowing down bench execution.
**Depends on**: Phase 5
**Requirements**: [RECD-01, RECD-02, RECD-03, RECD-04, UX-03]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can mark steps and full runs complete.
  2. User can capture key conditions such as temperature, duration, speed, volume, and notes.
  3. User can view completed run history.
  4. User can edit metadata after the bench session.
**Plans**: 3 plans

Plans:
- [ ] 06-01: Build step/run completion state and metadata capture.
- [ ] 06-02: Build run history and detail views.
- [ ] 06-03: Add post-bench editing and quick-entry cleanup flows.

### Phase 7: Personal Inventory
**Goal**: Manage personal local inventory and deduct actual scaled experiment usage through inspectable transactions.
**Depends on**: Phase 6
**Requirements**: [INVT-01, INVT-02, INVT-03, INVT-04, INVT-05, INVT-06]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can manage personal inventory items with quantities, units, thresholds, storage, and notes.
  2. User can link Protocol recipe items to inventory items.
  3. User can review expected consumption before completing a run.
  4. Completed runs create inspectable and correctable inventory transactions.
  5. Low-stock items are visibly warned.
**Plans**: 3 plans

Plans:
- [ ] 07-01: Build inventory item CRUD and low-stock warnings.
- [ ] 07-02: Link recipe items to inventory items and preview run consumption.
- [ ] 07-03: Add completion-time deductions, transaction history, and correction flow.

### Phase 8: Data Cards and Share Flow
**Goal**: Generate useful, attractive, shareable experiment result cards from real run metadata and annotated images.
**Depends on**: Phase 7
**Requirements**: [CARD-01, CARD-02, CARD-03, CARD-04, CARD-05, CARD-06]
**UI hint**: yes
**Success Criteria** (what must be TRUE):
  1. User can attach camera or library images to an experiment run.
  2. User can annotate attached images with drawing and short labels.
  3. User can generate Data Cards from selected images and actual run metadata.
  4. User can choose an academic-style layout and export/share the card as an image.
  5. Exported cards include subtle Powered by LabBuddy branding.
**Plans**: 4 plans

Plans:
- [ ] 08-01: Add experiment image attachment and local asset handling.
- [ ] 08-02: Build image annotation tools.
- [ ] 08-03: Compose Data Cards from run metadata, images, and layout styles.
- [ ] 08-04: Add share/export flow, watermark, and final v1 usability polish.

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. iOS Local Foundation | 0/3 | Not started | - |
| 2. Protocol Library | 0/3 | Not started | - |
| 3. Scaling and Calculator Toolkit | 0/4 | Not started | - |
| 4. Daily Schedule | 0/3 | Not started | - |
| 5. Timer Execution | 0/4 | Not started | - |
| 6. Experiment Records | 0/3 | Not started | - |
| 7. Personal Inventory | 0/3 | Not started | - |
| 8. Data Cards and Share Flow | 0/4 | Not started | - |
