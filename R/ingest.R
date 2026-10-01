# Functions to acquire raw datasets for the transport environment typology.

# **** Manual downloads ****

# Datasets that were downloaded manually are referenced by a relative path here 

NGD_DIR <- here::here("data", "download", "NGD Traffic Speed Sheffield")

# **** Boundaries ****
# Sheffield local authority ID for ONS is E08000019

get_boundary_city <- function() {
  # Sheffield City boundary
  # SCC AGOL 
  # Source: https://sheffieldcc.maps.arcgis.com/home/item.html?id=97cfdc3a164c48219826b907c0a5064f#overview
  sf::read_sf("https://utility.arcgis.com/usrsvcs/servers/97cfdc3a164c48219826b907c0a5064f/rest/services/AGOL/Boundaries/MapServer/0/query?where=1%3D1&outFields=*&returnGeometry=true&f=geojson") |> 
    sf::st_transform(27700)
}

get_boundary_lsoa <- function() {
  # 2021 generalised (20m) LSOA boundaries for Sheffield
  # ONS Open Geography Portal
  # Source: https://geoportal.statistics.gov.uk/datasets/ons::lower-layer-super-output-areas-december-2021-boundaries-ew-bgc-v5-2/about
  URLencode("https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/Lower_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V5/FeatureServer/0/query?where=LSOA21NM LIKE 'Sheffield%'&outFields=*&f=geojson") |>
    sf::read_sf() |> 
    sf::st_transform(27700)
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

# **** IMD 2025 ****

get_lsoa_imd <- function() {
  # Indices of Deprivation 2025 at LSOA level for Sheffield
  # MHCLG GeoPortal
  # Source: https://www.arcgis.com/home/item.html?id=0fddc254c1184386bbeed27ed49bbd03#overview
  URLencode("https://services-eu1.arcgis.com/EbKcOS6EXZroSyoi/arcgis/rest/services/LSOA_IMD2025_WGS84/FeatureServer/0/query?where=LSOA21NM LIKE 'Sheffield%'&outFields=*&f=geojson") |>
    sf::read_sf() |> 
    sf::st_transform(27700)
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
