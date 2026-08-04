# =====================================================================
# make_soi_wateryear.R
# Layer 2 of the pipeline (see src/data/README):
#   reads/saves raw  -> data/external/soi_download.txt   (unedited)
#   derives interim  -> data/interim/soi_ndjfm_wateryear.csv
#
# Builds the REVERSED Southern Oscillation Index, averaged over the
# Nov-Mar wet season of each water year. All SOI derivation lives HERE
# and nowhere else (assignment guidance point 5).
#
# SIGN CONVENTION: raw SOI is NEGATIVE during El Nino (Tahiti pressure
# falls relative to Darwin). We multiply by -1 so that, like the ONI,
# POSITIVE = El Nino. Hence "reversed" SOI, the report's `rsoi`.
#
# COVERAGE: CPC's SOI table begins in 1951, and the Nov-Mar window for
# water year Y needs Nov-Dec of Y-1. WY1950 and WY1951 are therefore
# incomplete and come out NA. This is expected -- `rsoi` is a secondary
# operationalization; `oni_djf` is the primary measure and covers all
# 76 water years.
#
# Requires: here
# Usage: Rscript src/data/make_soi_wateryear.R
# =====================================================================

if (!requireNamespace("here", quietly = TRUE))
  stop("Package 'here' is not installed. Run: install.packages(\"here\")",
       call. = FALSE)

WY_FIRST <- 1950
WY_LAST  <- 2025

CPC_URL <- "https://www.cpc.ncep.noaa.gov/data/indices/soi"
RAW <- here::here("data", "external", "soi_download.txt")
OUT <- here::here("data", "interim",  "soi_ndjfm_wateryear.csv")

# ---- 1. Download; preserve the raw layer ------------------------------
dir.create(dirname(RAW), showWarnings = FALSE, recursive = TRUE)
ok <- tryCatch(utils::download.file(CPC_URL, RAW, quiet = TRUE, mode = "wb"),
               error = function(e) 1L)
if (!identical(ok, 0L))
  stop("Could not download the SOI table from CPC (network problem?):\n  ",
       CPC_URL, call. = FALSE)
message("Raw download preserved at ", RAW)

# ---- 2. Parse the ANOMALY block ---------------------------------------
# The file holds two stacked tables: ANOMALY first, then STANDARDIZED
# DATA. Both start with a "YEAR JAN ... DEC" header. We take the first
# (anomaly) block, which is the series the report describes.
lines <- readLines(RAW, warn = FALSE)
hdr <- grep("^\\s*YEAR", lines)
if (length(hdr) == 0L) stop("Could not find a 'YEAR' header row in the SOI file.")

std_start <- grep("STANDARDIZED", lines)
block_end <- if (length(std_start)) std_start[1] - 1L else length(lines)
body <- lines[(hdr[1] + 1L):block_end]

# Data rows start with a 4-digit year; -999.9 is CPC's missing marker.
body <- body[grepl("^\\s*\\d{4}", body)]

# FIXED WIDTH, not whitespace-delimited: a 4-char year followed by twelve
# 6-char fields. Negative missing codes butt straight up against the
# preceding value ("2030-999.9-999.9..."), so splitting on whitespace
# silently mangles the year. read.fwf is the only safe reader here.
tab <- utils::read.fwf(textConnection(body), widths = c(4, rep(6, 12)),
                       header = FALSE)
names(tab) <- c("year", month.abb)
tab$year <- as.integer(tab$year)
for (mn in month.abb) tab[[mn]] <- suppressWarnings(as.numeric(tab[[mn]]))
tab[, month.abb][tab[, month.abb] <= -99] <- NA   # CPC missing marker

message("SOI table: ", nrow(tab), " years, ",
        min(tab$year), "-", max(tab$year))

# ---- 3. Long form, then Nov-Mar mean per water year -------------------
long <- data.frame(
  year  = rep(tab$year, times = 12),
  month = rep(1:12, each = nrow(tab)),
  soi   = unlist(tab[, month.abb], use.names = FALSE)
)

# Nov-Mar of water year Y = Nov(Y-1), Dec(Y-1), Jan(Y), Feb(Y), Mar(Y).
long <- long[long$month %in% c(11, 12, 1, 2, 3), ]
long$water_year <- ifelse(long$month >= 11, long$year + 1L, long$year)

# Require all five months; otherwise the mean is not comparable.
agg <- tapply(long$soi, long$water_year,
              function(v) if (sum(!is.na(v)) == 5L) mean(v) else NA_real_)

soi <- data.frame(
  water_year = as.integer(names(agg)),
  # Reverse the sign so positive = El Nino, matching the ONI.
  rsoi       = round(-1 * as.numeric(agg), 3),
  stringsAsFactors = FALSE
)
soi <- soi[soi$water_year >= WY_FIRST & soi$water_year <= WY_LAST, ]

# Pad to the full water-year frame so the join in make_analysis_data.R
# always lines up, even for the years CPC cannot cover.
soi <- merge(data.frame(water_year = WY_FIRST:WY_LAST), soi,
             by = "water_year", all.x = TRUE)
soi <- soi[order(soi$water_year), ]

# ---- 4. Write ---------------------------------------------------------
stopifnot(nrow(soi) == WY_LAST - WY_FIRST + 1)

dir.create(dirname(OUT), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(soi, OUT, row.names = FALSE)

n_ok <- sum(!is.na(soi$rsoi))
message("Wrote ", OUT, ": ", nrow(soi), " water years, ",
        n_ok, " with a complete Nov-Mar window.")
if (n_ok < nrow(soi))
  message("  (missing: ",
          paste(soi$water_year[is.na(soi$rsoi)], collapse = ", "),
          " -- CPC's SOI series starts in 1951)")
