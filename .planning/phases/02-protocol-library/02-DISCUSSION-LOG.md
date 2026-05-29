# Phase 2: Protocol Library - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 2-Protocol Library
**Areas discussed:** Page role, list organization, card density, detail editing, method extraction, variables and checks, sharing

---

## Page Role

| Option | Description | Selected |
|--------|-------------|----------|
| Method asset library | Manage reusable templates, steps, variables, sources, and sharing. | ✓ |
| Experiment creation center | Add Protocols directly to today or tomorrow from the Protocol page. | |
| Method extraction center | Import methods from literature, kit manuals, and SOPs. | ✓ |

**User's choice:** Protocol is both a method asset library and method extraction center.
**Notes:** Scheduling must happen from today/tomorrow, not directly from Protocol.

---

## List Organization

| Option | Description | Selected |
|--------|-------------|----------|
| Type groups | Group by cell, cloning/plasmid, and WB/gel. | |
| Recent/favorite first | Prioritize high-frequency Protocols and use type only as metadata. | |
| Search + filters + priority | Use search, type filtering, and recent/favorite priority together. | ✓ |

**User's choice:** Search + type filters + recent/favorite priority.
**Notes:** This should scale better than static grouping as the Protocol library grows.

---

## Card Density

| Option | Description | Selected |
|--------|-------------|----------|
| Light cards | Name, type, duration, source/confidence. | |
| Medium cards | Name, type, duration, key variables, recent use, source. | ✓ |
| Heavy cards | Expanded steps, recipes, and variable check results in the list. | |

**User's choice:** Medium cards.
**Notes:** Tapping a card opens detail and edit. Reagents and reagent quantities must be a highlighted, directly editable area.

---

## Detail Editing

| Option | Description | Selected |
|--------|-------------|----------|
| One long page | Overview, reagents, steps, variables, and source in one scroll. | |
| Segmented detail | Overview, reagent recipe, steps, variables/checks, and source sections. | ✓ |
| Separate read/edit mode | Default readable view, then explicit edit mode. | ✓ |

**User's choice:** Segmented detail plus explicit read/edit modes.
**Notes:** Reagent recipe is the priority editing area. Reagent name, amount, unit, and concentration/note fields must be directly editable.

---

## Method Extraction

| Option | Description | Selected |
|--------|-------------|----------|
| Manual text only | Paste text and manually structure it. | |
| PDF/image/text sources | Support source entry points for files, images, and text. | ✓ |
| Draft UI with AI deferred | Build import and editable draft flow now; AI extraction later. | ✓ |

**User's choice:** PDF/image/text source entry points plus editable draft UI, with true AI extraction deferred.
**Notes:** v1 should not pretend automatic AI extraction is complete.

---

## Variables And Checks

| Option | Description | Selected |
|--------|-------------|----------|
| Simple checks | Total amount and step duration presence only. | |
| Variable system | Variables/formulas linked to reagents, steps, timers, target volume, and sample count. | ✓ |
| Rule engine | Complex conditional rules and sample matrices. | |

**User's choice:** Variable system.
**Notes:** Checks should catch missing variables, undefined references, reagent-total/base-volume conflicts, and step-parameter mismatches.

---

## Sharing

| Option | Description | Selected |
|--------|-------------|----------|
| Text only | Share plain text Protocol instructions. | |
| Structured only | Export/import a reusable Protocol file. | |
| Image + structured export | Share a visual card and an importable structured file. | ✓ |

**User's choice:** Image card plus structured export.
**Notes:** Shared content includes name, type, reagents, steps, variables/formulas, and source information.

## the agent's Discretion

- The agent may choose exact visual layout and local model details while preserving Protocol as method asset library plus extraction center.

## Deferred Ideas

- True AI extraction is deferred to Pro or a later version.
- Advanced formula/rule engines are deferred beyond v1.
- Direct scheduling from Protocol cards is deferred/avoided in favor of Phase 4's add flow.
