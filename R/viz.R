# Reusable visualisation helpers

# Build a Leaflet map with an OS raster basemap centred on Sheffield.
# os_layer: OS Maps API raster layer name (see OS documentation).
# Returns a leaflet map object with tiles and view set.
make_basemap <- function(
  os_layer = "Outdoor_3857",
  lng = -1.4701,
  lat =  53.3811,
  zoom = 10
) {
  os_url <- paste0(
    "https://api.os.uk/maps/raster/v1/zxy/",
    os_layer,
    "/{z}/{x}/{y}.png?key=",
    osdatahub::get_os_key()
  )
  os_copyright <- paste0(
    "\u00a9 Crown copyright and database rights ",
    format(Sys.Date(), "%Y"),
    " OS licence number AC0000805013"
  )
  leaflet::leaflet() |>
    leaflet::addTiles(urlTemplate = os_url, attribution = os_copyright) |>
    leaflet::setView(lng = lng, lat = lat, zoom = zoom)
}


# gt (table) theme & format
my_gt <- function(df) {

  fmt_num <- function(x) {
    
    dplyr::if_else(
      is.na(x),
      NA_character_,
      dplyr::case_when(
        abs(x) >= 100  ~ format(round(x, 0), scientific = FALSE, trim = TRUE),
        abs(x) >= 10   ~ format(round(x, 1), scientific = FALSE, trim = TRUE),
        abs(x) >= 1    ~ format(round(x, 2), scientific = FALSE, trim = TRUE),
        abs(x) >= 0.01 ~ format(round(x, 3), scientific = FALSE, trim = TRUE),
        TRUE           ~ format(signif(x, 3), scientific = FALSE, trim = TRUE)
      )
    )
  }
  
  gt::gt(df) |>
    gt::fmt(
      columns = where(is.numeric),
      fns = fmt_num
    ) |>
    gtExtras::gt_theme_guardian() |>
    gt::tab_options(
      table.font.size = px(12),
      data_row.padding = px(2),
      heading.padding = px(4)
    )
}


