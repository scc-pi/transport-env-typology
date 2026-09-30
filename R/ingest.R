# Functions to acquire raw datasets for the transport environment typology.

# **** Manual downloads ****

# Some datasets were downloaded manually, and are referenced by
# a relative absolute path here. 

NGD_DIR <- here::here("data", "download", "NGD Traffic Speed Sheffield")
CITY_BOUNDARY_DIR <- here::here("data", "download")

# **** Boundaries ****

get_boundary_city <- function() {
  file.path(CITY_BOUNDARY_DIR, "city.gpkg")
}

get_boundary_lsoa <- function(
    out_path = here::here("data", "boundaries", "lsoa.gpkg")
) {
  # 2011 LSOA boundaries (generalised, clipped) for Sheffield.
  # Note: using 2011 boundaries because the 2021 boundary service is not
  # currently published on the ONS Open Geography ArcGIS server. The 2011
  # LSOA codes align directly with IMD 2019. Census 2021 data will require
  # joining via the ONS LSOA 2011 to 2021 lookup table.
  # Source: ONS Open Geography Portal
  resp <- httr::GET(
    paste0(
      "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
      "LSOA_Dec_2011_Boundaries_Generalised_Clipped_BGC_EW_V3/FeatureServer/0/query"
    ),
    query = list(
      where          = "LSOA11NM LIKE 'Sheffield%'",
      outFields      = "LSOA11CD,LSOA11NM",
      returnGeometry = "true",
      f              = "geojson"
    )
  )
  httr::stop_for_status(resp)

  # Write raw GeoJSON to a temp file then read as sf
  # (sf::read_sf() cannot handle special characters in URLs directly)
  tf <- tempfile(fileext = ".geojson")
  writeBin(httr::content(resp, "raw"), tf)
  on.exit(unlink(tf))

  sf::read_sf(tf) |>
    sf::write_sf(out_path, delete_dsn = TRUE)
  out_path
}

# **** OS NGD **** 

get_ngd_road <- function() {
  file.path(NGD_DIR, "trn_ntwk_road.gpkg")
}

get_ngd_roadlink <- function() {
  file.path(NGD_DIR, "trn_ntwk_roadlink.gpkg")
}

get_ngd_roadnode <- function() {
  file.path(NGD_DIR, "trn_ntwk_roadnode.gpkg")
}

get_ngd_speed <- function() {
  # Average and indicative speeds per road link
  file.path(NGD_DIR, "trn_rami_averageandindicativespeed.gpkg")
}

get_ngd_highway <- function() {
  # Highway dedication (cycle routes, footways etc.)
  file.path(NGD_DIR, "trn_rami_highwaydedication.gpkg")
}

# **** DfT Traffic (API) ****
# Sheffield local authority ID on the DfT Road Traffic Statistics API is 159

get_road_category_description <- function() {
  # Source: https://storage.googleapis.com/dft-statistics/road-traffic/all-traffic-data-metadata.pdf
  tibble::tribble(
    ~category, ~category_description,
    "PM",      "M or Class A Principal Motorway",
    "PA",      "Class A Principal road",
    "TM",      "M or Class A Trunk Motorway",
    "TA",      "Class A Trunk road",
    "M",       "Minor road",
    "MB",      "Class B road",
    "MCU",     "Class C road or Unclassified road"
  )
}

get_flow <- function(year = 2024) {
  # Average Annual Daily Flow (AADF) per count point
  result <- httr::GET(
    "https://roadtraffic.dft.gov.uk/api/average-annual-daily-flow",
    query = list(
      "filter[local_authority_id]" = 159,
      "filter[year]"               = year,
      "page[size]"                 = 1000
    )
  )
  jsonlite::fromJSON(httr::content(result, "text"), flatten = TRUE)$data
}

get_raw_count <- function() {
  # Hourly raw traffic counts - paginated API
  base_url  <- "https://roadtraffic.dft.gov.uk/api/raw-counts"
  page      <- 1
  all_pages <- list()
  repeat {
    result <- httr::GET(
      base_url,
      query = list(
        "filter[local_authority_id]" = 159,
        "page[size]"                 = 10000,
        "page[number]"               = page
      )
    )
    json           <- httr::content(result, as = "text") |>
      jsonlite::fromJSON(flatten = TRUE)
    all_pages[[page]] <- json$data
    if (page >= json$last_page) break
    page <- page + 1
  }
  do.call(rbind, all_pages)
}

