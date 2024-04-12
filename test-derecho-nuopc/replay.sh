#!/bin/bash

set -e

# Created 2024-03-28 08:52:14

CASEDIR="/glade/u/home/marielj/cesm-hillslope/test-derecho-nuopc"

/glade/u/home/marielj/ctsm-hillslope_hydrology/cime/scripts/create_newcase --case "${CASEDIR}" --compset 2000_DATM%1PT_CLM50%SP_SICE_SOCN_SROF_SGLC_SWAV --res CLM_USRDAT --project UMIN0008 --run-unsupported --driver nuopc

cd "${CASEDIR}"

./case.setup

./xmlchange DATM_MODE=1PT

./xmlchange CLM_FORCE_COLDSTART=off

./xmlchange CONTINUE_RUN=FALSE

./xmlchange CLM_USRDAT_NAME=1x1pt_US-MBP

./xmlchange CALENDAR=NO_LEAP

./xmlchange RUN_STARTDATE=2011-01-01

./xmlchange DATM_YR_ALIGN=2011

./xmlchange DATM_YR_START=2011

./xmlchange DATM_YR_END=2017

./xmlchange STOP_OPTION=nyears

./xmlchange STOP_N=7

./xmlchange DIN_LOC_ROOT_CLMFORC=/glade/work/marielj/inputdata/atm/datm7/CLM1PT_data

./xmlchange ATM_DOMAIN_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/ESMFmesh_US-MBP_lagg_cdf5.nc

./xmlchange LND_DOMAIN_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/ESMFmesh_US-MBP_lagg_cdf5.nc

./xmlchange MASK_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/ESMFmesh_US-MBP_lagg_cdf5.nc

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./xmlchange ATM_DOMAIN_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/ESMFmesh_US-MBP_lagg.nc

./xmlchange LND_DOMAIN_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/ESMFmesh_US-MBP_lagg.nc

./xmlchange MASK_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/ESMFmesh_US-MBP_lagg.nc

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

./case.submit

./case.build --clean-all

./case.build

./case.submit

