# =====================================================================
# make_analysis_data.R
# Layer 3 (top) of the pipeline (see src/data/README):
#   joins the interim files -> data/processed/ca_enso_analysis.csv
#
# This is the ONLY script the report depends on. Running it end to end
# rebuilds every input from source:
#
#   make_oni_djf_wateryear.R   -> data/interim/oni_djf_wateryear.csv
#   make_soi_wateryear.R       -> data/interim/soi_ndjfm_wateryear.csv
#   make_ca_wateryear_precip.R -> data/interim/ca_wateryear_precip.csv
#                              -> data/processed/ca_enso_analysis.csv
#
# Unit of observation: one California water year (Oct 1 - Sep 30),
# WY1950-WY2025, 76 rows.
#
# Requires: here
# Usage: Rscript src/data/make_analysis_data.R
#        (add REBUILD=FALSE below to reuse existing interim files)
# =====================================================================

if (!requireNamespace("here", quietly = TRUE))
  stop("Package 'here' is not installed. Run: install.packages(\"here\")",
       call. = FALSE)

REBUILD <- TRUE          # FALSE = reuse interim files, skip downloads

WY_FIRST <- 1950
WY_LAST  <- 2025

ONI_FILE    <- here::here("data", "interim", "oni_djf_wateryear.csv")
SOI_FILE    <- here::here("data", "interim", "soi_ndjfm_wateryear.csv")
PRECIP_FILE <- here::here("data", "interim", "ca_wateryear_precip.csv")
OUT         <- here::here("data", "processed", "ca_enso_analysis.csv")

# ---- 1. Rebuild the interim layer -------------------------------------
if (REBUILD) {
  for (s in c("make_oni_djf_wateryear.R", "make_soi_wateryear.R",
              "make_ca_wateryear_precip.R")) {
    message("\n--- running ", s, " ---")
    source(here::here("src", "data", s), local = new.env())
  }
  message("")
}

for (f in c(ONI_FILE, SOI_FILE, PRECIP_FILE))
  if (!file.exists(f))
    stop("Missing interim file: ", f,
         "\nRun with REBUILD <- TRUE, or run the make_* scripts first.",
         call. = FALSE)

oni    <- utils::read.csv(ONI_FILE,    stringsAsFactors = FALSE)
soi    <- utils::read.csv(SOI_FILE,    stringsAsFactors = FALSE)
precip <- utils::read.csv(PRECIP_FILE, stringsAsFactors = FALSE)

# ---- 2. Join on water year --------------------------------------------
d <- merge(oni, precip[, intersect(names(precip),
             c("water_year", "precip_in", "n_stations", "precip_source"))],
           by = "water_year", all = FALSE)
d <- merge(d, soi, by = "water_year", all.x = TRUE)
d <- d[order(d$water_year), ]

# ---- 3. Presentation labels the report expects ------------------------
# The interim keeps machine-safe labels (el_nino); the report factors on
# the display form. Map once, here, so the report never re-derives.
pretty <- c(la_nina = "La Niña", neutral = "Neutral", el_nino = "El Niño")
d$enso_phase <- unname(pretty[d$enso_phase])

# `phase` is the SECOND, independent operationalization: the same
# +/-0.5 rule applied to the reversed SOI (atmosphere) instead of the
# ONI (ocean). The report counts how often the two disagree, which is
# only meaningful because they come from different instruments.
d$phase <- ifelse(is.na(d$rsoi), NA_character_,
           ifelse(d$rsoi >=  0.5, "El Niño",
           ifelse(d$rsoi <= -0.5, "La Niña", "Neutral")))

# ---- 4. Column order --------------------------------------------------
cols <- c("water_year", "precip_in",
          "oni_djf", "oni_djf_lag1", "rsoi",
          "enso_phase", "phase", "enso_strength",
          "el_nino", "la_nina", "time_trend")
cols <- c(cols, setdiff(intersect(names(d),
            c("n_stations", "precip_source")), cols))
d <- d[, intersect(cols, names(d))]

# ---- 5. Validate the merge --------------------------------------------
n_expected <- WY_LAST - WY_FIRST + 1
if (nrow(d) != n_expected)
  stop("Merge produced ", nrow(d), " rows, expected ", n_expected,
       ". Check that all three interim files cover WY", WY_FIRST,
       "-WY", WY_LAST, ".", call. = FALSE)
if (!identical(d$water_year, WY_FIRST:WY_LAST))
  stop("Water years are not a complete consecutive run.", call. = FALSE)
if (anyNA(d$precip_in) || anyNA(d$oni_djf))
  stop("Missing values in the two analysis variables.", call. = FALSE)
stopifnot(
  all(d$precip_in > 0),
  all(d$el_nino + d$la_nina <= 1),                 # phases exclusive
  sum(is.na(d$oni_djf_lag1)) == 1L,                # only WY1950
  all(d$enso_phase %in% c("La Niña", "Neutral", "El Niño"))
)

dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(d, OUT, row.names = FALSE, fileEncoding = "UTF-8")

# ---- 6. Report what was built -----------------------------------------
message("Wrote ", OUT, ": ", nrow(d), " water years (WY",
        min(d$water_year), "-WY", max(d$water_year), ").")
message(sprintf("  precip_in : mean %.2f  sd %.2f  min %.2f  max %.2f",
                mean(d$precip_in), stats::sd(d$precip_in),
                min(d$precip_in), max(d$precip_in)))
message(sprintf("  oni_djf   : mean %.2f  sd %.2f",
                mean(d$oni_djf), stats::sd(d$oni_djf)))
message(sprintf("  cor(precip_in, oni_djf) = %.3f",
                stats::cor(d$precip_in, d$oni_djf)))
message("  phases (La Nina/Neutral/El Nino): ",
        sum(d$enso_phase == "La Niña"),  " / ",
        sum(d$enso_phase == "Neutral"),  " / ",
        sum(d$enso_phase == "El Niño"))
if ("precip_source" %in% names(d))
  message("  precipitation source: ", d$precip_source[1])
