# Phase 2: Protocol Library - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 2 defines LabBuddy's reusable Protocol library: browsing, creating, editing, duplicating, deleting, classifying, importing starter templates, and preparing structured method assets for later scaling and scheduling. The Protocol page is not the scheduling surface. Scheduling happens later from the today/tomorrow add flow.

</domain>

<decisions>
## Implementation Decisions

### Page Role
- **D-01:** The Protocol page is both a method asset library and a method extraction center.
- **D-02:** The page manages reusable Protocol templates, including steps, recipe/reagent items, variables, source information, and sharing.
- **D-03:** The page must not directly add a Protocol to today or tomorrow. Schedule import belongs to the Daily Schedule add sheet.

### Library Browsing
- **D-04:** The Protocol list uses search, experiment-type filters, and recency/favorite prioritization.
- **D-05:** Supported filters must cover at least all v1 experiment families: cell experiments, molecular cloning/plasmid workflows, and Western blot/gel workflows.
- **D-06:** Protocol cards show medium-density information: name, experiment type, expected duration, key variables, recent-use signal, and source.
- **D-07:** Cards open a detail view where the Protocol can be reviewed and edited.

### Detail And Editing Structure
- **D-08:** Protocol detail uses sections or tabs: overview, reagent recipe, steps, variables and checks, and source.
- **D-09:** Detail defaults to a readable review mode. Editing is a deliberate mode/action.
- **D-10:** In edit mode, every section can be modified.
- **D-11:** The reagent recipe section is a priority area and must be visually more prominent than ordinary descriptive text.
- **D-12:** Reagent name, amount, unit, concentration/notes, and related fields must be directly editable. This data later drives scaling, inventory deductions, and Data Card metadata.

### Method Extraction Center
- **D-13:** The Protocol page should expose import/extraction entry points for literature, kit manuals, and SOPs.
- **D-14:** The entry points should support PDF, image, and text source types at the product-flow level.
- **D-15:** v1 implements the import entry and editable structured draft flow. It must not pretend full AI auto-extraction is already available.
- **D-16:** True AI recognition/extraction can be deferred to Pro or a later version, but the UI flow should be ready: source input -> structured draft -> human confirmation -> save as Protocol.

### Variables And Consistency Checks
- **D-17:** Protocols support variables and formulas, linked to reagent recipes, step parameters, timer points, target volume, and sample count.
- **D-18:** Consistency checks should catch missing variables, undefined references, reagent-total/base-volume conflicts, and mismatches between step parameters and variable definitions.
- **D-19:** v1 should not implement a heavy rule engine with complex branching or sample matrices.

### Sharing
- **D-20:** Protocol sharing has two paths: image card sharing and structured export.
- **D-21:** The image card is for quick visual sharing in group chats or presentations.
- **D-22:** The structured export file is for importing, editing, and reusing a Protocol.
- **D-23:** Shared Protocol content should include name, experiment type, reagent recipe, steps, variables/formulas, and source information.

### the agent's Discretion
- The agent may choose exact component layout, iconography, and local data structures as long as the role boundary and reagent-first editing behavior remain true.
- The agent may decide how favorites and recent-use signals are represented in the prototype.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product And Requirements
- `.planning/PROJECT.md` — Defines LabBuddy as an iOS-first, local-first wet-lab bench productivity app.
- `.planning/REQUIREMENTS.md` — Defines Phase 2 requirements `PROT-01` through `PROT-05`.
- `.planning/ROADMAP.md` — Defines Phase 2 scope, dependencies, success criteria, and plans.

### Current Implementation Context
- `LabBuddy/ContentView.swift` — Contains the current prototype Protocol view, editor, extraction sheet, and current scheduling coupling that may need correction.
- `LabBuddy/Models.swift` — Contains current prototype models for `LabProtocol`, `ProtocolIngredient`, `ProtocolVariable`, `ProtocolSource`, and `LabStep`.
- `LabBuddy/SampleData.swift` — Contains current starter Protocols and examples for the three initial experiment families.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Existing `LabProtocol`, `ProtocolIngredient`, `ProtocolVariable`, and `ProtocolSource` models already point toward structured Protocol assets.
- Existing Protocol editor and extraction prototype can be reshaped into the decided detail/edit and draft-confirmation flow.

### Established Patterns
- SwiftUI sheet-based editing is already used and remains appropriate for focused add/edit flows.
- The app is local-first and iOS-only; no account or cloud sharing is required for v1.

### Integration Points
- Phase 3 scaling depends on recipe amount/unit/variable correctness.
- Phase 4 scheduling imports Protocol-derived runs from today/tomorrow add flows, not from the Protocol list itself.
- Phase 7 inventory deductions depend on reagent recipe structure.
- Phase 8 Data Cards depend on Protocol source, variables, and recipe metadata.

</code_context>

<specifics>
## Specific Ideas

- The user specifically wants reagent names and reagent quantities to be marked as important while editing and to be directly clickable/editable.
- The user wants Protocol extraction to reference literature, kit manuals, and SOPs through PDF/image/text entry points, while keeping automatic AI extraction deferred.

</specifics>

<deferred>
## Deferred Ideas

- Full AI extraction from literature, manuals, or images is deferred to Pro or a later version.
- Advanced formula/rule engines with complex branching or sample matrices are deferred beyond v1.
- Scheduling from Protocol cards is intentionally not part of this phase; scheduling belongs to Phase 4's add flow.

</deferred>

---

*Phase: 2-Protocol Library*
*Context gathered: 2026-05-29*
