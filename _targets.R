library(targets)
library(tarchetypes)

# Source all functions in R/*.R
tar_source()

tar_option_set(
  packages = c(
    "tidyverse",
    "here",
    "sf",
    "httr",
    "jsonlite"
  )
)

list(

  # **** Boundaries ****

  # Sheffield City boundary (SCC AGOL API)
  tar_target(
    sf_city,
    get_boundary_city()
  ),

  # Sheffield LSOAs (ONS Open Geography Portal API)
  tar_target(
    sf_lsoa,
    get_boundary_lsoa()
  ),

  # **** OS NGD - Road Network ****
  # GeoPackage files downloaded from OS Data Hub.
  # Targets track the file modification time. If the source files are refreshed
  # downstream targets will automatically re-run.

  tar_target(file_ngd_road, get_ngd_road(), format = "file"),
  tar_target(file_ngd_roadlink, get_ngd_roadlink(), format = "file"),
  tar_target(file_ngd_roadnode, get_ngd_roadnode(), format = "file"),
  tar_target(file_ngd_speed, get_ngd_speed(), format = "file"),
  tar_target(file_ngd_highway, get_ngd_highway(), format = "file"),

  tar_target(sf_ngd_road, sf::read_sf(file_ngd_road, layer = "trn_ntwk_road")),
  tar_target(
    sf_ngd_roadlink, 
    sf::read_sf(file_ngd_roadlink, layer = "trn_ntwk_roadlink")
  ),
  tar_target(
    sf_ngd_roadnode, 
    sf::read_sf(file_ngd_roadnode, layer = "trn_ntwk_roadnode")
  ),
  tar_target(
    sf_ngd_speed, 
    sf::read_sf(file_ngd_speed, layer = "trn_rami_averageandindicativespeed")
  ),
  tar_target(
    sf_ngd_highway,
    sf::read_sf(file_ngd_highway, layer = "trn_rami_highwaydedication")
  ),

  # **** DfT Traffic (API) ****

  # Road category lookup (hardcoded, based on DfT metadata)
  tar_target(
    df_road_category_description,
    get_road_category_description()
  ),

  # Average Annual Daily Flow per count point
  tar_target(
    df_flow,
    get_flow()
  ),

  # Hourly raw traffic counts (used to derive traffic intensity & peak ratios)
  tar_target(
    df_raw_count,
    get_raw_count()
  ),

  # **** IMD 2025 ****

  tar_target(
    sf_lsoa_imd,
    get_lsoa_imd()
  ),

  # **** NaPTAN (bus stops) ****

  tar_target(
    file_naptan,
    get_naptan_file(),
    format = "file"
  ),

  tar_target(
    df_naptan,
    readr::read_csv(file_naptan, show_col_types = FALSE)
  ),

  # **** Census 2021 ****

  # TS006 - Population density
  tar_target(
    file_census_population,
    get_census_population_file(),
    format = "file"
  ),

  tar_target(
    df_census_population,
    readr::read_csv(file_census_population, show_col_types = FALSE)
  ),

  # TS045 - Car or van availability
  tar_target(
    file_census_cars,
    get_census_cars_file(),
    format = "file"
  ),

  tar_target(
    df_census_cars,
    readr::read_csv(file_census_cars, show_col_types = FALSE)
  ),

  # TS066 - Economic activity status (unemployment rate for employment deprivation)
  tar_target(
    file_census_economic_activity,
    get_census_economic_activity_file(),
    format = "file"
  ),

  tar_target(
    df_census_economic_activity,
    readr::read_csv(file_census_economic_activity, show_col_types = FALSE)
  ),

  # TS060 - Industry of employment (MSOA level is finest geography ONS publish)
  tar_target(
    file_census_employment,
    get_census_employment_file(),
    format = "file"
  ),

  tar_target(
    df_census_employment,
    readr::read_csv(file_census_employment, show_col_types = FALSE)
  ),

  # **** Process ****
  # One target per source, each returning a data frame keyed on LSOA21CD

  # Road network (OS NGD) — computationally expensive spatial intersections
  tar_target(
    df_lsoa_road_network,
    process_lsoa_road_network(sf_ngd_roadlink, sf_ngd_roadnode, sf_lsoa)
  ),

  tar_target(
    df_lsoa_speed,
    process_lsoa_speed(sf_ngd_speed, sf_lsoa)
  ),

  tar_target(
    df_lsoa_cycling,
    process_lsoa_cycling(sf_ngd_highway, sf_lsoa)
  ),

  # Traffic (DfT)
  tar_target(
    df_lsoa_traffic,
    process_lsoa_traffic(df_flow, sf_lsoa)
  ),

  # Accessibility
  tar_target(
    df_lsoa_city_centre_dist,
    process_lsoa_city_centre_dist(sf_lsoa)
  ),

  # Bus stops (NaPTAN)
  tar_target(
    df_lsoa_bus_stops,
    process_lsoa_bus_stops(df_naptan, sf_lsoa)
  ),

  # Census 2021
  tar_target(
    df_lsoa_population,
    process_lsoa_census_population(df_census_population)
  ),

  tar_target(
    df_lsoa_cars,
    process_lsoa_census_cars(df_census_cars)
  ),

  tar_target(
    df_lsoa_economic_activity,
    process_lsoa_economic_activity(df_census_economic_activity)
  )

)
