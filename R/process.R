# Functions to aggregate raw datasets to Sheffield LSOA level, producing one
# data frame per source ready to join into the analytical dataset.
#
# Functions that rely on OS NGD spatial data (road network, speed, cycling)
# are annotated with the expected field names based on the OS NGD schema.

# **** Helpers ****

# Project to British National Grid (EPSG:27700) for accurate length/area
to_bng <- function(sf_obj) sf::st_transform(sf_obj, 27700)

# Compute LSOA area in km² from sf_lsoa. Returns a plain data frame.
lsoa_area_km2 <- function(sf_lsoa) {
  sf_lsoa |>
    to_bng() |>
    dplyr::mutate(area_km2 = as.numeric(sf::st_area(geom)) / 1e6) |>
    sf::st_drop_geometry() |>
    dplyr::select(LSOA11CD, area_km2)
}

# Filter a Census 2021 bulk CSV to Sheffield rows (by the geography name column)
filter_sheffield_census <- function(df) {
  dplyr::filter(df, stringr::str_starts(geography, "Sheffield"))
}

# **** Road network (OS NGD) ****
# OS NGD RoadLink field names:
#   osid - unique road link ID
#   roadclassification - "A Road", "B Road", "Motorway", "Unclassified", etc.
#   geometry_length_m - pre-computed link length in metres (use for full links)
# RoadNode has no classification — only geometry is used (for junction counts).

process_lsoa_road_network <- function(sf_ngd_roadlink, sf_ngd_roadnode, sf_lsoa) {
  lsoa_bng <- to_bng(sf_lsoa)
  links_bng <- to_bng(sf_ngd_roadlink)
  nodes_bng <- to_bng(sf_ngd_roadnode)
  areas <- lsoa_area_km2(sf_lsoa)

  # Clip road links to LSOA boundaries and re-measure each clipped segment.
  message("Intersecting road links with LSOAs — this may take a moment...")
  links_clipped <- sf::st_intersection(
    dplyr::select(links_bng, osid, roadclassification),
    dplyr::select(lsoa_bng, LSOA11CD)
  ) |>
    dplyr::mutate(link_length_m = as.numeric(sf::st_length(geometry)))

  road_lengths <- links_clipped |>
    sf::st_drop_geometry() |>
    dplyr::group_by(LSOA11CD) |>
    dplyr::summarise(
      road_length_m   = sum(link_length_m, na.rm = TRUE),
      a_road_length_m = sum(
        link_length_m[grepl("A Road|Motorway", roadclassification)],
        na.rm = TRUE
      ),
      road_link_count = dplyr::n(),
      pct_a_road      = a_road_length_m / road_length_m,
      .groups = "drop"
    )

  # Count road nodes (junctions) falling within each LSOA.
  junction_counts <- sf::st_join(
    dplyr::select(nodes_bng, osid),
    dplyr::select(lsoa_bng, LSOA11CD),
    join = sf::st_within
  ) |>
    sf::st_drop_geometry() |>
    dplyr::filter(!is.na(LSOA11CD)) |>
    dplyr::count(LSOA11CD, name = "junction_count")

  areas |>
    dplyr::left_join(road_lengths, by = "LSOA11CD") |>
    dplyr::left_join(junction_counts, by = "LSOA11CD") |>
    dplyr::mutate(
      road_density_km_per_km2 = (road_length_m   / 1000) / area_km2,
      a_road_density_km_per_km2 = (a_road_length_m / 1000) / area_km2,
      junction_density_per_km2= junction_count / area_km2
    )
}

# **** Speed environment (OS NGD) ****
# OS NGD speed field names:
#   indicativespeedlimit_mph - posted speed limit in mph
#   averagespeed_mf7to9indirection_kph - Mon-Fri AM peak speed (in-direction)
#   averagespeed_mf7to9againstdirection_kph - Mon-Fri AM peak (against-direction)
#
# The speed layer carries its own road link geometry (47,363 features, same as
# roadlink) — no join to sf_ngd_roadlink is needed. Spatial join to LSOAs only.

