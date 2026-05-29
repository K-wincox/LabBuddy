# Phase 8: Data Cards and Share Flow - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 8-Data Cards and Share Flow
**Areas discussed:** Card purpose, content, image interaction, template scope, generation entry points, export/share, metadata sources

---

## Card Purpose

| Option | Description | Selected |
|--------|-------------|----------|
| Mentor/labmate sharing | Help others quickly see the result and key conditions. | |
| Personal archive | Serve mainly as a notebook-style record. | |
| Both, sharing-first | Support both archive and sharing, with sharing glanceability prioritized. | ✓ |

**User's choice:** Both, sharing-first.
**Notes:** The card should not contain AI report summaries or long reporting copy.

---

## Card Content

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal | Image, experiment name, date/time. | |
| Result + conditions | Image, experiment name, key conditions, Protocol/usage information. | |
| Full compact card | Result image, name, date/time, key conditions, Protocol, usage, completion, short note, watermark. | ✓ |

**User's choice:** Full compact card.
**Notes:** Notes must remain short; no long report prose.

---

## Image Interaction

| Option | Description | Selected |
|--------|-------------|----------|
| Single static image | Add one image with no annotation. | |
| Multi-image management | Add multiple images with crop/order. | |
| Operable annotated images | Images are clickable and support view, replace, crop, reorder, circles, arrows, and short text. | ✓ |

**User's choice:** Operable annotated images.
**Notes:** Annotation should clarify the result, not become a full drawing suite.

---

## Template Scope

| Option | Description | Selected |
|--------|-------------|----------|
| One template | One polished academic-simple template in v1. | ✓ |
| 2-3 templates | Simple, academic, and presentation variants. | |
| Many skins | Multiple colors/themes/templates. | |

**User's choice:** One template for v1.
**Notes:** Future skins, community templates, and plugin-style card themes can come later.

---

## Generation Entry Points

| Option | Description | Selected |
|--------|-------------|----------|
| Completion only | Generate only right after finishing an experiment. | |
| Detail/history only | Generate from experiment detail or past records. | |
| Completion + detail + history | Prompt after completion and allow regeneration from detail/past records. | ✓ |

**User's choice:** Completion + detail + history.
**Notes:** Users can regenerate after adding images, conditions, or notes.

---

## Export And Sharing

| Option | Description | Selected |
|--------|-------------|----------|
| Save only | Save the card to Photos only. | |
| Share Sheet only | Share through iOS Share Sheet only. | |
| Save + share + copy conditions | Save to Photos, share image, and copy structured condition text. | ✓ |

**User's choice:** Save + share + copy conditions.
**Notes:** Copied text is concise condition metadata, not AI report copy.

---

## Metadata Sources

| Option | Description | Selected |
|--------|-------------|----------|
| Manual only | User fills conditions manually. | |
| Automatic only | Pull all conditions from app metadata. | |
| Automatic with edit/hide | Auto-populate from metadata, then allow editing or hiding fields. | ✓ |

**User's choice:** Automatic with edit/hide.
**Notes:** Sources include Protocol, scaling, schedule, timer actuals, completion records, key metadata, and inventory-confirmed actual usage.

## the agent's Discretion

- The agent may choose exact card layout and default metadata subset.

## Deferred Ideas

- AI mentor-report copy is deferred to Pro/later versions.
- Multiple skins, community templates, and plugin-style themes are deferred beyond v1.
