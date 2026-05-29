# Phase 7: Personal Inventory - Context

**Gathered:** 2026-05-29
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 7 defines LabBuddy's personal local inventory model and how it appears inside the `我的` tab. The `我的` tab is a personal workspace containing settings, inventory summary/entry points, local data management, and clearly disabled future account/Pro/cloud entries. Inventory itself must support item management, Protocol linking, suggested deductions, low-stock warnings, and inspectable correction-friendly transactions.

</domain>

<decisions>
## Implementation Decisions

### My Page Role
- **D-01:** `我的` is a personal workspace, not a pure inventory page.
- **D-02:** It includes personal settings, inventory entry points, local data management, and future login/Pro/cloud placeholders.
- **D-03:** Inventory is an important module inside `我的`, but full inventory management should open into a secondary page.

### Inventory Presentation
- **D-04:** The `我的` home shows an inventory summary, low-stock count, common/recent reagents, and visible restock warnings.
- **D-05:** Full inventory management lives in a secondary inventory page.
- **D-06:** The home should not be flooded with the entire inventory list.

### Inventory Item Fields
- **D-07:** Inventory items include name, category, current quantity, unit, low-stock threshold, storage location, lot/batch number, opening date, expiration date, supplier/vendor, and notes.
- **D-08:** Inventory items can link to Protocol reagent items.
- **D-09:** Inventory must preserve consumption and adjustment records.

### Deduction Flow
- **D-10:** Completing an experiment generates suggested inventory deductions rather than silently deducting.
- **D-11:** The user can confirm, modify actual quantities, or skip suggested deductions.
- **D-12:** Confirmed deductions create inspectable transactions.
- **D-13:** Inventory transactions must be correctable after the fact.

### Low-Stock Warnings
- **D-14:** Low-stock warnings appear on the `我的` home.
- **D-15:** Low-stock items are highlighted or prioritized on the inventory page.
- **D-16:** Deduction preview must warn if confirming a deduction will push an item below threshold.

### Local Data Management
- **D-17:** `我的` includes local export/backup.
- **D-18:** `我的` includes local import/restore.
- **D-19:** `我的` includes cache cleanup and demo-data reset.
- **D-20:** Backup/restore is local file based in v1 and must clearly explain that exported data includes local Protocols, schedules, records, inventory, and related app data.

### Future Account And Pro Placeholders
- **D-21:** `我的` keeps placeholders for login/identity, Pro status, and cloud backup/sync.
- **D-22:** These placeholders must be clearly marked as not enabled in v1, local mode, or future-version features.
- **D-23:** v1 must not implement real login, subscription, or cloud sync.

### the agent's Discretion
- The agent may choose the exact secondary-page navigation and inventory summary visuals.
- The agent may choose the initial categories and sample inventory items, biased toward the three v1 wet-lab domains.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Product And Requirements
- `.planning/PROJECT.md` — Defines LabBuddy as an iOS-first, local-first wet-lab bench productivity app.
- `.planning/REQUIREMENTS.md` — Defines Phase 7 requirements `INVT-01` through `INVT-06`.
- `.planning/ROADMAP.md` — Defines Phase 7 scope, dependencies, success criteria, and plans.

### Current Implementation Context
- `LabBuddy/ContentView.swift` — Contains the current prototype `ProfileView` and embedded `InventoryView`.
- `LabBuddy/Models.swift` — Contains the current prototype `InventoryItem` model.
- `LabBuddy/SampleData.swift` — Contains the current sample inventory items.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- Existing `ProfileView` can be reshaped into the personal workspace.
- Existing `InventoryView` can become the summary module or seed the secondary inventory page.

### Established Patterns
- Local-first personal data remains the v1 rule.
- Future account/cloud features can be visible as disabled settings rows, but they must not imply working functionality.

### Integration Points
- Phase 2 Protocol recipes link to inventory items.
- Phase 3 scaled recipe snapshots supply expected consumption.
- Phase 6 completion state triggers deduction preview.
- Phase 8 Data Cards may display actual consumed amounts after deduction/confirmation.

</code_context>

<specifics>
## Specific Ideas

- The `我的` home should surface inventory risk without turning into a long inventory table.
- Suggested deductions should feel reviewable and correctable, not automatic and opaque.

</specifics>

<deferred>
## Deferred Ideas

- Real login, subscriptions, cloud backup, and cloud sync are deferred beyond v1.
- Team inventory, shared purchasing, and approval/order workflows are deferred beyond v1.

</deferred>

---

*Phase: 7-Personal Inventory*
*Context gathered: 2026-05-29*
