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

$(STAMPS)/elevation: scripts/import_elevation.sh $(STAMPS)/dsec | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_elevation.sh
	touch $@

$(STAMPS)/dsec: scripts/import_dsec.sh | $(STAMPS)
	$(GRASS_EXEC) ./scripts/import_dsec.sh
	touch $@

import: $(STAMPS)/bedmachine $(STAMPS)/sectors $(STAMPS)/area_error \
        $(STAMPS)/velocity $(STAMPS)/names $(STAMPS)/elevation $(STAMPS)/dsec

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

out/GIS_D.csv out/catchment_D.csv: scripts/compute_discharge.py tmp/dat.csv out/gate_meta.csv
	$(CONDA_EXEC) python ./scripts/compute_discharge.py

tmp/err_sector_mouginot.csv: scripts/compute_errors.py tmp/dat.csv out/gate_meta.csv
	$(CONDA_EXEC) python ./scripts/compute_errors.py

out/catchment_variability.csv: scripts/compute_variability.py tmp/dat.csv tmp/dem_ts.csv out/catchment_D.csv
	$(CONDA_EXEC) python ./scripts/compute_variability.py

out/sector_variability.csv: scripts/compute_sector_variability.py out/sector_D.csv
	$(CONDA_EXEC) python ./scripts/compute_sector_variability.py

out/sector_seasonality.csv: scripts/compute_sector_seasonality.py out/sector_D.csv
	$(CONDA_EXEC) python ./scripts/compute_sector_seasonality.py

discharge: out/GIS_D.csv out/catchment_D.csv tmp/err_sector_mouginot.csv out/catchment_variability.csv out/sector_variability.csv out/sector_seasonality.csv

## Figures ----------------------------------------------------------------

figs/discharge_ts.png: scripts/figures.py out/GIS_D.csv
	mkdir -p figs
	$(CONDA_EXEC) python ./scripts/figures.py

figs/sector_variability_scatter.png: scripts/figures_sector_variability.py out/sector_variability.csv out/sector_D.csv out/sector_err.csv
	mkdir -p figs
	$(CONDA_EXEC) python ./scripts/figures_sector_variability.py

figs/sector_map_trend.png: scripts/figures_sector_map.py out/sector_variability.csv plot_data/Zwally_2012/sectors/sectors.shp plot_data/outlines/Kyst.shp
	mkdir -p figs
	$(CONDA_EXEC) python ./scripts/figures_sector_map.py

figs/sector_seasonality_cycle.png: scripts/figures_sector_seasonality.py out/sector_seasonality.csv out/sector_seasonality_annual.csv out/sector_D.csv
	mkdir -p figs
	$(CONDA_EXEC) python ./scripts/figures_sector_seasonality.py

figures: figs/discharge_ts.png figs/sector_variability_scatter.png figs/sector_map_trend.png figs/sector_seasonality_cycle.png

## Distribution -----------------------------------------------------------

# ESA CCI delivery zip: product files plus README.txt, description.txt and a
# quicklook (<= 1200 px). Files 644, folder 755, nothing hidden. Analysis
# outputs (variability, seasonality, catchment_*) are not part of the product.
# Staged in a local temp dir because chmod has no effect on the SMB share.
DIST_NAME ?= MFID_v3.0
DIST_FILES = $(foreach s,GIS region sector gate,$(foreach v,D err coverage,out/$(s)_$(v).csv)) \
    out/constant_thickness_GIS_D.csv out/gate_meta.csv out/gates.gpkg out/gates.kml \
    MFID/README.txt MFID/description.txt

dist: $(DIST_NAME).zip

$(DIST_NAME).zip: $(DIST_FILES) figs/discharge_ts.png
	@test $$(wc -c < MFID/description.txt) -le 100 || { echo "description.txt > 100 chars"; exit 1; }
	@file figs/quicklook.png | grep -Eq ', ([0-9]{1,3}|1[01][0-9]{2}|1200) x ([0-9]{1,3}|1[01][0-9]{2}|1200),' \
	    || { echo "figs/quicklook.png larger than 1200x1200"; exit 1; }
	@stage=$$(mktemp -d) && \
	mkdir $$stage/$(DIST_NAME) && \
	cp $(DIST_FILES) $$stage/$(DIST_NAME)/ && \
	cp figs/quicklook.png $$stage/$(DIST_NAME)/quicklook.png && \
	chmod 755 $$stage/$(DIST_NAME) && chmod 644 $$stage/$(DIST_NAME)/* && \
	rm -f $@ && (cd $$stage && zip -rX $(CURDIR)/$@ $(DIST_NAME)) && \
	rm -rf $$stage
	unzip -Z $@

clean:
	rm -fR G tmp out figs CCI.zip $(DIST_NAME).zip .stamps
