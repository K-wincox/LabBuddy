# Phase 7: Personal Inventory - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-05-29
**Phase:** 7-Personal Inventory
**Areas discussed:** My page role, inventory presentation, inventory fields, deduction flow, low-stock warnings, local data management, future account placeholders

---

## My Page Role

| Option | Description | Selected |
|--------|-------------|----------|
| Personal settings | Focus on profile and app preferences. | |
| Inventory center | Make inventory the whole page. | |
| Personal workspace | Settings, inventory entry, local data management, and future placeholders. | ✓ |

**User's choice:** Personal workspace.
**Notes:** Inventory is important but should live as a module inside `我的`.

---

## Inventory Presentation

| Option | Description | Selected |
|--------|-------------|----------|
| Summary only | Show low-stock summary and link to inventory. | |
| Full list on home | Put the entire inventory list on `我的`. | |
| Summary + high-frequency items | Show low-stock count, common/recent items, and a secondary full inventory page. | ✓ |

**User's choice:** Summary + high-frequency items.
**Notes:** Home should be useful but not overwhelmed by inventory rows.

---

## Inventory Fields

| Option | Description | Selected |
|--------|-------------|----------|
| Basic fields | Name, category, quantity, unit, threshold, location. | |
| Basic + lifecycle | Add batch, opening date, expiration, supplier notes. | |
| Full local tracking | Basic + lifecycle + Protocol links + consumption/adjustment records. | ✓ |

**User's choice:** Full local tracking.
**Notes:** Needed for later suggested deductions and traceability.

---

## Deduction Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Silent auto-deduct | Deduct automatically when experiment completes. | |
| Confirm preview | Preview expected deduction, then user confirms. | |
| Suggested editable deduction | Generate suggested deduction; user confirms, edits, or skips. | ✓ |

**User's choice:** Suggested editable deduction.
**Notes:** Actual wet-lab consumption often differs from theoretical scaled amounts.

---

## Low-Stock Warnings

| Option | Description | Selected |
|--------|-------------|----------|
| My page only | Warn only on `我的`. | |
| My + inventory | Warn on home and inventory page. | |
| My + inventory + deduction preview | Also warn if a pending deduction drops below threshold. | ✓ |

**User's choice:** Warn in all three places.
**Notes:** The completion/deduction moment is especially actionable.

---

## Local Data Management

| Option | Description | Selected |
|--------|-------------|----------|
| Reset demo only | Keep only a reset demo data action. | |
| Export backup | Add local export/backup. | |
| Full local management | Export/backup, import/restore, cache cleanup, and demo reset. | ✓ |

**User's choice:** Full local management.
**Notes:** v1 is local-first, so file-based backup and restore matter.

---

## Future Account Placeholders

| Option | Description | Selected |
|--------|-------------|----------|
| Hide completely | Do not show login/Pro/cloud in v1. | |
| Static coming soon | Show non-clickable future capability labels. | |
| Disabled placeholders | Keep entries but clearly mark them as local mode/future version/not enabled. | ✓ |

**User's choice:** Disabled placeholders.
**Notes:** Do not implement real login, subscription, or cloud sync in v1.

## the agent's Discretion

- The agent may decide exact secondary page navigation and inventory summary visuals.

## Deferred Ideas

- Login, subscriptions, cloud sync, shared inventory, purchasing, and approval/order flows are deferred beyond v1.
