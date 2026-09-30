# Neighbourhood Transport Environment Typology

An unsupervised machine learning project that classifies Sheffield's 345 Lower Super Output Areas (LSOAs) into transport environment types using publicly available data.

The resulting typology — the **Neighbourhood Transport Environment Typology (NTET)** — provides a common evidence base for transport planning, regeneration, climate policy, and public health interventions across the city.

## Methodology

The project follows four stages:

1. **Data preparation** — assemble, clean and standardise a neighbourhood-level analytical dataset
2. **Exploratory analysis** — examine correlations and apply PCA to understand principal dimensions of variation (e.g. urban intensity, car dependency, accessibility)
3. **Clustering** — compare K-Means, Hierarchical Clustering and Gaussian Mixture Models
4. **Evaluation** — assess cluster robustness via silhouette score, stability, statistical separation and policy interpretability

## Data Sources

| Source | Description | Access |
|--------|-------------|--------|
| [OS NGD](https://www.ordnancesurvey.co.uk/products/os-ngd-api-features) | Road network (links, nodes), speed limits, average speeds, cycle/highway dedication | Manual download to `data/download/` |
| [DfT Road Traffic Statistics API](https://roadtraffic.dft.gov.uk/api) | Average Annual Daily Flow (AADF) per count point | API (Sheffield LA ID: 159) |
| [NaPTAN](https://www.data.gov.uk/dataset/naptan) | Bus stop locations (ATCO area 370 — South Yorkshire) | API |
| [IMD 2019](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2019) | Index of Multiple Deprivation scores, ranks and deciles | Download |
| [Census 2021 (NOMIS)](https://www.nomisweb.co.uk/sources/census_2021_bulk) | Population density (TS006), car availability (TS045), economic activity (TS066), industry (TS060) | API |
| [ONS Open Geography Portal](https://geoportal.statistics.gov.uk/) | 2011 LSOA boundaries for Sheffield | API |

> **Note on LSOA codes**: LSOA boundaries use 2011 codes (LSOA11CD), which align with IMD 2019. Census 2021 data uses 2021 codes (LSOA21CD). An ONS lookup is required to reconcile a small number of split/merged LSOAs.

## Project Structure

```
.
├── R/
│   ├── ingest.R       # Functions to acquire raw data (API calls and file paths)
│   └── process.R      # Functions to aggregate each source to LSOA level
├── _targets.R         # Targets pipeline definition
├── data.qmd           # Data preparation report (Quarto)
├── proposal.qmd       # Project proposal (Quarto)
└── data/
    ├── download/      # Manually downloaded files (OS NGD, city boundary)
    ├── boundaries/    # Derived boundary files
    └── raw/           # API-sourced raw data files
```

The `data/` and `_targets/` directories are excluded from version control.

## Running the Pipeline

The pipeline is managed with [`{targets}`](https://books.ropensci.org/targets/). Before running, ensure OS NGD GeoPackage files have been downloaded to `data/download/NGD Traffic Speed Sheffield/`.

```r
library(targets)
tar_make()         # Run the full pipeline
tar_visnetwork()   # Visualise the dependency graph
tar_read(df_lsoa_road_network)  # Inspect a specific target
```

Key pipeline targets include:

| Target | Description |
|--------|-------------|
| `sf_lsoa` | Sheffield LSOA boundaries (sf object) |
| `df_lsoa_road_network` | Road density, A-road share and junction density per LSOA |
| `df_lsoa_speed` | Speed limit profile and AM-peak average speed per LSOA |
| `df_lsoa_cycling` | Cycle infrastructure length and density per LSOA |
| `df_lsoa_traffic` | Mean AADF (all vehicles, cars, buses, cycles) per LSOA |
| `df_lsoa_bus_stops` | Bus stop count and density per LSOA |
| `df_lsoa_city_centre_dist` | Straight-line distance to Sheffield city centre per LSOA |
| `df_lsoa_imd` | IMD 2019 score, rank, decile and sub-domain scores per LSOA |
| `df_lsoa_population` | Population density per LSOA (Census 2021) |
| `df_lsoa_cars` | Car/van availability per LSOA (Census 2021) |
| `df_lsoa_economic_activity` | Unemployment rate per LSOA (Census 2021) |

## Licence & Data Attribution

### Code

The code in this repository is licensed under the [GNU General Public License v3.0](LICENSE).

### Data

The raw data files are excluded from this repository. Sources and their terms are listed below.

| Source | Licence / Terms |
|--------|----------------|
| OS NGD (road network, speed, cycling infrastructure) | Contains OS data © Crown copyright and database right 2024. Available to public sector organisations via the [Public Sector Geospatial Agreement (PSGA)](https://www.ordnancesurvey.co.uk/customers/public-sector/public-sector-geospatial-agreement). Not redistributable. |
| DfT Road Traffic Statistics | [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) |
| NaPTAN (bus stops) | [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) |
| IMD 2019 | [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) |
| Census 2021 (NOMIS) | [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) — Contains National Statistics data © Crown copyright and database right 2026 |
| ONS Open Geography Portal (LSOA boundaries) | [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) — Contains OS data © Crown copyright and database right 2026 |

> OS NGD data is accessed under Sheffield City Council's PSGA membership. It may not be shared or redistributed outside of PSGA-permitted use. If you are reproducing or adapting this project, you will need your own PSGA membership or OS licence to access the NGD source files.

## Requirements

```r
install.packages(c(
  "targets", "tarchetypes",
  "tidyverse", "sf", "here",
  "httr", "jsonlite",
  "gt", "gtExtras", "readxl"
))
```
