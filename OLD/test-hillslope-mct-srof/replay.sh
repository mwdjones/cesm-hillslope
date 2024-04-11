#!/bin/bash

set -e

# Created 2023-05-16 09:59:29

CASEDIR="/glade/u/home/marielj/cesm-hillslope/test-hillslope-mct-srof"

/glade/u/home/marielj/ctsm-hillslope_hydrology/cime/scripts/create_newcase --case "${CASEDIR}" --compset 2000_DATM%1PT_CLM50%SP_SICE_SOCN_SROF_SGLC_SWAV --user-mods-dir /glade/u/home/marielj/cesm2.1.3/components/clm/tools/PTCLM/mydatafiles/1x1pt_US-MBP --res CLM_USRDAT --project UMIN0008 --run-unsupported --driver mct

cd "${CASEDIR}"

./case.setup

./xmlchange DATM_MODE=CLM1PT

./xmlchange CLM_FORCE_COLDSTART=off

./xmlchange CONTINUE_RUN=FALSE

./xmlchange CLM_USRDAT_NAME=1x1pt_US-MBP

./xmlchange CALENDAR=NO_LEAP

./xmlchange RUN_STARTDATE=2011-01-01

./xmlchange DATM_CLMNCEP_YR_ALIGN=2011

./xmlchange DATM_CLMNCEP_YR_START=2011

./xmlchange DATM_CLMNCEP_YR_END=2017

./xmlchange STOP_N=7

./xmlchange DIN_LOC_ROOT_CLMFORC=/glade/work/marielj/inputdata/atm/datm7/CLM1PT_data

./xmlchange ATM_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic

./xmlchange LND_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic

./xmlchange ATM_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc

./xmlchange STOP_OPTION=nyears

./case.build

./xmlchange LND_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc

./case.build

./case.submit

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.build

./case.build --clean-all

./case.build

./case.submit

./xmlchange RUN_STARTDATE=2004-01-01

./xmlchange STOP_N=14

./case.build --clean-all

./case.build

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.setup

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.submit

./case.submit

./case.submit

./case.submit

./case.submit

./case.submit

