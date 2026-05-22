container_cmd ?= docker
container_args ?= run --user $(shell id -u):$(shell id -g) --mount type=bind,src=${DATADIR},dst=/data --mount type=bind,src=$(shell pwd),dst=/home/user --env PARALLEL="--delay 0.1 -j -1"


all: docker G import GRASS PYTHON dist


docker: FORCE ## Pull down Docker environment
	docker pull hillerup/ice_discharge:grass
	${container_cmd} ${container_args} hillerup/ice_discharge:grass
	docker pull hillerup/ice_discharge:conda
	${container_cmd} ${container_args} hillerup/ice_discharge:conda conda env export -n base


G:
	grass -e -c EPSG:3413 ./G


import: FORCE
	${container_cmd} ${container_args} hillerup/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/import.sh



GRASS: FORCE
	#${container_cmd} ${container_args} hillerup/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/import.sh
	${container_cmd} ${container_args} hillerup/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/gate_IO_runner.sh
	${container_cmd} ${container_args} hillerup/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/vel_eff.sh
	${container_cmd} ${container_args} hillerup/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/export.sh


PYTHON: FORCE
	${container_cmd} ${container_args} hillerup/ice_discharge:conda python ./scripts/errors.py
	${container_cmd} ${container_args} hillerup/ice_discharge:conda python ./scripts/raw2discharge.py
	${container_cmd} ${container_args} hillerup/ice_discharge:grass grass ./G/PERMANENT --exec ./scripts/gate_export.sh
	mkdir -p figs
	${container_cmd} ${container_args} hillerup/ice_discharge:conda python ./scripts/figures.py

dist:
	ln -s out CCI
	zip -r CCI.zip CCI
	rm CCI

FORCE: # dummy target

clean:
	rm -fR G tmp out figs CCI.zip