process_lsoa_speed <- function(sf_ngd_speed, sf_lsoa) {
  lsoa_bng  <- to_bng(sf_lsoa)
  speed_bng <- to_bng(sf_ngd_speed)

  # AM peak average speed: mean of in and against direction, converted to mph
  speed_bng <- speed_bng |>
    dplyr::mutate(
      avg_speed_am_mph = (
        averagespeed_mf7to9indirection_kph +
          averagespeed_mf7to9againstdirection_kph
      ) / 2 * 0.621371
    )

  sf::st_join(
    dplyr::select(speed_bng, indicativespeedlimit_mph, avg_speed_am_mph),
    dplyr::select(lsoa_bng, LSOA11CD),
    join = sf::st_within
  ) |>
    sf::st_drop_geometry() |>
    dplyr::filter(!is.na(LSOA11CD)) |>
    dplyr::group_by(LSOA11CD) |>
    dplyr::summarise(
      mean_speed_limit_mph = mean(indicativespeedlimit_mph, na.rm = TRUE),
      median_speed_limit_mph = median(indicativespeedlimit_mph, na.rm = TRUE),
      mean_avg_speed_am_mph = mean(avg_speed_am_mph, na.rm = TRUE),
      pct_20mph_or_less = mean(indicativespeedlimit_mph <= 20, na.rm = TRUE),
      pct_30mph_or_less  = mean(indicativespeedlimit_mph <= 30, na.rm = TRUE),
      .groups = "drop"
    )
}

# **** Active travel / cycling infrastructure (OS NGD) ****
# OS NGD HighwayDedication uses a `description` field with values including:
#   "Cycle Track Or Cycle Way", "Bridleway", "Pedestrian Way Or Footpath", etc.
# Cycling infrastructure = "Cycle Track Or Cycle Way" (dedicated).
# Bridleways are included as they are legal for cycling under the Highway Act.

process_lsoa_cycling <- function(sf_ngd_highway, sf_lsoa) {
  lsoa_bng    <- to_bng(sf_lsoa)
  highway_bng <- to_bng(sf_ngd_highway)
  areas       <- lsoa_area_km2(sf_lsoa)

  cycle_infra <- highway_bng |>
    dplyr::filter(description %in% c("Cycle Track Or Cycle Way", "Bridleway"))

  if (nrow(cycle_infra) == 0) {
    warning(
      "No cycle infrastructure found — check the description field values."
    )
    return(
      dplyr::left_join(
        areas, 
        dplyr::tibble(LSOA11CD = character()), by = "LSOA11CD"
      ) |>
      dplyr::mutate(cycle_infra_length_m = 0, cycle_infra_density_m_per_km2 = 0)
    )
  }

  cycle_lsoa <- sf::st_intersection(
    dplyr::select(cycle_infra, description),
    dplyr::select(lsoa_bng, LSOA11CD)
  ) |>
    dplyr::mutate(length_m = as.numeric(sf::st_length(geometry))) |>
    sf::st_drop_geometry() |>
    dplyr::group_by(LSOA11CD) |>
    dplyr::summarise(
      cycle_infra_length_m = sum(length_m, na.rm = TRUE), .groups = "drop"
    )

  areas |>
    dplyr::left_join(cycle_lsoa, by = "LSOA11CD") |>
    tidyr::replace_na(list(cycle_infra_length_m = 0)) |>
    dplyr::mutate(
      cycle_infra_density_m_per_km2 = cycle_infra_length_m / area_km2
    ) |>
    dplyr::select(-area_km2)
}

# **** Traffic flow (DfT API) ****

process_lsoa_traffic <- function(df_flow, sf_lsoa) {
  lsoa_bng <- to_bng(sf_lsoa)

  sf_flow_bng <- df_flow |>
    dplyr::filter(!is.na(latitude), !is.na(longitude)) |>
    sf::st_as_sf(coords = c("longitude", "latitude"), crs = 4326) |>
    to_bng()

  sf::st_join(
    dplyr::select(
      sf_flow_bng, road_category, all_motor_vehicles,
      pedal_cycles, cars_and_taxis, buses_and_coaches
    ),
    dplyr::select(lsoa_bng, LSOA11CD),
    join = sf::st_within
  ) |>
    sf::st_drop_geometry() |>
    dplyr::filter(!is.na(LSOA11CD)) |>
    dplyr::group_by(LSOA11CD) |>
    dplyr::summarise(
      count_point_n = dplyr::n(),
      mean_aadf_all = mean(all_motor_vehicles, na.rm = TRUE),
      mean_aadf_cars = mean(cars_and_taxis, na.rm = TRUE),
      mean_aadf_buses = mean(buses_and_coaches, na.rm = TRUE),
      mean_aadf_cycles = mean(pedal_cycles, na.rm = TRUE),
      .groups = "drop"
    )
}

