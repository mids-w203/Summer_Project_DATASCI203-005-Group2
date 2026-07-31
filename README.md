# ENSO and California Rainfall Patterns

**DATASCI 203 — Research Project | Group 2**

**Team:** Daniel Bowd, Gunhui (Simon) Kim, Rishi Raj, and Sasha Schaps

## Overview

This project investigates how major climatic events — specifically El Niño and La Niña phases of the El Niño–Southern Oscillation (ENSO) — affect rainfall patterns in California. California’s water supply varies substantially from year to year; understanding how ENSO conditions relate to precipitation can support better water conservation and distribution planning for agencies such as the Bureau of Reclamation, the California Department of Water Resources, and PG&E.

## Research Question

How do El Niño / La Niña phases of ENSO affect rainfall patterns in the state of California?

| Concept | Operationalization |
| --- | --- |
| **X** (ENSO phase and intensity) | Historical Southern Oscillation Index (SOI) and Oceanic Niño Index (ONI) |
| **Y** (California rainfall) | Historical precipitation totals, with average temperature and reservoir storage as additional considerations |

**Unit of observation:** Month — each row pairs a monthly ENSO measurement with monthly California rainfall totals.

Prior work documents a clear pattern: El Niño tends to bring wetter-than-normal conditions to California and La Niña the inverse (Cayan et al., 1999; Redmond & Koch, 1991; Schonher & Nicholson, 1989), with stronger effects in Southern California (Jong et al., 2016). The relationship is not deterministic — recent years were unexpectedly wet despite La Niña (Guirguis et al., 2024) — which motivates further analysis with linear models.

## Key Considerations

- Does historical SOI data correlate with historical rainfall or average temperature data?
- How do El Niño / La Niña conditions affect rainfall levels in California?
- Can we predict the length of El Niño / La Niña oscillations using rainfall or average temperature?

## Key Variables

- **X:** Monthly SOI score; ONI / sea surface temperature
- **Y:** Monthly precipitation totals, with average temperature and reservoir storage

## Data Sources

- [NOAA](https://www.noaa.gov/) historical SOI and ONI records (sea level pressure differences and sea surface temperature anomalies)
- [California Data Exchange Center (CDEC)](https://cdec.water.ca.gov/) for monthly precipitation (and related hydrologic series)

## Project Structure

```
├── LICENSE
├── README.md          <- Project aims and overview (this file)
├── data
│   ├── external       <- Data from third-party sources
│   ├── interim        <- Intermediate data that has been transformed
│   └── processed      <- Final, canonical datasets for modeling
├── prompt             <- The assignment prompt
├── peer_review        <- Starting place for each person's peer evaluation
├── notebooks          <- .Rmd notebooks
├── references         <- Data dictionaries, manuals, and explanatory materials
├── reports            <- Generated analysis (HTML, PDF, LaTeX, etc.)
└── src
    └── data           <- Scripts to download or generate data
```

## Methods

We will build linear models relating monthly ENSO indicators (SOI, ONI) to California precipitation (and related variables) to produce a report analyzing the research question above.

## References

- Cayan, D. R., Redmond, K. T., & Dettinger, M. D. (1999). ENSO and hydrologic extremes in the western United States. *Journal of Climate*.
- Redmond, K. T., & Koch, R. W. (1991). Surface climate and streamflow variability in the western United States and their relationship to large-scale circulation indices. *Water Resources Research*.
- Schonher, T., & Nicholson, S. E. (1989). The relationship of California rainfall to ENSO events. *Journal of Climate*.
- Jong, B.-T., Ting, M., & Seager, R. (2016). El Niño's impact on California precipitation: seasonality, regionality, and El Niño intensity. *Environmental Research Letters*.
- Guirguis, K., et al. (2024). Reinterpreting ENSO's role in modulating impactful precipitation events in California. *Geophysical Research Letters*.

## Course

DATASCI 203 — Group 2 research project.
