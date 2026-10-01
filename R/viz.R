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
  gt::gt(df) |>
    gt::fmt(
      columns = where(is.numeric),
      fns = function(x) {
        ifelse(
          abs(x) < 10,
          format(round(x, 3), nsmall = 3, big.mark = ","),
          format(round(x, 0), nsmall = 0, big.mark = ",")
        )
      }
    ) |>
    gtExtras::gt_theme_pff()
}
