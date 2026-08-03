# src/data

Scripts that download, clean, and transform data. Keep **all** variable
derivation here — not in the report — so the team shares one canonical version
of every variable (assignment guidance point 5).

Pipeline (top to bottom):

1. **(raw)** `data/external/` — third-party files as downloaded, unedited.
2. **`make_*` scripts here** — read `external/`, derive intermediates into
   `data/interim/`, then join into the canonical `data/processed/ca_enso_analysis.csv`.
3. The report in `reports/` reads **only** `data/processed/` — never re-derives.

**To build (once these scripts exist):**

```r
source(here::here("src", "data", "make_analysis_data.R"))
```

> Status: the `make_analysis_data.R` referenced by the report appendix is not
> yet in the repo. `data/processed/ca_enso_analysis.csv` must be (re)created
> here before the final report can knit.