# *** Accessibility: distance to city centre ****

process_lsoa_city_centre_dist <- function(sf_lsoa) {
  # Sheffield city centre (approximate centroid of the retail/civic core)
  city_centre_bng <- sf::st_sfc(
    sf::st_point(c(-1.4701, 53.3811)),
    crs = 4326
  ) |>
    sf::st_transform(27700)

  sf_lsoa |>
    to_bng() |>
    sf::st_centroid() |>
    dplyr::mutate(
      dist_city_centre_km = as.numeric(
        sf::st_distance(geom, city_centre_bng)
      ) / 1000
    ) |>
    sf::st_drop_geometry() |>
    dplyr::select(LSOA11CD, dist_city_centre_km)
}

# **** Bus stops (NaPTAN) ****

process_lsoa_bus_stops <- function(df_naptan, sf_lsoa) {
  lsoa_bng <- to_bng(sf_lsoa)
  areas    <- lsoa_area_km2(sf_lsoa)

  sf_stops_bng <- df_naptan |>
    dplyr::filter(!is.na(Longitude), !is.na(Latitude)) |>
    sf::st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326) |>
    to_bng()

  stops_per_lsoa <- sf::st_join(
    sf_stops_bng,
    dplyr::select(lsoa_bng, LSOA11CD),
    join = sf::st_within
  ) |>
    sf::st_drop_geometry() |>
    dplyr::filter(!is.na(LSOA11CD)) |>
    dplyr::count(LSOA11CD, name = "bus_stop_count")

  areas |>
    dplyr::left_join(stops_per_lsoa, by = "LSOA11CD") |>
    tidyr::replace_na(list(bus_stop_count = 0)) |>
    dplyr::mutate(bus_stop_density_per_km2 = bus_stop_count / area_km2) |>
    dplyr::select(-area_km2)
}

# **** IMD 2019 ****

process_lsoa_imd <- function(df_imd, sf_lsoa) {
  df_imd |>
    dplyr::filter(`LSOA code (2011)` %in% sf_lsoa$LSOA11CD) |>
    dplyr::select(
      LSOA11CD = `LSOA code (2011)`,
      imd_score = `Index of Multiple Deprivation (IMD) Score`,
      imd_rank = `Index of Multiple Deprivation (IMD) Rank (where 1 is most deprived)`,
      imd_decile = `Index of Multiple Deprivation (IMD) Decile (where 1 is most deprived 10% of LSOAs)`,
      income_score = `Income Score (rate)`,
      employment_score = `Employment Score (rate)`,
      health_score = `Health Deprivation and Disability Score`,
      living_env_score = `Living Environment Score`
    )
}

# **** Census 2021 ****
# Census 2021 uses 2021 LSOA codes (LSOA21CD). Our boundaries use 2011 codes
# (LSOA11CD). For most Sheffield LSOAs the code is unchanged, but a small
# number were split or merged in the 2021 redesign. The final analytical
# dataset join will need the ONS LSOA 2011 to 2021 lookup to handle mismatches.
# Each function adds a LSOA21CD column as the key for that join.

process_lsoa_census_population <- function(df_census_population) {
  df_census_population |>
    filter_sheffield_census() |>
    dplyr::select(
      LSOA21CD = `geography code`,
      pop_density_per_km2 = `Population Density: Persons per square kilometre; measures: Value`
    )
}

process_lsoa_census_cars <- function(df_census_cars) {
  df_census_cars |>
    filter_sheffield_census() |>
    dplyr::transmute(
      LSOA21CD = `geography code`,
      hh_total = `Number of cars or vans: Total: All households`,
      hh_no_car = `Number of cars or vans: No cars or vans in household`,
      pct_no_car = hh_no_car / hh_total
    ) |>
    dplyr::select(LSOA21CD, pct_no_car, hh_no_car, hh_total)
}

process_lsoa_economic_activity <- function(df_census_economic_activity) {
  unemployed_col <- "Economic activity status: Economically active (excluding full-time students): Unemployed"
  total_col <- "Economic activity status: Total: All usual residents aged 16 years and over"

  df_census_economic_activity |>
    filter_sheffield_census() |>
    dplyr::transmute(
      LSOA21CD          = `geography code`,
      pop_16_plus       = .data[[total_col]],
      unemployed_count  = .data[[unemployed_col]],
      unemployment_rate = unemployed_count / pop_16_plus
    )
}