# **** IMD 2019 ****

get_imd_file <- function(
    out_path = here::here("data", "raw", "imd2019.csv")
) {
  # English Indices of Deprivation 2019 - scores, ranks, deciles at LSOA level
  # Source: https://www.gov.uk/government/statistics/english-indices-of-deprivation-2019
  url <- paste0(
    "https://assets.publishing.service.gov.uk/government/uploads/system/",
    "uploads/attachment_data/file/845345/",
    "File_7_-_All_IoD2019_Scores__Ranks__Deciles_and_Population_Denominators_3.csv"
  )
  httr::GET(url, httr::write_disk(out_path, overwrite = TRUE))
  out_path
}

# **** NaPTAN (bus stops) ****

get_naptan_file <- function(
    out_path = here::here("data", "raw", "naptan_sheffield.csv")
) {
  # All NaPTAN access nodes for South Yorkshire (ATCO area code 370 = Sheffield)
  # Source: https://www.data.gov.uk/dataset/naptan
  url <- "https://naptan.api.dft.gov.uk/v1/access-nodes?dataFormat=csv&ATCOAreaCode=370"
  httr::GET(url, httr::write_disk(out_path, overwrite = TRUE))
  out_path
}

# **** Census 2021 (NOMIS bulk downloads) ****
# NOMIS bulk CSV files are zip archives containing one CSV per geography level
# See https://www.nomisweb.co.uk/sources/census_2021_bulk

get_census_population_file <- function(
    out_path = here::here("data", "raw", "census2021_ts006_lsoa.csv")
) {
  # TS006 - Population density (persons per sq km) at LSOA level
  get_nomis_census_lsoa("ts006", out_path)
}

get_census_cars_file <- function(
    out_path = here::here("data", "raw", "census2021_ts045_lsoa.csv")
) {
  # TS045 - Car or van availability at LSOA level
  get_nomis_census_lsoa("ts045", out_path)
}

get_census_economic_activity_file <- function(
    out_path = here::here("data", "raw", "census2021_ts066_lsoa.csv")
) {
  # TS066 - Economic activity status at LSOA level.
  # Provides unemployment rate as a direct proxy for employment deprivation.
  # Note: TS066, not TS060 (which is Industry).
  get_nomis_census_lsoa("ts066", out_path)
}

get_census_employment_file <- function(
    out_path = here::here("data", "raw", "census2021_ts060_msoa.csv")
) {
  # TS060 - Industry of employment.
  # Note: TS060 is not published at LSOA level (ONS disclosure limitation);
  # the finest available geography is MSOA. Join to LSOAs via lookup if needed.
  # Note: TS060, not TS063 (which is Occupation).
  get_nomis_census_msoa("ts060", out_path)
}

# Helper: download a NOMIS Census 2021 bulk zip and extract the MSOA-level CSV
get_nomis_census_msoa <- function(table_code, out_path) {
  get_nomis_census_geography(table_code, "msoa", out_path)
}

# Helper: download a NOMIS Census 2021 bulk zip and extract the LSOA-level CSV
# Each zip (e.g. census2021-ts006.zip) contains one CSV per geography level
# The LSOA file is named census2021-tsXXX-lsoa.csv inside the archive.
get_nomis_census_lsoa <- function(table_code, out_path) {
  get_nomis_census_geography(table_code, "lsoa", out_path)
}

# Core helper used by all geography-level NOMIS wrappers above.
get_nomis_census_geography <- function(table_code, geography, out_path) {
  url <- paste0(
    "https://www.nomisweb.co.uk/output/census/2021/census2021-",
    table_code,
    ".zip"
  )
  tf <- tempfile(fileext = ".zip")
  httr::GET(url, httr::write_disk(tf, overwrite = TRUE))
  if (file.size(tf) == 0) stop("Downloaded zip is empty for: ", url)

  td <- tempfile()
  dir.create(td)
  utils::unzip(tf, exdir = td)

  pattern <- paste0("-", geography, "\\.csv$")
  csv <- list.files(td, pattern = pattern, full.names = TRUE)
  if (length(csv) == 0) {
    available <- paste(utils::unzip(tf, list = TRUE)$Name, collapse = ", ")
    stop(
      "No ", geography, " CSV found in zip for: ", url,
      "\nAvailable files: ", available
    )
  }
  file.copy(csv[[1]], out_path, overwrite = TRUE)
  out_path
}
