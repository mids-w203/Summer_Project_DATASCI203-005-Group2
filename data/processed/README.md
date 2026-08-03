# data/processed

Final, canonical datasets for modeling — one row per unit of observation, ready
for the report with no further transformation.

**Expected file:** `ca_enso_analysis.csv` — one row per California water year
(WY1950–2025), joining winter ONI, derived ENSO phase/strength/lag/trend, the
reversed SOI, and statewide water-year precipitation. It is the single file the
final report reads.

Built by `src/data/make_analysis_data.R` from `data/external/` (raw NOAA files)
and `data/interim/` (transformed intermediates). This file is currently
**not yet generated** — see `src/data/README.md`.
