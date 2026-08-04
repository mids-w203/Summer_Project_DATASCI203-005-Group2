# =====================================================================
# make_ca_rainfall_enso_model_data.R
#
# Builds data/processed/ca_rainfall_enso_model_data.csv: monthly mean
# station precipitation for Northern and Southern California, joined
# with the monthly Oceanic Nino Index and an ENSO phase label.
#
# Pipeline (see src/data/README):
#   data/external/ca_station_list.csv   long-record CA PRCP stations
#   data/external/ghcnd/<id>.csv        raw GHCN-Daily downloads (cached)
#   data/processed/ca_rainfall_enso_model_data.csv   output
#
# Output columns:
#   region      "NorCal" (lat >= 36 N) or "SoCal"
#   ym          first day of month (Date)
#   prcp        mean across reporting stations of the station's
#               monthly precipitation total, in mm
#   n_stations  number of stations contributing that month
#   oni         monthly Oceanic Nino Index (rsoi), 2 dp; NA before 1950
#   month       calendar month (1-12)
#   phase       "ElNino" (oni >= 0.5), "LaNina" (oni <= -0.5),
#               otherwise "Neutral" (including months with no ONI)
#
# Requires: rsoi, here. First run downloads ~284 station files
# (roughly 1-2 GB); they are cached in data/external/ghcnd/ and
# reused on later runs.
#
# Usage: Rscript src/data/make_ca_rainfall_enso_model_data.R
#        (or source() it from make_analysis_data.R)
# =====================================================================

for (p in c("rsoi", "here"))
  if (!requireNamespace(p, quietly = TRUE))
    stop("Package '", p, "' is not installed. Run: install.packages(\"",
         p, "\")", call. = FALSE)

LAT_SPLIT <- 36                      # >= 36 N is NorCal
STATIONS  <- here::here("data", "external", "ca_station_list.csv")
RAW_DIR   <- here::here("data", "external", "ghcnd")
OUT       <- here::here("data", "processed", "ca_rainfall_enso_model_data.csv")
GHCND_URL <- "https://www.ncei.noaa.gov/data/global-historical-climatology-network-daily/access/%s.csv"

dir.create(RAW_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)

# ---- 1. Station list + region assignment -----------------------------
stations <- read.csv(STATIONS, stringsAsFactors = FALSE)
stopifnot(all(c("id", "lat") %in% names(stations)))
stations$region <- ifelse(stations$lat >= LAT_SPLIT, "NorCal", "SoCal")
message(nrow(stations), " stations: ",
        sum(stations$region == "NorCal"), " NorCal / ",
        sum(stations$region == "SoCal"), " SoCal")

# ---- 2. Download (cached) and reduce each station to monthly totals --
# GHCN-Daily reports PRCP in tenths of mm; dividing by 10 gives mm.
# A station contributes to a month if it has at least one non-missing
# daily value that month.
station_monthly <- function(id, region) {
  dest <- file.path(RAW_DIR, paste0(id, ".csv"))
  if (!file.exists(dest)) {
    ok <- tryCatch(
      download.file(sprintf(GHCND_URL, id), dest, quiet = TRUE, mode = "wb"),
      error = function(e) 1L)
    if (!identical(ok, 0L)) { unlink(dest); return(NULL) }
  }
  x <- tryCatch(read.csv(dest, stringsAsFactors = FALSE),
                error = function(e) NULL)
  if (is.null(x) || !"PRCP" %in% names(x)) return(NULL)

  x <- x[!is.na(x$PRCP), c("DATE", "PRCP")]
  if (nrow(x) == 0) return(NULL)

  ym  <- substr(x$DATE, 1, 7)                        # "YYYY-MM"
  tot <- tapply(x$PRCP / 10, ym, sum)                # monthly total, mm
  data.frame(region = region, ym = names(tot),
             prcp_station = as.numeric(tot), stringsAsFactors = FALSE)
}

monthly <- do.call(rbind, Map(station_monthly, stations$id, stations$region))
message("Monthly station totals: ", nrow(monthly), " station-months")

# ---- 3. Aggregate to region-month: mean prcp + station count ---------
agg <- aggregate(prcp_station ~ region + ym, monthly,
                 function(v) c(mean = mean(v), n = length(v)))
rain <- data.frame(region     = agg$region,
                   ym         = as.Date(paste0(agg$ym, "-01")),
                   prcp       = agg$prcp_station[, "mean"],
                   n_stations = as.integer(agg$prcp_station[, "n"]),
                   stringsAsFactors = FALSE)

# ---- 4. Monthly ONI via rsoi, joined by month ------------------------
oni_raw <- as.data.frame(rsoi::download_oni())
stopifnot(all(c("Date", "ONI") %in% names(oni_raw)))
oni <- data.frame(ym  = as.Date(format(oni_raw$Date, "%Y-%m-01")),
                  oni = round(oni_raw$ONI, 2))

out <- merge(rain, oni, by = "ym", all.x = TRUE)     # NA before 1950-01
out$month <- as.integer(format(out$ym, "%m"))
out$phase <- ifelse(!is.na(out$oni) & out$oni >=  0.5, "ElNino",
             ifelse(!is.na(out$oni) & out$oni <= -0.5, "LaNina", "Neutral"))

# ---- 5. Order columns and rows, then write ---------------------------
out <- out[order(out$region, out$ym),
           c("region", "ym", "prcp", "n_stations", "oni", "month", "phase")]

stopifnot(!anyNA(out$prcp), all(out$n_stations >= 1),
          all(out$phase %in% c("ElNino", "LaNina", "Neutral")))

write.csv(out, OUT, row.names = FALSE, na = "NA", quote = FALSE)
message("Wrote ", OUT, ": ", nrow(out), " region-months (",
        sum(out$region == "NorCal"), " NorCal / ",
        sum(out$region == "SoCal"), " SoCal)")

# ---- 6. Sanity-check scatter: monthly precipitation vs ONI -----------
# A quick visual of the project's core relationship -- do wetter months
# line up with higher ONI (El Nino)? Written to a PNG (base graphics) so
# it also works when the script is run non-interactively via Rscript.
FIG <- here::here("reports", "figures", "precip_vs_oni.png")
dir.create(dirname(FIG), showWarnings = FALSE, recursive = TRUE)

plot_df    <- out[!is.na(out$oni), ]                 # ONI is NA before 1950
region_col <- c(NorCal = "#2a78d6", SoCal = "#eb6834")

png(FIG, width = 1800, height = 1200, res = 300)
plot(plot_df$oni, plot_df$prcp,
     col  = region_col[plot_df$region], pch = 19, cex = 0.4,
     xlab = "Monthly Oceanic Nino Index (ONI, deg C)",
     ylab = "Monthly mean station precipitation (mm)",
     main = "California monthly precipitation vs ENSO (ONI)")
abline(v = c(-0.5, 0.5), lty = 3, col = "grey60")    # El Nino / La Nina cutoffs
legend("topright", legend = names(region_col),
       col = region_col, pch = 19, bty = "n")
invisible(dev.off())
message("Wrote ", FIG)
