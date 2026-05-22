# MFID — Mass Flux Ice Discharge for ESA CCI+ Greenland, Phase 3

Calculates the mass flux ice discharge (MFID) for the Greenland Ice Sheet as part of the ESA CCI+ Greenland project. Ice discharge is calculated from the CCI Ice Velocity (IV) product, ice thickness from BedMachine, and a monthly DEM time series derived from the CCI differential Surface Elevation Change (dSEC) product. Ice discharge gates are placed 10 km upstream from all marine-terminating glacier termini with baseline velocities above 150 m/yr. Results are summed by Zwally et al. (2012) sectors.

Based on the workflow by Ken Mankoff for the PROMICE Solid Ice Discharge product:
> Mankoff, Ken; Solgaard, Anne; Larsen, Signe, 2020, "Greenland Ice Sheet solid ice discharge from 1986 through last month: Discharge", https://doi.org/10.22008/promice/data/ice_discharge/d/v02, GEUS Dataverse, V101

Methods are described in Mankoff et al. (2020; DOI: 10.5194/essd-12-1367-2020).

## Output

- `out/` — CSV files with mass flow rate ice discharge (Gt yr⁻¹), discharge uncertainty (Gt yr⁻¹), and gate coverage [0–1], at gate, sector, region, and GIS scale.

## Dependencies

- [Docker](https://docs.docker.com/get-docker/) — most steps run inside Docker images
  - `hillerup/ice_discharge:grass` — GRASS GIS environment
  - `hillerup/ice_discharge:conda` — Python/conda environment
- `make`

## Setup

1. Install Docker and ensure you are logged in.
2. Download the required input datasets and place them under a common data directory.
3. Set the `DATADIR` environment variable to point to that directory:
   ```bash
   export DATADIR=/path/to/data
   ```
4. Run:
   ```bash
   make
   ```

## Workflow

The `Makefile` runs the full pipeline. Each step is a separate script; Make tracks which outputs are up to date and skips steps that do not need re-running.

### Import

| Script | Description |
|--------|-------------|
| `import_bedmachine.sh` | Import BedMachine v5 surface, thickness, bed, and mask |
| `import_sectors.sh` | Import Mouginot 2019 and Zwally 2012 sector masks |
| `import_area_error.sh` | Compute 2D projection area error for EPSG:3413 |
| `import_velocity.sh` | Import ENVEO monthly ice velocity; compute baseline and fill holes |
| `import_names.sh` | Import Bjørk 2015 glacier names and Mouginot 2019 outlet names |
| `import_elevation.sh` | Import PRODEM; build monthly DEM time series from dSEC (see below) |
| `import_dsec.sh` | Import CCI dSEC monthly surface elevation change product |

### DEM time series

Monthly DEMs are built by integrating the CCI dSEC product (units: m/month) forward and backward from a single anchor: the PRODEM July 2020 DEM. This gives a continuous monthly surface elevation time series from January 2011 to March 2025, which is used to compute time-varying ice thickness at each gate.

### Gates

| Script | Description |
|--------|-------------|
| `find_gates.sh` | Identify ice discharge gates from velocity and BedMachine mask |
| `gate_metadata.sh` | Add coordinates, sector, region, and glacier name to each gate; export `out/gate_meta.csv` |
| `compute_vel_eff.sh` | Compute effective velocity at each gate pixel for each ENVEO timestep |

### Export and discharge

| Script | Description |
|--------|-------------|
| `export_data.sh` | Export all gate-masked raster data to `tmp/dat.csv` |
| `export_gates.sh` | Export gate geometries to `out/gates.kml` and `out/gates.gpkg` |
| `compute_discharge.py` | Compute discharge time series using monthly DEMs for time-varying thickness |
| `compute_errors.py` | Compute discharge uncertainties |
| `figures.py` | Generate figures |

## Repository structure

```
MFID/
├── README.md
├── Makefile
├── scripts/
│   ├── lib/common.sh       ← shared shell boilerplate
│   ├── import_*.sh         ← data import steps
│   ├── find_gates.sh
│   ├── gate_metadata.sh
│   ├── compute_vel_eff.sh
│   ├── export_*.sh
│   ├── compute_discharge.py
│   ├── compute_errors.py
│   └── figures.py
├── docker/                 ← Dockerfiles for the two images
└── out/                    ← output CSV files (generated)
```
