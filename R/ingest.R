# Functions to acquire raw datasets for the transport environment typology.

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

get_lsoa_ward <- function() {
  # LSOA (2021) to Electoral Ward (2025) Best Fit Lookup for Sheffield
  # ONS Open Geography Portal
  # Source: https://geoportal.statistics.gov.uk/datasets/ons::lsoa-2021-to-electoral-ward-2025-to-lad-2025-best-fit-lookup-in-ew-v2/about
  
  base_url <- "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/LSOA21_WD25_LAD25_EW_LU_v2/FeatureServer/0/query"
  
  query <- paste0(
    base_url,
    "?where=", utils::URLencode("LSOA21NM LIKE 'Sheffield%'", reserved = TRUE),
    "&outFields=*&returnGeometry=false&f=json"
  )
  
  result <- jsonlite::fromJSON(query, simplifyVector = TRUE)
  tibble::as_tibble(result$features$attributes) |> 
    dplyr::select(!dplyr::ends_with("NMW"))
}

# **** OS NGD ****
# Files are downloaded from the OS Downloads API using the data package
# "NGD Transport - Sheffield" (ID: 22969) under the OS Public Sector Plan.
# Authentication uses an API key stored in the OS_API_KEY environment variable.
# Set this in your .Renviron file: OS_API_KEY=your_key_here
#
# targets caches the downloaded file hashes, so re-downloads only occur when
# the file content changes on disk (i.e. a new OS release is fetched manually
# by invalidating the target with tar_invalidate("file_ngd_*")).

NGD_PACKAGE_ID <- "22969"
NGD_DIR <- here::here("data", "raw", "NGD Transport Sheffield")

# Retrieve the OS API key from the OS_API_KEY environment variable.
os_api_key <- function() {
  key <- Sys.getenv("OS_API_KEY")
  if (!nzchar(key)) {
    stop(
      "OS_API_KEY environment variable is not set. ",
      "Add it to .Renviron: OS_API_KEY=your_key_here"
    )
  }
  key
}

# Download a single GeoPackage from the OS Downloads API.
# Queries the latest version of the given data package, finds a file whose
# name contains `layer_name`, downloads it (unzipping if necessary), and
# copies the .gpkg to `out_path`. Returns `out_path`.
os_download_ngd_gpkg <- function(package_id, layer_name, out_path) {
  key <- os_api_key()

  # Get latest version metadata (includes downloads list)
  version_resp <- httr::GET(
    paste0(
      "https://api.os.uk/downloads/v1/dataPackages/",
      package_id,
      "/versions/latest"
    ),
    httr::add_headers(key = key)
  )
  httr::stop_for_status(version_resp)
  version_info <- jsonlite::fromJSON(
    httr::content(version_resp, "text", encoding = "UTF-8")
  )

  # Match a download entry by layer name
  downloads  <- version_info$downloads
  match_idx  <- which(grepl(layer_name, downloads$fileName, ignore.case = TRUE))
  if (length(match_idx) == 0) {
    stop(
      "No download matching '", layer_name, "' found in package ", package_id, ". ",
      "Available files: ", paste(downloads$fileName, collapse = ", ")
    )
  }
  dl_url      <- downloads$url[match_idx[1]]
  dl_filename <- downloads$fileName[match_idx[1]]

  # Download to a temp file
  tf <- tempfile(fileext = tools::file_ext(dl_filename))
  dl_resp <- httr::GET(
    dl_url,
    httr::add_headers(key = key),
    httr::write_disk(tf, overwrite = TRUE)
  )
  httr::stop_for_status(dl_resp)

  # Extract .gpkg (handle both zip archives and direct .gpkg downloads)
  dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)

  if (grepl("\\.zip$", dl_filename, ignore.case = TRUE)) {
    td <- tempfile()
    dir.create(td, recursive = TRUE)
    utils::unzip(tf, exdir = td)
    gpkg_files <- list.files(
      td, pattern = "\\.gpkg$", full.names = TRUE, recursive = TRUE
    )
    if (length(gpkg_files) == 0) {
      stop("No .gpkg file found inside downloaded zip for layer: ", layer_name)
    }
    file.copy(gpkg_files[1], out_path, overwrite = TRUE)
  } else {
    file.copy(tf, out_path, overwrite = TRUE)
  }

  out_path
}

get_ngd_road <- function(
    out_path = file.path(NGD_DIR, "trn_ntwk_road.gpkg")
) {
  os_download_ngd_gpkg(NGD_PACKAGE_ID, "trn_ntwk_road", out_path)
}

get_ngd_roadlink <- function(
    out_path = file.path(NGD_DIR, "trn_ntwk_roadlink.gpkg")
) {
  os_download_ngd_gpkg(NGD_PACKAGE_ID, "trn_ntwk_roadlink", out_path)
}

