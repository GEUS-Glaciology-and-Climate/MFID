README for "Greenland Ice Sheet solid ice discharge from 1986 through 2018"

Paper Citation: TODO

Original Paper: doi:10.5194/essd-11-769-2019

Data Citation: TODO

Original Data Citations: doi:10.22008/promice/data/ice_discharge

Source: https://github.com/mankoff/ice_discharge

* Usage instructions:

When using any of the following data, you are required to cite the paper and the data set.

* Data Descriptions

Data sets released as part of this work include:
+ Discharge data
+ Gates
+ Surface Elevation Change
+ Code

Each are described briefly below.

** Discharge Data

This data set is made up of the following files

| Filename            | Description                                           |
|---------------------+-------------------------------------------------------|
| GIS_D.csv           | Greenland Ice Sheet cumulative discharge by timestamp |
| GIS_err.csv         | Errors for GIS_D.csv                                  |
| GIS_coverage.csv    | Coverage for GIS_D.csv                                |
| region_D.csv        | Regional discharge                                    |
| region_err.csv      | Errors for region_D.csv                               |
| region_coverage.csv | Coverage for region_D.csv                             |
| sector_D.csv        | Sector discharge                                      |
| sector_err.csv      | Errors for sector_D.csv                               |
| sector_coverage.csv | Coverage for sector_D.csv                             |
| gate_D.csv          | Gate discharge                                        |
| gate_err.csv        | Errors for gate_D.csv                                 |
| gate_coverage.csv   | Coverage for gate_D.csv                               |
|---------------------+-------------------------------------------------------|
| gate_meta.csv       | Metadata for each gate                                |


D and err data have units [Gt yr-1].
Coverage is in range [0, 1]

** Gates

| Filename   | Description                                   |
|------------+-----------------------------------------------|
| gates.kml  | KML file of gate location and metadata        |
| gates.gpkg | GeoPackage file of gate location and metadata |

** Surface Elevation Change

The "surface_elevation_change" file set contains the surface elevation change data used in this work (DOI 10.22008/promice/data/DTU/surface_elevation_change/v1.0.0)

** Code

The "code" file set (DOI 10.22008/promice/data/ice_discharge/code/v0.0.1) contains the digital workbook that produced the data, the ESSD document text and figures, this README, and everything else associated with this work.
