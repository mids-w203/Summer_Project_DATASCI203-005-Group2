# =====================================================================
# make_oni_djf_wateryear.R
# Layer 2 of the pipeline (see src/data/README):
#   reads/saves raw  -> data/external/oni_download.csv   (unedited)
#   derives interim  -> data/interim/oni_djf_wateryear.csv
# Sourced by make_analysis_data.R, which joins interims into
# data/processed/ca_enso_analysis.csv. All ONI variable derivation
# lives HERE and nowhere else (assignment guidance point 5).
#
# Requires: rsoi, here
# =====================================================================

if (!requireNamespace("rsoi", quietly = TRUE))
  stop("Package 'rsoi' is not installed. Run: install.packages(\"rsoi\")",
       call. = FALSE)
if (!requireNamespace("here", quietly = TRUE))
  stop("Package 'here' is not installed. Run: install.packages(\"here\")",
       call. = FALSE)

WY_FIRST <- 1950
WY_LAST  <- 2025

RAW <- here::here("data", "external", "oni_download.csv")
OUT <- here::here("data", "interim",  "oni_djf_wateryear.csv")

# ---- 1. Download ONI via rsoi; preserve the raw layer ----------------
oni_raw <- tryCatch(
  as.data.frame(rsoi::download_oni()),
  error = function(e) stop(
    "rsoi::download_oni() failed (network problem reaching NOAA?):\n  ",
    conditionMessage(e), call. = FALSE)
)
message("download_oni() returned ", nrow(oni_raw), " rows; columns: ",
        paste(names(oni_raw), collapse = ", "))

# data/external/ keeps the third-party data as downloaded, unedited.
dir.create(dirname(RAW), showWarnings = FALSE, recursive = TRUE)
write.csv(oni_raw, RAW, row.names = FALSE)
message("Raw download preserved at ", RAW)

# ---- 2. Find DJF rows, robust to rsoi's column-name drift ------------
win_col <- names(oni_raw)[vapply(oni_raw, function(x)
  is.character(x) && any(x == "DJF", na.rm = TRUE) ||
  is.factor(x)    && "DJF" %in% levels(x), logical(1))][1]
if (is.na(win_col))
  stop("Could not find a column containing 'DJF' window labels. ",
       "Inspect names(rsoi::download_oni()) and set win_col manually.")
message("Using window column: ", win_col)

stopifnot(all(c("Year", "ONI") %in% names(oni_raw)))

# DJF of calendar year Y = Dec(Y-1)-Feb(Y), inside water year Y,
# so the DJF row's Year IS the water year.
d <- oni_raw[oni_raw[[win_col]] == "DJF" &
             oni_raw$Year >= WY_FIRST & oni_raw$Year <= WY_LAST, ]
d <- d[order(d$Year), ]
n <- nrow(d)
if (n != WY_LAST - WY_FIRST + 1)
  stop("Expected ", WY_LAST - WY_FIRST + 1, " DJF rows, got ", n)

oni_djf <- round(d$ONI, 1)

# ---- 3. Derived columns (verified against the shipped file) ----------
phase <- ifelse(oni_djf >=  0.5, "el_nino",
         ifelse(oni_djf <= -0.5, "la_nina", "neutral"))

strength <- as.character(cut(abs(oni_djf),
  breaks = c(-Inf, 0.5, 1.0, 1.5, 2.0, Inf), right = FALSE,
  labels = c("neutral", "weak", "moderate", "strong", "very_strong")))

fmt1 <- function(x) ifelse(is.na(x), "", sprintf("%.1f", x))  # "0.0", not "0"

out <- data.frame(
  water_year    = d$Year,
  oni_djf       = fmt1(oni_djf),
  enso_phase    = phase,
  enso_strength = strength,
  el_nino       = as.integer(phase == "el_nino"),
  la_nina       = as.integer(phase == "la_nina"),
  oni_djf_lag1  = fmt1(c(NA, oni_djf[-n])),
  time_trend    = seq_len(n) - 1L,
  stringsAsFactors = FALSE
)

# ---- 4. Write the interim file ---------------------------------------
dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)
write.table(out, OUT, sep = ",", quote = FALSE, row.names = FALSE,
            na = "", eol = "\r\n")
message("Wrote ", OUT, ": ", n, " water years.")
