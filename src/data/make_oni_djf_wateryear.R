# =====================================================================
# make_oni_djf_wateryear.R
# Layer 2 of the pipeline (see src/data/README):
#   reads/saves raw  -> data/external/oni_download.txt   (unedited)
#   derives interim  -> data/interim/oni_djf_wateryear.csv
# Sourced by make_analysis_data.R, which joins interims into
# data/processed/ca_enso_analysis.csv. All ONI variable derivation
# lives HERE and nowhere else (assignment guidance point 5).
#
# Requires: here (ONI comes straight from NOAA CPC, not rsoi -- see below)
# =====================================================================

if (!requireNamespace("here", quietly = TRUE))
  stop("Package 'here' is not installed. Run: install.packages(\"here\")",
       call. = FALSE)

WY_FIRST <- 1950
WY_LAST  <- 2025

CPC_URL <- "https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt"
RAW <- here::here("data", "external", "oni_download.txt")
OUT <- here::here("data", "interim",  "oni_djf_wateryear.csv")

# ---- 1. Download ONI from NOAA CPC; preserve the raw layer -----------
# We read CPC's published table directly rather than rsoi::download_oni().
# rsoi recomputes ONI as a rolling 3-month mean, so it CANNOT produce the
# DJF window for 1950 (that needs Dec 1949, which the series lacks) and
# its earliest DJF is 1951. CPC publishes DJF 1950 (-1.53) outright, so
# sourcing here keeps the full WY1950-2025 sample the report describes.
dir.create(dirname(RAW), showWarnings = FALSE, recursive = TRUE)
ok <- tryCatch(utils::download.file(CPC_URL, RAW, quiet = TRUE, mode = "wb"),
               error = function(e) 1L)
if (!identical(ok, 0L))
  stop("Could not download the ONI table from CPC (network problem?):\n  ",
       CPC_URL, call. = FALSE)
message("Raw download preserved at ", RAW)

# Fixed-width-ish table: SEAS YR TOTAL ANOM. ANOM is the ONI.
oni_raw <- utils::read.table(RAW, header = TRUE, stringsAsFactors = FALSE)
stopifnot(all(c("SEAS", "YR", "ANOM") %in% names(oni_raw)))
message("CPC table: ", nrow(oni_raw), " rows, ",
        min(oni_raw$YR), "-", max(oni_raw$YR))

# ---- 2. Keep the DJF window for each water year ----------------------
# DJF of calendar year Y = Dec(Y-1)-Feb(Y), which falls inside water
# year Y, so the DJF row's year IS the water year.
# NOTE: use which() so that any NA in the condition drops the row. Plain
# logical subsetting turns an NA into a phantom all-NA row (this bug
# previously produced a junk trailing row that still passed the n check).
d <- oni_raw[which(oni_raw$SEAS == "DJF" &
                   oni_raw$YR >= WY_FIRST & oni_raw$YR <= WY_LAST), ]
d <- d[order(d$YR), ]
n <- nrow(d)

if (n != WY_LAST - WY_FIRST + 1)
  stop("Expected ", WY_LAST - WY_FIRST + 1, " DJF rows, got ", n)
if (anyNA(d$YR) || anyNA(d$ANOM))
  stop("DJF rows contain missing years or ONI values.")
if (!identical(d$YR, WY_FIRST:WY_LAST))
  stop("Water years are not a complete consecutive run ",
       WY_FIRST, "-", WY_LAST, ".")

oni_djf <- round(d$ANOM, 1)

# ---- 3. Derived columns (verified against the shipped file) ----------
phase <- ifelse(oni_djf >=  0.5, "el_nino",
         ifelse(oni_djf <= -0.5, "la_nina", "neutral"))

strength <- as.character(cut(abs(oni_djf),
  breaks = c(-Inf, 0.5, 1.0, 1.5, 2.0, Inf), right = FALSE,
  labels = c("neutral", "weak", "moderate", "strong", "very_strong")))

fmt1 <- function(x) ifelse(is.na(x), "", sprintf("%.1f", x))  # "0.0", not "0"

out <- data.frame(
  water_year    = d$YR,
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
