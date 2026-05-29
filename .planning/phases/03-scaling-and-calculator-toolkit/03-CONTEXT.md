# Phase 3: Scaling and Calculator Toolkit - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 3 defines deterministic Protocol scaling, scaled recipe snapshots, and the bench-side calculator toolkit. The tools page should behave as an experiment-bench calculator and reusable recipe entry point. It can save useful calculations as Protocol drafts, but it must not directly schedule work into today or tomorrow.

</domain>

<decisions>
## Implementation Decisions

### Tools Page Role
- **D-01:** The tools page is an experiment-bench calculator plus reusable recipe entry point, not a miscellaneous utility drawer.
- **D-02:** The tools page must not directly add items to today or tomorrow. Scheduling remains owned by the Daily Schedule add flow.

### Tool Set
- **D-03:** The tools page includes mass concentration, liquid dilution, and percentage concentration calculators.
- **D-04:** The tools page also includes common buffer and culture-medium recipe templates.
- **D-05:** The tools page includes recent calculation history.

### Result Handling
- **D-06:** Calculation results can be copied as text.
- **D-07:** Calculation results can be saved as Protocol drafts.
- **D-08:** Results do not directly become scheduled work; a user must schedule from today/tomorrow.

### Page Layout
- **D-09:** The tools landing screen is a toolbox home, not one long stacked calculator page.
- **D-10:** The toolbox home includes recent calculation records, common templates, and a tool list.
- **D-11:** Each concrete calculator opens into its own focused screen with clear inputs, result display, and copy/save actions.

### Recent Calculations
- **D-12:** Valid calculations are saved automatically to recent history.
- **D-13:** Users can delete individual calculation records.
- **D-14:** Users can clear all recent calculations.
- **D-15:** Tapping a recent record restores its input parameters for repeat calculation.

### Buffer And Medium Templates
- **D-16:** Buffer and culture-medium templates are scalable by target volume.
- **D-17:** Templates show scaled reagent quantities.
- **D-18:** Template results can be copied as text.
- **D-19:** Template results can be saved as Protocol drafts.

### Input Experience
- **D-20:** Calculators default to fast input that accepts common bench shorthand, such as `50mM 100ml`, `1M -> 50mM 100ml`, or `5% milk 20ml`.
- **D-21:** Each calculator also provides expandable precise fields for values such as molecular weight, stock concentration, target concentration, target volume, and unit.
- **D-22:** Parsed values must be visible and editable before relying on the result.
- **D-23:** If shorthand parsing is ambiguous, the app must ask the user to confirm instead of silently calculating.

### the agent's Discretion
- The agent may choose exact parsing implementation and calculator screen layout, provided deterministic calculation services remain testable and user-visible values are confirmable.
- The agent may decide the initial set of common buffer/medium templates, biased toward the v1 wet-lab domains.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product And Requirements
- `.planning/PROJECT.md` — Defines LabBuddy as an iOS-first, local-first wet-lab bench productivity app.
- `.planning/REQUIREMENTS.md` — Defines Phase 3 requirements `SCAL-01` through `SCAL-04` and `CALC-01` through `CALC-04`.
- `.planning/ROADMAP.md` — Defines Phase 3 scope, dependencies, success criteria, and plans.

### Current Implementation Context
- `LabBuddy/ContentView.swift` — Contains the current prototype tools page and calculator UI.
- `LabBuddy/Models.swift` — Contains current Protocol and run models that saved Protocol drafts must connect to.
- `LabBuddy/SampleData.swift` — Contains current calculator examples and starter Protocol data.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Current calculator mode enum and simple calculator fields can be reused inside focused calculator screens.
- Current Protocol models can support saving a calculation or scalable template as a Protocol draft once draft status is modeled.

### Established Patterns
- SwiftUI segmented controls are useful inside focused calculator screens, but the tools landing page should be a toolbox home.
- Deterministic scientific calculations should remain separated enough to be unit-testable.

### Integration Points
- Saved Protocol drafts feed Phase 2's Protocol library.
- Scaled template results feed Phase 3's scaled recipe snapshot behavior.
- Scheduling remains a Phase 4 concern.

</code_context>

<specifics>
## Specific Ideas

- Recent calculations should be automatic, not manually saved.
- Fast shorthand input is useful only if the parsed values are visible, confirmable, and editable.
- Buffer and culture-medium templates should behave like lightweight Protocol sources.

</specifics>

<deferred>
## Deferred Ideas

- Directly adding a calculator result to today or tomorrow is deferred/avoided; scheduling belongs to Phase 4.
- Complex natural-language calculator parsing beyond common shorthand can be deferred.

</deferred>

---

*Phase: 3-Scaling and Calculator Toolkit*
*Context gathered: 2026-05-29*
