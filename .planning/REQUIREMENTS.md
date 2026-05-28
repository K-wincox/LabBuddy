# Requirements: LabBuddy

**Defined:** 2026-05-28
**Core Value:** Wet-lab researchers can reliably execute and report daily experiments from their phone without losing track of protocols, timings, scaled reagent amounts, or key experimental metadata.

## v1 Requirements

### Platform and Local Data

- [ ] **PLAT-01**: User can use LabBuddy as an iOS-only app with no account sign-in.
- [ ] **PLAT-02**: User's Protocols, schedules, timers, inventory, experiment records, images, and Data Cards are stored locally on device.
- [ ] **PLAT-03**: User can open the app directly into a today-focused bench workflow without navigating through desktop-style project management screens.

### Protocol Library

- [ ] **PROT-01**: User can create, edit, duplicate, and delete reusable Protocol templates.
- [ ] **PROT-02**: User can define Protocol steps with ordered instructions, expected duration, optional timer preset, and key metadata fields.
- [ ] **PROT-03**: User can define Protocol recipe items with amount, unit, concentration note, and optional inventory item link.
- [ ] **PROT-04**: User can tag a Protocol as cell experiment, molecular cloning/plasmid workflow, Western blot/gel workflow, or general.
- [ ] **PROT-05**: User can start from starter templates for cell experiments, molecular cloning/plasmid workflows, and Western blot/gel workflows.

### Scaling and Calculations

- [ ] **SCAL-01**: User can create an experiment run from a Protocol by entering target volume, sample count, or direct scale factor.
- [ ] **SCAL-02**: User can review the calculated scale factor before importing a run into the schedule.
- [ ] **SCAL-03**: User can view scaled recipe quantities for every Protocol recipe item.
- [ ] **SCAL-04**: User can store the scaled recipe snapshot with the experiment run so later inventory and Data Card metadata match the actual run.
- [ ] **CALC-01**: User can calculate mass from molecular weight, target concentration, and total volume.
- [ ] **CALC-02**: User can calculate liquid dilution volumes using C1V1 = C2V2.
- [ ] **CALC-03**: User can calculate w/v and v/v percentage recipes.
- [ ] **CALC-04**: User can copy a calculator result as text or save it as a new Protocol draft.

### Daily Schedule

- [ ] **SCHD-01**: User can import a scaled Protocol run into a selected day.
- [ ] **SCHD-02**: User can view the selected day's experiment work in a timeline or board optimized for phone use.
- [ ] **SCHD-03**: User can see each scheduled step's planned time, duration, experiment label, and status.
- [ ] **SCHD-04**: User can manually move or reorder scheduled steps.
- [ ] **SCHD-05**: User can create carry-over placeholders for future or next-day steps such as overnight incubation, cell passaging, antibody incubation, or imaging.
- [ ] **SCHD-06**: User can see visible conflicts or overlaps between scheduled steps and manually resolve them.

### Timer Execution

- [ ] **TIME-01**: User can start a labeled timer directly from a scheduled step with one tap.
- [ ] **TIME-02**: User can run multiple labeled timers in parallel.
- [ ] **TIME-03**: User can see active timers inside the app with the most urgent timer visually prioritized.
- [ ] **TIME-04**: User receives local notification alerts when timers complete while the app is backgrounded or locked.
- [ ] **TIME-05**: User can see active timer state on iOS Lock Screen/Dynamic Island where supported.
- [ ] **TIME-06**: User can mark a timer-linked step complete and preserve actual start/end time.

### Experiment Records

- [ ] **RECD-01**: User can mark experiment steps and full runs as complete.
- [ ] **RECD-02**: User can record key condition metadata for a run or step, including temperature, duration, speed, volume, and freeform note.
- [ ] **RECD-03**: User can view a run history for completed experiments.
- [ ] **RECD-04**: User can edit completion metadata after the bench session if a quick entry was incomplete.

### Inventory

- [ ] **INVT-01**: User can create, edit, and delete personal inventory items with name, category, unit, current quantity, low-stock threshold, storage location, and optional lot/vendor note.
- [ ] **INVT-02**: User can link Protocol recipe items to inventory items.
- [ ] **INVT-03**: User can review expected inventory consumption before completing an experiment run.
- [ ] **INVT-04**: User can automatically deduct inventory through transaction records when an experiment run is completed.
- [ ] **INVT-05**: User can inspect and correct inventory transactions.
- [ ] **INVT-06**: User can see low-stock warnings for inventory items below their configured threshold.

### Images and Data Cards

