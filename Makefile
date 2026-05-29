container_cmd ?= docker
container_args ?= run --user $(shell id -u):$(shell id -g) \
    --mount type=bind,src=${DATADIR},dst=/data \
    --mount type=bind,src=$(shell pwd),dst=/home/user \
    --env PARALLEL="--delay 0.1 -j -1"

GRASS_EXEC = ${container_cmd} ${container_args} hillerup/ice_discharge:grass grass ./G/PERMANENT --exec
CONDA_EXEC  = ${container_cmd} ${container_args} hillerup/ice_discharge:conda

STAMPS = .stamps

all: docker G import gates export discharge figures

## Docker images
docker:
	docker pull hillerup/ice_discharge:grass
	docker pull hillerup/ice_discharge:conda

## GRASS database
G:
	grass -e -c EPSG:3413 ./G

$(STAMPS):
	mkdir -p $@

## Import -----------------------------------------------------------------

$(STAMPS)/bedmachine: scripts/import_bedmachine.sh | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_bedmachine.sh
	touch $@

$(STAMPS)/sectors: scripts/import_sectors.sh | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_sectors.sh
	touch $@

$(STAMPS)/area_error: scripts/import_area_error.sh | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_area_error.sh
	touch $@

$(STAMPS)/velocity: scripts/import_velocity.sh | $(STAMPS)/bedmachine
	$(GRASS_EXEC) ./scripts/import_velocity.sh
	touch $@

$(STAMPS)/names: scripts/import_names.sh | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_names.sh
	touch $@

$(STAMPS)/elevation: scripts/import_elevation.sh $(STAMPS)/sec | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_elevation.sh
	touch $@

$(STAMPS)/sec: scripts/import_sec.sh | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_sec.sh
	touch $@

import: $(STAMPS)/bedmachine $(STAMPS)/sectors $(STAMPS)/area_error \
        $(STAMPS)/velocity $(STAMPS)/names $(STAMPS)/elevation $(STAMPS)/sec

## Gates ------------------------------------------------------------------

$(STAMPS)/gates: scripts/find_gates.sh \
    | $(STAMPS)/bedmachine $(STAMPS)/velocity $(STAMPS)/sectors $(STAMPS)/elevation
	$(GRASS_EXEC) ./scripts/find_gates.sh
	touch $@

out/gate_meta.csv: scripts/gate_metadata.sh | $(STAMPS)/gates $(STAMPS)/names
	$(GRASS_EXEC) ./scripts/gate_metadata.sh

$(STAMPS)/vel_eff: scripts/compute_vel_eff.sh | $(STAMPS)/gates $(STAMPS)/velocity
	$(GRASS_EXEC) ./scripts/compute_vel_eff.sh
	touch $@

gates: out/gate_meta.csv $(STAMPS)/vel_eff

## Export from GRASS ------------------------------------------------------

tmp/dat.csv: scripts/export_data.sh | out/gate_meta.csv $(STAMPS)/vel_eff $(STAMPS)/area_error
	$(GRASS_EXEC) ./scripts/export_data.sh

out/gates.gpkg: scripts/export_gates.sh | out/gate_meta.csv
	$(GRASS_EXEC) ./scripts/export_gates.sh

export: tmp/dat.csv out/gates.gpkg

## Discharge and errors ---------------------------------------------------

out/GIS_D.csv: scripts/compute_discharge.py tmp/dat.csv out/gate_meta.csv
	$(CONDA_EXEC) python ./scripts/compute_discharge.py

tmp/err_sector_mouginot.csv: scripts/compute_errors.py tmp/dat.csv out/gate_meta.csv
	$(CONDA_EXEC) python ./scripts/compute_errors.py

discharge: out/GIS_D.csv tmp/err_sector_mouginot.csv

## Figures ----------------------------------------------------------------

figs/discharge_ts.png: scripts/figures.py out/GIS_D.csv
	mkdir -p figs
	$(CONDA_EXEC) python ./scripts/figures.py

figures: figs/discharge_ts.png

## Distribution -----------------------------------------------------------

dist:
	ln -s out CCI
	zip -r CCI.zip CCI
	rm CCI

clean:
	rm -fR G tmp out figs CCI.zip .stamps
