# Phase 4: Daily Schedule - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 4 defines the local daily schedule model and phone-first timeline behavior for LabBuddy. It covers importing scaled runs into selected days, showing today and tomorrow as editable daily timelines, handling carry-over placeholders, surfacing overlaps, and defining how day rollover should work. It does not implement full experiment record editing, images, inventory deduction, timers, or Data Cards, though it must leave clean integration points for those later phases.

</domain>

<decisions>
## Implementation Decisions

### Three-Segment Day Model
- **D-01:** The Today tab's top switch is `过去 / 今天 / 明天`.
- **D-02:** `过去` is a complete calendar-style historical view, but selectable dates must be limited to days before today. It must not include today or tomorrow because those have dedicated segments.
- **D-03:** `今天` is the current day's formal execution timeline. It includes planned, executing, completed, canceled, and unfinished work so the researcher can see the full day at the bench.
- **D-04:** `明天` uses the same formal schedule model as today, only for tomorrow's date. It is not merely a draft or weak plan.

### Day Rollover
- **D-05:** The app must not secretly roll dates at 00:00 or 05:00.
- **D-06:** The primary rollover action is a user-controlled `结束今天` action in the today timeline.
- **D-07:** When the user chooses `结束今天`, the entire current day is archived into `过去`, including unfinished, completed, and canceled experiments. Tomorrow's schedule then becomes today's schedule.
- **D-08:** If the user does not tap `结束今天` and later opens the app on a new calendar day, show a confirmation sheet asking whether to start a new day. Confirming performs the same rollover as `结束今天`; dismissing keeps the current state unchanged.
- **D-09:** `结束今天` and the "start a new day" confirmation should include a short randomized supportive message to provide emotional value after bench work.
- **D-10:** Overnight experiments should keep one experiment identity while appearing on both relevant days. The app must not duplicate them as unrelated experiments.

### Timeline Insertion and Editing
- **D-11:** Today and tomorrow timelines both support adding experiments by tapping a `+` insertion point between existing experiments.
- **D-12:** Today and tomorrow timelines also support adding experiments by tapping an empty point on the time axis.
- **D-13:** The add sheet must support three creation paths: import from Protocol, create a temporary/manual experiment operation, and add a carry-over placeholder.
- **D-14:** Newly added schedule items must be editable after creation, including planned time, title, experiment type, steps/notes, status, and overnight/carry-over flags.
- **D-15:** Time overlaps are allowed because wet-lab work is often multi-threaded. The UI must clearly mark conflicts and provide an action to shift later experiments forward.

### Past Records Boundary
- **D-16:** Past records are stable by default. Users can supplement archived days with notes, results, images, key metadata, and simple status corrections.
- **D-17:** Past records should not expose default timeline restructuring. Deep edit/correction can exist as a deliberate secondary action, and fuller history editing belongs to Phase 6.

### the agent's Discretion
- The agent may decide exact visual treatment, component naming, and local persistence mechanics as long as the decisions above are preserved.
- The agent may choose the exact supportive message set for `结束今天`, provided the tone stays warm, brief, and not childish.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product And Requirements
- `.planning/PROJECT.md` — Defines LabBuddy as an iOS-first, local-first wet-lab bench productivity app.
- `.planning/REQUIREMENTS.md` — Defines Phase 4 requirements `SCHD-01` through `SCHD-06`.
- `.planning/ROADMAP.md` — Defines Phase 4 scope, dependencies, success criteria, and plan outline.

### Current Implementation Context
- `LabBuddy/ContentView.swift` — Contains the current prototype tab shell, today/protocol/tools/profile views, schedule UI experiments, and quick-task changes that may need correction against this context.
- `LabBuddy/Models.swift` — Contains current prototype domain models such as `LabRun`, `LabStep`, and `ExperimentDayRecord`.
- `LabBuddy/SampleData.swift` — Contains current starter/sample runs and prototype historical days.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `RunCard` can remain the base presentation for scheduled experiment runs, but it must support the formal today/tomorrow timeline model and conflict/insert affordances.
- Existing sheet-based Protocol import flow can be reused for the "import from Protocol" creation path, but the add sheet must also support manual operations and carry-over placeholders.

### Established Patterns
- SwiftUI, local-first state, and iOS-only assumptions are already established.
- Current prototype state is still partly `UserDefaults` and sample-data driven; Phase 4 planning should define the correct model before hardening storage.

### Integration Points
- Schedule items created here feed Phase 5 timers, Phase 6 experiment records, Phase 7 inventory deductions, and Phase 8 Data Cards.
- Day rollover must preserve enough identity and metadata for later timer completion, record editing, inventory transaction, and Data Card generation.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly prefers a click/tap selection sheet for add actions instead of requiring typed command-like input.
- The "start a new day" reminder should be a confirmation sheet, not an invisible automatic migration.
- Supportive end-of-day copy is part of the intended bench-side emotional experience.

</specifics>

<deferred>
## Deferred Ideas

- Full post-bench record editing, rich metadata cleanup, and historical run correction are deferred to Phase 6.
- Timers, lock-screen behavior, and Live Activity/Dynamic Island surfaces are deferred to Phase 5.
- Images, annotations, and Data Card export are deferred to Phase 8.

</deferred>

---

*Phase: 4-Daily Schedule*
*Context gathered: 2026-05-29*