- [ ] **CARD-01**: User can attach experiment images from camera or photo library to an experiment run.
- [ ] **CARD-02**: User can annotate attached images with finger-drawn marks and short text labels.
- [ ] **CARD-03**: User can generate a Data Card that combines selected image(s), Protocol name, run date/time, key conditions, scaled recipe metadata, and notes.
- [ ] **CARD-04**: User can choose from a small set of academic-style Data Card layouts.
- [ ] **CARD-05**: User can export/share a Data Card as an image through the iOS share sheet.
- [ ] **CARD-06**: Generated Data Cards include a subtle "Powered by LabBuddy" watermark.

### Bench-Side Usability

- [ ] **UX-01**: Core bench actions use large, glanceable controls suitable for gloved or time-pressured use.
- [ ] **UX-02**: Starting timers, marking steps complete, and viewing next steps can be done with minimal typing.
- [ ] **UX-03**: The app supports quick entry during an experiment and later cleanup/editing after the bench session.

## v2 Requirements

### AI and Pro Features

- **AI-01**: User can speak or type a natural-language scheduling request and have AI propose a daily schedule.
- **AI-02**: User can generate mentor-report copy from a completed Data Card.
- **AI-03**: User can choose report tone such as good-news update or help-needed update.
- **PRO-01**: User can store unlimited Protocols beyond free-tier limits.
- **PRO-02**: User can use cloud storage or sync for experiment assets.

### Future Platform and Collaboration

- **SYNC-01**: User can sync data across devices.
- **TEAM-01**: Users in the same lab can share inventory or Protocol libraries.
- **ORDR-01**: User can create purchasing reminders or order requests from low-stock warnings.
- **ANDR-01**: User can use an Android version of LabBuddy.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Account system in v1 | v1 is a local personal tool and should avoid auth/sync complexity. |
| Cloud sync in v1 | Local-first validation is more important than infrastructure. |
| Android app in v1 | iOS-specific lock-screen and Dynamic Island timer UX is central to the first release. |
| Full ELN notebook authoring | LabBuddy is a bench execution app, not a full notebook replacement. |
| Full LIMS/sample lineage | Too heavy for the mobile-first individual workflow. |
| Team permissions and shared lab admin | v1 focuses on personal productivity. |
| Barcode scanning and instrument integrations | Useful later, but not required for the first Protocol -> Timer -> Data Card loop. |
| AI voice scheduling in v1 | Deferred Pro capability after manual scheduling is validated. |
| AI mentor-report assistant in v1 | Deferred Pro capability after Data Cards are validated. |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAT-01 | TBD | Pending |
| PLAT-02 | TBD | Pending |
| PLAT-03 | TBD | Pending |
| PROT-01 | TBD | Pending |
| PROT-02 | TBD | Pending |
| PROT-03 | TBD | Pending |
| PROT-04 | TBD | Pending |
| PROT-05 | TBD | Pending |
| SCAL-01 | TBD | Pending |
| SCAL-02 | TBD | Pending |
| SCAL-03 | TBD | Pending |
| SCAL-04 | TBD | Pending |
| CALC-01 | TBD | Pending |
| CALC-02 | TBD | Pending |
| CALC-03 | TBD | Pending |
| CALC-04 | TBD | Pending |
| SCHD-01 | TBD | Pending |
| SCHD-02 | TBD | Pending |
| SCHD-03 | TBD | Pending |
| SCHD-04 | TBD | Pending |
| SCHD-05 | TBD | Pending |
| SCHD-06 | TBD | Pending |
| TIME-01 | TBD | Pending |
| TIME-02 | TBD | Pending |
| TIME-03 | TBD | Pending |
| TIME-04 | TBD | Pending |
| TIME-05 | TBD | Pending |
| TIME-06 | TBD | Pending |
| RECD-01 | TBD | Pending |
| RECD-02 | TBD | Pending |
| RECD-03 | TBD | Pending |
| RECD-04 | TBD | Pending |
| INVT-01 | TBD | Pending |
| INVT-02 | TBD | Pending |
| INVT-03 | TBD | Pending |
| INVT-04 | TBD | Pending |
| INVT-05 | TBD | Pending |
| INVT-06 | TBD | Pending |
| CARD-01 | TBD | Pending |
| CARD-02 | TBD | Pending |
| CARD-03 | TBD | Pending |
| CARD-04 | TBD | Pending |
| CARD-05 | TBD | Pending |
| CARD-06 | TBD | Pending |
| UX-01 | TBD | Pending |
| UX-02 | TBD | Pending |
| UX-03 | TBD | Pending |

**Coverage:**
- v1 requirements: 47 total
- Mapped to phases: 0
- Unmapped: 47

---
*Requirements defined: 2026-05-28*
*Last updated: 2026-05-28 after initial definition*