get_ngd_roadnode <- function(
    out_path = file.path(NGD_DIR, "trn_ntwk_roadnode.gpkg")
) {
  os_download_ngd_gpkg(NGD_PACKAGE_ID, "trn_ntwk_roadnode", out_path)
}

get_ngd_speed <- function(
    out_path = file.path(NGD_DIR, "trn_rami_averageandindicativespeed.gpkg")
) {
  # Average and indicative speeds per road link
  os_download_ngd_gpkg(NGD_PACKAGE_ID, "trn_rami_averageandindicativespeed", out_path)
}

get_ngd_highway <- function(
    out_path = file.path(NGD_DIR, "trn_rami_highwaydedication.gpkg")
) {
  # Highway dedication (cycle routes, footways etc.)
  os_download_ngd_gpkg(NGD_PACKAGE_ID, "trn_rami_highwaydedication", out_path)
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

get_imd <- function() {
  # Indices of Deprivation 2025 at LSOA level for Sheffield
  # MHCLG GeoPortal
  # Source: https://www.arcgis.com/home/item.html?id=0fddc254c1184386bbeed27ed49bbd03#overview
  URLencode("https://services-eu1.arcgis.com/EbKcOS6EXZroSyoi/arcgis/rest/services/LSOA_IMD2025_WGS84/FeatureServer/0/query?where=LSOA21NM LIKE 'Sheffield%'&outFields=*&f=geojson") |>
    sf::read_sf() |> 
    sf::st_transform(27700)
}

# **** NaPTAN (bus stops) ****

get_naptan_file <- function(
    out_path = here::here("data", "raw", "NaPTAN", "naptan_sheffield.csv")
) {
  # All NaPTAN access nodes for South Yorkshire (ATCO area code 370 = Sheffield)
  # Source: https://beta-naptan.dft.gov.uk/
  url <- paste0(
    "https://naptan.api.dft.gov.uk/v1/access-nodes",
    "?dataFormat=csv&ATCOAreaCode=370"
  )
  dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
  resp <- httr::GET(url, httr::write_disk(out_path, overwrite = TRUE))
  httr::stop_for_status(resp)
  out_path
}

# **** OAC ****

OAC_DIR <- here::here("data", "raw", "OAC")

get_oac_file <- function(
    out_path = here::here(OAC_DIR, "lsoa_dz_sdz_lookup.csv")
) {
  # UK LSOA / DZ / SDZ Classification (2021/2 LSOAC)
  # Source: https://data.geods.ac.uk/dataset/lsoac
  url <- paste0(
    "https://data.geods.ac.uk/dataset/",
    "d257ab6a-2353-4aec-b6f7-2c3dbc359766/resource/",
    "92de7c1f-07a8-440c-8793-203fe61d3005/download/",
    "lsoa_dz_sdz_lookup.csv"
  )
  dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
  resp <- httr::GET(url, httr::write_disk(out_path, overwrite = TRUE))
  httr::stop_for_status(resp)
  out_path
}

get_oac_names_file <- function(
    out_path = here::here(
      OAC_DIR, "classification_codes_and_names_ukoac_lsoac.csv"
    )
) {
  
  # File with names for different classification codes
  # Source: https://data.geods.ac.uk/dataset/lsoac
  url <- paste0(
    "https://data.geods.ac.uk/dataset/",
    "d257ab6a-2353-4aec-b6f7-2c3dbc359766/resource/",
    "8f2e48a0-7900-47b5-b41e-c7fd8e303c3d/download/",
    "classification_codes_and_names_ukoac_lsoac.csv"
  )
  dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
  resp <- httr::GET(url, httr::write_disk(out_path, overwrite = TRUE))
  httr::stop_for_status(resp)
  out_path
}

# **** Census 2021 (NOMIS bulk downloads) ****
# NOMIS bulk CSV files are zip archives containing one CSV per geography level
# See https://www.nomisweb.co.uk/sources/census_2021_bulk

CENSUS_DIR <- here::here("data", "raw", "census")

get_census_population_file <- function(
    out_path = here::here(CENSUS_DIR, "census2021_ts006_lsoa.csv")
) {
  # TS006 - Population density (persons per sq km) at LSOA level
  get_nomis_census_lsoa("ts006", out_path)
}

get_census_cars_file <- function(
    out_path = here::here(CENSUS_DIR, "census2021_ts045_lsoa.csv")
) {
  # TS045 - Car or van availability at LSOA level
  get_nomis_census_lsoa("ts045", out_path)
}

get_census_economic_activity_file <- function(
    out_path = here::here(CENSUS_DIR, "census2021_ts066_lsoa.csv")
) {
  # TS066 - Economic activity status at LSOA level.
  # Provides unemployment rate as a direct proxy for employment deprivation.
  # Note: TS066, not TS060 (which is Industry).
  get_nomis_census_lsoa("ts066", out_path)
}

get_census_employment_file <- function(
    out_path = here::here(CENSUS_DIR, "census2021_ts060_msoa.csv")
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
  
  dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)

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
