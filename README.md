# MFID — Mass Flux Ice Discharge for ESA CCI+ Greenland, Phase 3

Calculates the mass flux ice discharge (MFID) for the Greenland Ice Sheet as part of the ESA CCI+ Greenland project. Ice discharge is calculated from the CCI Ice Velocity (IV) product, the CCI Surface Elevation Change (SEC) product (where it overlaps with the ice discharge gates), and ice thickness from BedMachine. Ice discharge gates are placed 10 km upstream from all marine-terminating glacier termini with baseline velocities above 150 m/yr. Results are summed by Zwally et al. (2012) sectors.

Based on the workflow by Ken Mankoff for the PROMICE Solid Ice Discharge product:
> Mankoff, Ken; Solgaard, Anne; Larsen, Signe, 2020, "Greenland Ice Sheet solid ice discharge from 1986 through last month: Discharge", https://doi.org/10.22008/promice/data/ice_discharge/d/v02, GEUS Dataverse, V101

Methods are described in Mankoff et al. (2020; DOI: 10.5194/essd-12-1367-2020).

## Output

- `out/` — CSV files with mass flow rate ice discharge (Gt yr⁻¹), discharge uncertainty (Gt yr⁻¹), and gate coverage [0–1], by sector.

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

The `Makefile` runs the full pipeline in order:

| Step | Script | Description |
|------|--------|-------------|
| `import` | `scripts/import.sh` | Import input data (BedMachine, velocity, SEC, etc.) into GRASS |
| `GRASS` | `scripts/gate_IO_runner.sh` | Find and characterise ice discharge gates |
| | `scripts/vel_eff.sh` | Compute effective velocity at gates |
| | `scripts/export.sh` | Export raster results from GRASS |
| `PYTHON` | `scripts/errors.py` | Compute discharge uncertainties |
| | `scripts/raw2discharge.py` | Convert raw gate data to discharge time series |
| | `scripts/gate_export.sh` | Export gate geometries |
| | `scripts/figures.py` | Generate figures |

`scripts/dSEC.sh` imports the CCI dSEC (surface elevation change) product and is called as part of the import step.

## Repository structure

```
MFID/
├── README.md
├── Makefile
├── scripts/          ← all processing scripts
├── docker/           ← Dockerfiles for the two images
└── out/              ← output CSV files (generated)
```
