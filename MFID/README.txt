Mass flow rate ice discharge (MFID) for Greenland ice sheet sectors.

This data set is part of the ESA Greenland Ice Sheet CCI project, phase 3.
It covers October 2014 to December 2025 at monthly resolution.

It provides the following files.
1. Mass flow rate ice discharge (*_D.csv) for the whole ice sheet (GIS),
   regions (Mouginot et al., 2019), Zwally et al. (2012) sectors, and
   individual gates. Units are Gt yr^{-1}.
2. Mass flow rate ice discharge uncertainty (*_err.csv). Units are Gt yr^{-1}.
3. Coverage for each region, sector and gate at each timestamp
   (*_coverage.csv). Unitless [0 to 1].
4. Ice-sheet discharge with time-invariant thickness
   (constant_thickness_GIS_D.csv). Units are Gt yr^{-1}.
5. Gate metadata (gate_meta.csv) and gate locations (gates.gpkg, gates.kml).
6. A quicklook of the ice-sheet discharge time series (quicklook.png).

Ice discharge is calculated from the CCI Ice Velocity (IV) product (through December 2025) and ice thickness from BedMachine v5. Ice thickness varies over time using a monthly DEM time series derived from the CCI differential Surface Elevation Change (dSEC) product (units: m/month), integrated forward and backward from a PRODEM July 2020 anchor. Ice discharge gates are placed 10 km upstream from all marine terminating glacier termini that have baseline velocities of more than 150 m/yr. Results are summed by Zwally et al. (2012) sectors.

The methods, including description of "coverage", are described in Mankoff et al. (2020; DOI: 10.5194/essd-12-1367-2020).

References:
Mankoff, K. D., Solgaard, A., Colgan, W., Ahlstrøm, A. P., Khan, S. A., and Fausto, R. S.: Greenland Ice Sheet solid ice discharge from 1986 through March 2020, Earth Syst. Sci. Data, 12, 1367-1383, https://doi.org/10.5194/essd-12-1367-2020, 2020.
Morlighem, M., et al.: IceBridge BedMachine Greenland, Version 5. [TODO: full citation and DOI]
Zwally, H. J., Giovinetto, M. B., Beckley, M. A., and Saba, J. L.: Antarctic and Greenland Drainage Systems, GSFC Cryospheric Sciences Laboratory, 2012.
