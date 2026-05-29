# Phase 4: Daily Schedule - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 4-Daily Schedule
**Areas discussed:** Three-segment day model, day rollover, timeline insertion, past record editability

---

## Three-Segment Day Model

| Option | Description | Selected |
|--------|-------------|----------|
| Past-only calendar | `过去` shows a calendar-like historical view limited to days before today. | ✓ |
| Mixed calendar | One calendar includes past, today, and tomorrow together. | |
| Records label | Keep the segment named `实验记录` or `记录`. | |

**User's choice:** Use `过去 / 今天 / 明天`; past shows a complete calendar-style historical view but excludes today and tomorrow.
**Notes:** Today is the formal execution timeline. Tomorrow uses the same formal schedule model as today, not a weak draft.

---

## Day Rollover

| Option | Description | Selected |
|--------|-------------|----------|
| Fixed midnight rollover | Automatically roll at 00:00. | |
| Fixed early-morning rollover | Automatically roll at 05:00. | |
| User-confirmed rollover | User taps `结束今天`, or confirms a start-new-day reminder on next app open. | ✓ |

**User's choice:** Do not secretly roll by time. Use `结束今天`; if missed, ask on next launch whether to start a new day.
**Notes:** Rollover archives all of today, including unfinished, completed, and canceled experiments, then moves tomorrow into today. Overnight experiments should appear on both relevant days with one identity. End-of-day/start-day sheets should include randomized supportive copy.

---

## Timeline Insertion

| Option | Description | Selected |
|--------|-------------|----------|
| Between-item plus only | Add through insertion points between experiments. | |
| Empty-axis tap only | Add by tapping empty time-axis space. | |
| Both affordances | Support both `+` insertion points and empty-axis taps. | ✓ |

**User's choice:** Support both.
**Notes:** Add sheet supports Protocol import, manual/temporary experiment operation, and carry-over placeholder. New items must be editable after creation, including time and other custom fields.

---

## Conflict Handling

| Option | Description | Selected |
|--------|-------------|----------|
| Disallow overlaps | Force the user to pick non-overlapping times. | |
| Allow silently | Permit overlap with no special handling. | |
| Allow with visible conflicts | Permit overlap, clearly mark it, and provide shift-later action. | ✓ |

**User's choice:** Allow overlaps with clear conflict markers and one-click shift of later experiments.
**Notes:** Wet-lab work is naturally multi-threaded, so hard blocking overlaps would be wrong.

---

## Past Record Editability

| Option | Description | Selected |
|--------|-------------|----------|
| View-only | Archived days cannot be edited. | |
| Supplement-only | Add notes, results, images, metadata, and simple status corrections without restructuring the timeline. | ✓ |
| Full edit | Past timelines can be freely rearranged and structurally edited. | |

**User's choice:** Supplement-only by default.
**Notes:** Deep structural correction can exist behind a deliberate secondary entry, with full record editing refined in Phase 6.

## the agent's Discretion

- The agent may choose exact UI styling, component names, local persistence shape, and the supportive message set as long as decisions in `04-CONTEXT.md` remain true.

## Deferred Ideas

- Full historical record editing is deferred to Phase 6.
- Timer execution surfaces are deferred to Phase 5.
- Image annotation and Data Cards are deferred to Phase 8.
