# Quick Plan: refine Today tab schedule flow

## Scope
- Rename the first Today tab segment from experiment records to past records.
- Keep past records focused on days before today, with calendar-like day switching.
- Replace "blank time" strips with timeline insert actions between scheduled experiments.
- Support local day rollover: tomorrow becomes today and today is archived as past after date changes.

## Verification
- Run source checks for removed "空白时间" user-facing copy.
- Run `make preflight`.
- Launch the app through XcodeBuildMCP.
