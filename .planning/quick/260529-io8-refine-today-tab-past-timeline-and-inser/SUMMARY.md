# Summary

## Changed
- Renamed the Today tab's first segment from experiment records to past records.
- Past records now use a local `ExperimentDayRecord` model and show only historical days.
- Added local midnight rollover logic: today's scheduled runs are archived to past records, and tomorrow's runs become today's scheduled runs.
- Replaced separate "blank time" strips with timeline insert buttons before, between, and after scheduled experiments.
- Reused the editable schedule timeline for both today and tomorrow.

## Verified
- Source search found no remaining user-facing "空白时间" schedule strip copy.
- `make preflight` passed.
- XcodeBuildMCP `build_run_sim` passed on iPhone 17 Pro simulator.
- XcodeBuildMCP UI snapshot confirmed the first segment content displays as "过去" with historical day cards.
