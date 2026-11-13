# Neighbourhood Transport Environment Typology

**Repo owner:** Laurie Platt  
**Status:** Initial development  

An unsupervised machine learning clustering project that groups Sheffield's 343 Lower Super Output Areas (LSOAs) into transport environment types using publicly available data.

The resulting typology, the **Neighbourhood Transport Environment Typology (NTET)**, provides a common evidence base for transport planning, regeneration, climate policy, and public health interventions across the city.

## Methodology

The project follows five stages:

1. **Data preparation** - extract, process, and assemble a neighbourhood-level analytical dataset.  
2. **Exploratory analysis** - feature scaling, correlation analysis, and understanding principal dimensions of variation (e.g. urban intensity, car dependency, accessibility).  
3. **Clustering** - compare K-Means, Hierarchical Clustering, and Gaussian Mixture Models.  
4. **Evaluation** - assess cluster robustness via silhouette score, stability, statistical separation, and policy interpretability.  
5. **Communicate** - the results.  

## Running the Pipeline

The pipeline has two main steps:

1. ETL  
2. EDA & Clustering

### 1. ETL

The ETL part of the pipeline is managed with [`{targets}`](https://books.ropensci.org/targets/).  

```r
# Run the full pipeline (from the R console)
targets::tar_make() 
```

The ETL pipeline includes OS data that requires an API key. This is acquired via an [OS Data Hub API project](https://docs.os.uk/os-apis/core-concepts/getting-started-with-an-api-project). The pipeline assumes a variable called `OS_API_KEY` has been set in the `.Renviron` file.    

```r
# To set the OS API key (from the R console)
# replace 2nd argument with actual API key
usethis::use_env_var("OS_API_KEY", "123456789ABCDEFGHIJ") 
```

Key ETL pipeline targets include:

| Target | Description |
|--------|-------------|
| `sf_lsoa` | Sheffield LSOA boundaries (sf object) |
| `df_lsoa_road_network` | Road density, A-road share and junction density per LSOA |
| `df_lsoa_speed` | Speed limit profile and AM-peak average speed per LSOA |
| `df_lsoa_cycling` | Cycle infrastructure length and density per LSOA |
| `df_lsoa_traffic` | Mean AADF (all vehicles, cars, buses, cycles) per LSOA |
| `df_lsoa_bus_stops` | Bus stop count and density per LSOA |
| `df_lsoa_city_centre_dist` | Straight-line distance to Sheffield city centre per LSOA |
| `sf_lsoa_imd` | IMD 2025 rank and decile per LSOA |
| `df_lsoa_population` | Population density per LSOA (Census 2021) |
| `df_lsoa_cars` | Car/van availability per LSOA (Census 2021) |
| `df_lsoa_economic_activity` | Unemployment rate per LSOA (Census 2021) |
| `df_lsoa` | Assembled data frame of all candidate variables |

### 2. EDA & Clustering  

For the EDA & Clustering part of the pipeline we've adopted a Literate Programming approach using [Quarto](https://quarto.org/), rather than the Functional Programming approach of `{targets}`. The two don't have to be mutually exclusive, but we've kept them separate whilst the project is in development and at the proof-of-concept stage. The transparency, narrative, and exploratory characteristics of Literate Programming best suits our current EDA and clustering efforts.  

The rendering of Quarto documents is undertaken locally rather than via [GitHub Actions](https://docs.github.com/en/actions). 

```r
# Render all Quarto documents (from the terminal)
quarto render
```

[GitHub Pages](https://docs.github.com/en/pages) publish the rendered HTML files from the `docs/` repo directory on the `main` branch.  

## Project Structure

```
.
├── R/
│   └── ingest.R       # Functions to acquire raw data (API calls and file paths)
│   └── process.R      # Functions to aggregate each source to LSOA level
│   └── assemble.R     # Functions to assemble indicators to a single data frame
│   └── viz.R          # Functions to help with visualisations
├── _targets.R         # Targets pipeline definition
├── one-page.qmd       # Summary of what & why? (Quarto to HTML & .docx)
├── proposal.qmd       # Project proposal, includes how? (Quarto to HTML)
├── oac.qmd            # Exploration of Output Area Classifications (Quarto to HTML)
├── data.qmd           # Data preparation report (Quarto to HTML)
├── features.qmd       # Feature engineering report (Quarto to HTML)
├── data/
    ├── raw/           # API-sourced raw data files
├── _freeze/           # Enables Quarto website local execution with CI rendering  
├── docs/              # Output from `quarto render` e.g. proposal.html   
├── _quarto.yml        # Defines project level `quarto render` options e.g. `freeze: auto`
├── resources/         # Files used by the Quarto documents e.g. style.css
├── output/            # File output shared by the Quarto documents e.g. ons_oas_sheffield.xlsx 
```

The `data/` and `_targets/` directories are excluded from version control.

## Data

| Source (& license) | Description | Access |
|--------|-------------|--------|
| [OS NGD](https://www.ordnancesurvey.co.uk/products/os-ngd-api-features) <br/><span style="font-size: 80%">Contains OS data © Crown copyright and database right 2026. Available to public sector organisations via the [Public Sector Geospatial Agreement (PSGA)](https://www.ordnancesurvey.co.uk/customers/public-sector/public-sector-geospatial-agreement). Not redistributable.</span>| Road network (links, nodes), speed limits, average speeds, cycle/highway dedication | API (Data Package ID: 22969) |
| [DfT Road Traffic Statistics API](https://roadtraffic.dft.gov.uk/api) <br/><span style="font-size: 80%">[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)</span>| Average Annual Daily Flow (AADF) per count point | API (Sheffield LA ID: 159) |
| [NaPTAN](https://www.data.gov.uk/dataset/naptan)  <br/><span style="font-size: 80%">[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)</span>| Bus stop locations (ATCO area 370 — South Yorkshire) | API |
| [IMD 2025](https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025)  <br/><span style="font-size: 80%">[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)</span>| Index of Multiple Deprivation scores, ranks and deciles | API |
| [Census 2021 (NOMIS)](https://www.nomisweb.co.uk/sources/census_2021_bulk)  <br/><span style="font-size: 80%">[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) — Contains National Statistics data © Crown copyright and database right 2026</span>| Population density (TS006), car availability (TS045), economic activity (TS066), industry (TS060) | API |
| [ONS Open Geography Portal](https://geoportal.statistics.gov.uk) <br/><span style="font-size: 80%">[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/) — Contains National Statistics data © Crown copyright and database right 2026</span>| 2021 LSOA boundaries for Sheffield | API |
| [GeoDS OAC 2021/2](https://data.geods.ac.uk/dataset/lsoac) <br/><span style="font-size: 80%">[Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)</span>| 2021/22 LSOA classifications | API |
| [SCC AGOL](https://sheffieldcc.maps.arcgis.com) | Sheffield City boundary | API |

Raw data files are excluded from this repository.

> OS NGD data is accessed under Sheffield City Council's PSGA membership. It may not be shared or redistributed outside of PSGA-permitted use. If you are reproducing or adapting this project, you will need your own PSGA membership or OS licence to access the NGD source files.

## Requirements

**R packages:**

```r
install.packages(c(
  "targets", "tarchetypes",
  "tidyverse", "sf", "here",
  "httr", "jsonlite",
  "gt", "gtExtras", "readxl",
  "leaflet", "osdatahub", "tidymodels",
  "tidyclust", "skimr", "usethis",
  "ggcorrplot", "factoextra",
  "writexl", "usethis"
))
```

**Session Info:**  

```
─ Session info ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 setting  value
 version  R version 4.3.3 (2024-02-29 ucrt)
 os       Windows Server 2022 x64 (build 26200)
 system   x86_64, mingw32
 ui       RStudio
 language (EN)
 collate  English_United Kingdom.utf8
 ctype    English_United Kingdom.utf8
 tz       Europe/London
 date     2026-11-12
 rstudio  2026.05.0+218 Golden Wattle (desktop)
 pandoc   NA
 quarto   1.9.38 @ C:\\PROGRA~1\\Quarto\\bin\\quarto.exe

─ Packages ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 package      * version    date (UTC) lib source
 class          7.3-22     2023-05-03 [2] CRAN (R 4.3.3)
 cli            3.6.4      2025-02-13 [1] CRAN (R 4.3.3)
 codetools      0.2-19     2023-02-01 [2] CRAN (R 4.3.3)
 data.table     1.17.0     2025-02-22 [1] CRAN (R 4.3.3)
 dials          1.4.4      2026-06-22 [1] CRAN (R 4.3.3)
 DiceDesign     1.10       2023-12-07 [1] CRAN (R 4.3.3)
 digest         0.6.37     2024-08-19 [1] CRAN (R 4.3.3)
 dplyr          1.1.4      2023-11-17 [1] CRAN (R 4.3.3)
 evaluate       1.0.5      2025-08-27 [1] CRAN (R 4.3.3)
 farver         2.1.2      2024-05-13 [1] CRAN (R 4.3.3)
 foreach        1.5.2      2022-02-02 [1] CRAN (R 4.3.3)
 furrr          0.3.1      2022-08-15 [1] CRAN (R 4.3.3)
 future         1.34.0     2024-07-29 [1] CRAN (R 4.3.3)
 future.apply   1.11.3     2024-10-27 [1] CRAN (R 4.3.3)
 generics       0.1.4      2025-05-09 [1] CRAN (R 4.3.3)
 ggplot2        4.0.3      2026-04-22 [1] CRAN (R 4.3.3)
 globals        0.19.1     2026-03-13 [1] CRAN (R 4.3.3)
 glue           1.8.0      2024-09-30 [1] CRAN (R 4.3.3)
 gower          1.0.2      2024-12-17 [1] CRAN (R 4.3.3)
 GPfit          1.0-8      2019-02-08 [1] CRAN (R 4.3.3)
 gtable         0.3.6      2024-10-25 [1] CRAN (R 4.3.3)
 hardhat        1.4.3      2026-04-04 [1] CRAN (R 4.3.3)
 ipred          0.9-15     2024-07-18 [1] CRAN (R 4.3.3)
 iterators      1.0.14     2022-02-05 [1] CRAN (R 4.3.3)
 knitr          1.50       2025-03-16 [1] CRAN (R 4.3.3)
 lattice        0.22-5     2023-10-24 [2] CRAN (R 4.3.3)
 lava           1.8.0      2024-03-05 [1] RSPM
 lhs            1.2.0      2024-06-30 [1] CRAN (R 4.3.3)
 lifecycle      1.0.5      2026-01-08 [1] CRAN (R 4.3.3)
 listenv        1.0.0      2026-06-22 [1] CRAN (R 4.3.3)
 lubridate      1.9.4      2024-12-08 [1] CRAN (R 4.3.3)
 magrittr       2.0.3      2022-03-30 [1] CRAN (R 4.3.3)
 MASS           7.3-60.0.1 2024-01-13 [2] CRAN (R 4.3.3)
 Matrix         1.6-5      2024-01-11 [2] CRAN (R 4.3.3)
 modelenv       0.2.0      2024-10-14 [1] CRAN (R 4.3.3)
 nnet           7.3-19     2023-05-03 [2] CRAN (R 4.3.3)
 parallelly     1.43.0     2025-03-24 [1] CRAN (R 4.3.3)
 parsnip        1.6.1      2026-09-27 [1] CRAN (R 4.3.3)
 pillar         1.11.1     2025-09-17 [1] CRAN (R 4.3.3)
 pkgconfig      2.0.3      2019-09-22 [1] CRAN (R 4.3.3)
 prodlim        2024.06.25 2024-06-24 [1] CRAN (R 4.3.3)
 purrr          1.0.4      2025-02-05 [1] CRAN (R 4.3.3)
 R6             2.6.1      2025-02-15 [1] CRAN (R 4.3.3)
 RColorBrewer   1.1-3      2022-04-03 [1] CRAN (R 4.3.1)
 Rcpp           1.0.14     2025-01-12 [1] CRAN (R 4.3.3)
 recipes        1.4.0      2026-08-24 [1] CRAN (R 4.3.3)
 rlang          1.1.5      2025-01-17 [1] CRAN (R 4.3.3)
 rpart          4.1.23     2023-12-05 [2] CRAN (R 4.3.3)
 rsample        1.3.2      2026-01-30 [1] CRAN (R 4.3.3)
 rstudioapi     0.19.0     2026-06-11 [1] CRAN (R 4.3.3)
 S7             0.2.0      2024-11-07 [1] CRAN (R 4.3.3)
 scales         1.4.0      2025-04-24 [1] CRAN (R 4.3.3)
 sessioninfo    1.2.4      2026-06-04 [1] CRAN (R 4.3.3)
 survival       3.5-8      2024-02-14 [2] CRAN (R 4.3.3)
 tibble         3.2.1      2023-03-20 [1] CRAN (R 4.3.3)
 tidyclust      0.2.4      2025-01-27 [1] CRAN (R 4.3.3)
 tidyr          1.3.1      2024-01-24 [1] CRAN (R 4.3.3)
 tidyselect     1.2.1      2024-03-11 [1] CRAN (R 4.3.3)
 timechange     0.3.0      2024-01-18 [1] CRAN (R 4.3.3)
 timeDate       4052.112   2026-01-28 [1] CRAN (R 4.3.3)
 tune           1.3.0      2025-02-21 [1] CRAN (R 4.3.3)
 vctrs          0.6.5      2023-12-01 [1] CRAN (R 4.3.3)
 withr          3.0.2      2024-10-28 [1] CRAN (R 4.3.3)
 workflows      1.3.0      2025-08-27 [1] CRAN (R 4.3.3)
 xfun           0.52       2025-04-02 [1] CRAN (R 4.3.3)
 yardstick      1.3.2      2025-01-22 [1] CRAN (R 4.3.3)

 [1] C:/Users/lp41455/AppData/Local/R/win-library/4.3
 [2] C:/Program Files/R/R-4.3.3/library
```

