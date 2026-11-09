# Functions to aggregate raw datasets to Sheffield LSOA level, producing one
# data frame per source ready to join into the analytical dataset.


# Returns a data frame (one row per LSOA) with all indicators 
# assembled LSOA21CD as key. One row per LSOA and one column per indicator. 
assemble_lsoa <- function(
    sf_lsoa,
    df_lsoa_road_network, 
    df_lsoa_speed, 
    df_lsoa_cycling,
    df_lsoa_traffic, 
    df_lsoa_city_centre_dist, 
    df_lsoa_imd,
    df_lsoa_bus_stops,
    df_lsoa_population, 
    df_lsoa_cars, 
    df_lsoa_economic_activity
  ) {
  # Left-join all LSOA-level indicators to the full LSOA list
  sf_lsoa |>
    st_drop_geometry() |>
    dplyr::select(LSOA21CD) |>
    dplyr::left_join(df_lsoa_road_network, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_speed, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_cycling, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_traffic, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_city_centre_dist, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_imd, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_bus_stops, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_population, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_cars, by = "LSOA21CD") |>
    dplyr::left_join(df_lsoa_economic_activity, by = "LSOA21CD")
}