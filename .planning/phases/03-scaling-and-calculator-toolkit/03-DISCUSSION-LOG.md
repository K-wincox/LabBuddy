# Phase 3: Scaling and Calculator Toolkit - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 3-Scaling and Calculator Toolkit
**Areas discussed:** Tool set, result handling, layout, recent records, templates, input experience

---

## Tool Set

| Option | Description | Selected |
|--------|-------------|----------|
| Basic calculators | Mass concentration, liquid dilution, and percentage concentration only. | |
| Calculators + templates | Basic calculators plus common buffer/culture-medium templates. | |
| Calculators + templates + recent records | Basic calculators, templates, and recent calculation history. | ✓ |

**User's choice:** Include basic calculators, common templates, and recent calculation records.
**Notes:** The tools page should feel like a bench calculator and reusable recipe entry point.

---

## Result Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Copy only | Results can only be copied as text. | |
| Copy + Protocol draft | Results can be copied and saved as Protocol drafts. | ✓ |
| Copy + draft + schedule | Results can also be added directly to today/tomorrow. | |

**User's choice:** Copy and save as Protocol draft.
**Notes:** The tools page should not directly schedule work; scheduling belongs to today/tomorrow.

---

## Layout

| Option | Description | Selected |
|--------|-------------|----------|
| Stacked calculators | Put all calculators on one page. | |
| Segmented calculator | Switch calculator modes at the top of one page. | |
| Toolbox home | Home shows recent records, templates, and tool list; each tool opens separately. | ✓ |

**User's choice:** Toolbox home.
**Notes:** This fits the expanded scope better than a single segmented calculator.

---

## Recent Records

| Option | Description | Selected |
|--------|-------------|----------|
| Manual save | User taps save to keep calculation records. | |
| Auto save with delete/clear | Valid calculations save automatically; user can delete one or clear all. | ✓ |
| No records | Do not store calculation history. | |

**User's choice:** Auto save with delete/clear.
**Notes:** Tapping a record should restore the input parameters.

---

## Templates

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed view-only templates | User can view and copy static recipes. | |
| Scalable templates | User enters target volume and gets scaled quantities. | |
| Scalable templates + Protocol draft | Scalable templates can be copied and saved as Protocol drafts. | ✓ |

**User's choice:** Scalable templates with Protocol draft save.
**Notes:** Templates can act as lightweight Protocol sources.

---

## Input Experience

| Option | Description | Selected |
|--------|-------------|----------|
| Strict fields | Require fully structured fields up front. | |
| Fast shorthand only | Parse common shorthand as the main interaction. | |
| Fast input + precise fields | Default to shorthand, with expandable exact fields and confirmation. | ✓ |

**User's choice:** Fast input plus precise fields.
**Notes:** Parsed values must be visible and editable. Ambiguous input must ask for confirmation instead of silently calculating.

## the agent's Discretion

- The agent may decide exact parsing implementation, initial template list, and calculator screen layout as long as values remain visible and testable.

## Deferred Ideas

- Direct scheduling from tools is deferred/avoided.
- Complex natural-language parsing beyond common shorthand is deferred.
