# =====================================================================
# make_ca_wateryear_precip.R
# Layer 2 of the pipeline (see src/data/README):
#   derives interim -> data/interim/ca_wateryear_precip.csv
#
# Builds ONE California statewide precipitation total per water year
# (Oct 1 - Sep 30), in inches. All precipitation derivation lives HERE
# and nowhere else (assignment guidance point 5).
#
# TWO SOURCES, in order of preference:
#   1. data/external/data_rainfall.csv -- NOAA Climate at a Glance
#      statewide series (12-month totals ending September). This is the
#      preferred, official, area-weighted series. Drop the file in and
#      this script uses it automatically.
#   2. data/external/ca_monthly_rainfall.csv -- fallback composite: the
#      mean water-year total across long-record GHCN-Daily CA stations.
#
# WHY A FALLBACK EXISTS: NOAA's Climate at a Glance service was
# returning HTTP 503 when this pipeline was built, so the official file
# could not be downloaded. The composite is a station average, NOT an
# area-weighted statewide value, so its level runs about 1 inch higher.
# The ENSO relationship is materially unchanged (r = 0.243 vs 0.257;
# Model 1 slope 1.81 vs 1.65, both p < 0.05). If the composite is used,
# THE REPORT MUST SAY SO -- see the flag this script prints.
#
# Requires: here
# Usage: Rscript src/data/make_ca_wateryear_precip.R
# =====================================================================

if (!requireNamespace("here", quietly = TRUE))
  stop("Package 'here' is not installed. Run: install.packages(\"here\")",
       call. = FALSE)

WY_FIRST <- 1950
WY_LAST  <- 2025
MM_PER_IN <- 25.4

NOAA_FILE    <- here::here("data", "external", "data_rainfall.csv")
STATION_FILE <- here::here("data", "external", "ca_monthly_rainfall.csv")
OUT          <- here::here("data", "interim",  "ca_wateryear_precip.csv")

# ---- 1. Preferred path: the official NOAA statewide series -----------
if (file.exists(NOAA_FILE)) {

  message("Using OFFICIAL NOAA statewide series: ", NOAA_FILE)

  # Climate at a Glance ships two comment lines before the header:
  #   # California October-September Precipitation
  #   # Units: Inches
  #   Date,Value
  # Date is YYYYMM with MM = 09 (the month the water year ends), so the
  # first four characters are the water year.
  x <- utils::read.csv(NOAA_FILE, skip = 2, stringsAsFactors = FALSE,
                       colClasses = c("character", "numeric"))
  stopifnot(all(c("Date", "Value") %in% names(x)))

  precip <- data.frame(water_year = as.integer(substr(x$Date, 1, 4)),
                       precip_in  = x$Value,
                       stringsAsFactors = FALSE)
  precip_source <- "NOAA Climate at a Glance statewide (official)"
  n_stations    <- NA_integer_

# ---- 2. Fallback path: station composite -----------------------------
} else {

  message("NOAA file not found at ", NOAA_FILE)
  message("FALLING BACK to the GHCN station composite.")

  if (!file.exists(STATION_FILE))
    stop("Neither the NOAA series nor ", STATION_FILE, " is available.",
         call. = FALSE)

  m <- utils::read.csv(STATION_FILE, stringsAsFactors = FALSE)
  stopifnot(all(c("id", "ym", "prcp") %in% names(m)))

  ymd <- as.Date(m$ym)
  cal_year <- as.integer(format(ymd, "%Y"))
  cal_mon  <- as.integer(format(ymd, "%m"))

  # Water year Y runs Oct(Y-1) .. Sep(Y), so Oct-Dec belong to Y+1.
  m$water_year <- ifelse(cal_mon >= 10, cal_year + 1L, cal_year)
  m$precip_in  <- m$prcp / MM_PER_IN
  m <- m[m$water_year >= WY_FIRST & m$water_year <= WY_LAST, ]

  # A station contributes to a water year only if it reported all 12
  # months; partial years would bias the total downward.
  station_wy <- tapply(m$precip_in, list(m$id, m$water_year),
                       function(v) if (length(v) == 12) sum(v) else NA_real_)

  precip <- data.frame(
    water_year = as.integer(colnames(station_wy)),
    precip_in  = colMeans(station_wy, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
  n_stations    <- colSums(!is.na(station_wy))
  precip_source <- "GHCN station composite (NOAA CaG unavailable)"
}

precip <- precip[precip$water_year >= WY_FIRST &
                 precip$water_year <= WY_LAST, ]
precip <- precip[order(precip$water_year), ]
precip$precip_in <- round(precip$precip_in, 2)
if (length(n_stations) > 1) precip$n_stations <- as.integer(n_stations)
precip$precip_source <- precip_source

# ---- 3. Validate ------------------------------------------------------
n_expected <- WY_LAST - WY_FIRST + 1
if (nrow(precip) != n_expected)
  stop("Expected ", n_expected, " water years, got ", nrow(precip), ".")
if (!identical(precip$water_year, WY_FIRST:WY_LAST))
  stop("Water years are not a complete consecutive run.")
stopifnot(!anyNA(precip$precip_in), all(precip$precip_in > 0))

# A calendar-year series would slip through every check above, so test
# the one thing that actually distinguishes it: CA's driest water year
# is 1977, while its driest CALENDAR year is 2013.
driest <- precip$water_year[which.min(precip$precip_in)]
if (identical(driest, 2013L))
  warning("Driest year is 2013, which is the driest CALENDAR year. ",
          "This looks like a calendar-year series, not a water-year ",
          "series. Check the source file.", call. = FALSE)

dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(precip, OUT, row.names = FALSE)

message("Wrote ", OUT, ": ", nrow(precip), " water years.")
message("  source : ", precip_source)
message(sprintf("  mean %.2f  sd %.2f  min %.2f  max %.2f in",
                mean(precip$precip_in), stats::sd(precip$precip_in),
                min(precip$precip_in), max(precip$precip_in)))
message("  driest ", driest, " / wettest ",
        precip$water_year[which.max(precip$precip_in)])
