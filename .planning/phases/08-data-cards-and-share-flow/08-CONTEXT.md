# Phase 8: Data Cards and Share Flow - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 8 defines LabBuddy's result card and sharing flow: image attachment, lightweight annotation, card composition from real experiment metadata, export/share, and subtle branding. Data Cards should help mentors and labmates understand results quickly while also serving as a compact personal archive artifact. This phase must not implement AI mentor-report copy.

</domain>

<decisions>
## Implementation Decisions

### Card Purpose
- **D-01:** Data Cards serve both outward sharing and personal archive use.
- **D-02:** The primary visual priority is outward sharing: mentors or labmates should understand the result and key conditions at a glance.
- **D-03:** Data Cards are not long reports and must not include AI-generated report summaries in v1.

### Card Content
- **D-04:** A Data Card includes experiment image/result imagery, experiment name, date/time, key conditions, Protocol name, scaled volume or sample count, step completion summary, short notes, and a subtle `Powered by LabBuddy` watermark.
- **D-05:** Short notes are allowed, but long explanations or chat-like report copy are out of scope.

### Image Interaction And Annotation
- **D-06:** The image area is interactive/clickable.
- **D-07:** Users can view large images, replace images, crop images, reorder or manage multiple images, and annotate images.
- **D-08:** Annotation supports finger-drawn circles/selection marks, arrows, and short text labels.
- **D-09:** Annotation is for quickly clarifying gel, blot, fluorescence, or similar results; it is not a full drawing application.

### Template Scope
- **D-10:** v1 ships one polished academic-simple card template.
- **D-11:** v1 must not implement multiple templates, skins, community templates, or plugin-style card themes.
- **D-12:** Future official skins, community templates, and plugin-style layouts are acceptable later, but not part of the v1 minimum loop.

### Generation Entry Points
- **D-13:** Completing an experiment can prompt the user to generate a Data Card.
- **D-14:** Users can also generate a Data Card from experiment detail.
- **D-15:** Users can regenerate a Data Card from past records after adding or editing images, conditions, or notes.

### Export And Sharing
- **D-16:** Users can save the card image to Photos.
- **D-17:** Users can share through the iOS Share Sheet.
- **D-18:** Users can copy structured condition text.
- **D-19:** Copied condition text is not AI report copy; it is a concise metadata summary.

### Metadata Sources And Control
- **D-20:** Card conditions are automatically populated from Protocol data, scaled volume or sample count, schedule time, timer actual start/end, completion records, key metadata, and inventory-confirmed actual usage when available.
- **D-21:** Before generation/export, users can edit or hide specific condition fields.
- **D-22:** The card should avoid becoming a dense table. Only the most relevant metadata should be shown by default.

### the agent's Discretion
- The agent may decide the exact card layout, hierarchy, typography, and default metadata subset as long as the template remains polished, academic, compact, and readable.
- The agent may decide initial placeholder imagery behavior for prototype builds.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product And Requirements
- `.planning/PROJECT.md` — Defines LabBuddy as an iOS-first, local-first wet-lab bench productivity app.
- `.planning/REQUIREMENTS.md` — Defines Phase 8 requirements `CARD-01` through `CARD-06`.
- `.planning/ROADMAP.md` — Defines Phase 8 scope, dependencies, success criteria, and plans.

### Current Implementation Context
- `LabBuddy/ContentView.swift` — Contains the current prototype `DataCardPreview` and share/copy affordances.
- `LabBuddy/Models.swift` — Contains current run, Protocol, step, inventory, and metadata-adjacent prototype models.
- `LabBuddy/SampleData.swift` — Contains sample runs and Protocols that can seed Data Card examples.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Current `DataCardPreview` can seed the composition concept but must be reshaped around real image interaction, metadata field control, and no AI report summary.
- Existing run/Protocol/step models provide the initial metadata sources for card composition.

### Established Patterns
- The app is iOS-only, so Photos, PhotosUI, SwiftUI rendering, and the iOS Share Sheet are appropriate platform primitives.
- The v1 app is local-first; card images and attached assets remain local unless the user explicitly shares/exports.

### Integration Points
- Phase 4 schedule supplies planned time and experiment labels.
- Phase 5 timers supply actual start/end data.
- Phase 6 records supply completion state, notes, and key conditions.
- Phase 7 inventory supplies confirmed actual usage where available.

</code_context>

<specifics>
## Specific Ideas

- The user explicitly removed AI report summary from the card concept.
- The user wants the card to show the result beautifully together with corresponding experimental conditions.
- Images should be tappable/operable, not static decoration.

</specifics>

<deferred>
## Deferred Ideas

- AI mentor-report copy and tone generation are deferred to Pro or a later version.
- Multiple card skins, community templates, and plugin-style card themes are deferred beyond v1.

</deferred>

---

*Phase: 8-Data Cards and Share Flow*
*Context gathered: 2026-05-29*
