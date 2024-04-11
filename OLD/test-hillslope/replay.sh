#!/bin/bash

set -e

# Created 2023-05-15 11:57:34

CASEDIR="/glade/u/home/marielj/cesm-hillslope/test-hillslope"

/glade/u/home/marielj/ctsm-hillslope_hydrology/cime/scripts/create_newcase --case "${CASEDIR}" --compset 2000_DATM%1PT_CLM50%SP_SICE_SOCN_MOSART_SGLC_SWAV --user-mods-dir /glade/u/home/marielj/cesm2.1.3/components/clm/tools/PTCLM/mydatafiles/1x1pt_US-MBP --res CLM_USRDAT --project UMIN008 --run-unsupported

cd "${CASEDIR}"

./case.setup

./xmlchange DATM_MODE=CLM1PT

./xmlchange DATM_MODE=1PT

./xmlchange CLM_FORCE_COLDSTART=pff

./xmlchange CLM_FORCE_COLDSTART=off

./xmlchange CONTINUE_RUN=FALSE

./xmlchange CLM_USRDAT_NAME=1x1pt_US-MBP

./xmlchange CALENDAR=NO_LEAP

./xmlchange RUN_STARTDATE=2011-01-01

./xmlchange DATM_CLMNCEP_YR_ALIGN=2011

./xmlchange DATM_YR_ALIGN=2011

./xmlchange DATM_YR_START=2011

./xmlchange DATM_YR_END=2017

./xmlchange STOP_OPTION=nyears

./xmlchange STOP_N=7

./xmlchange DIN_LOC_ROOT_CLMFORC=/glade/work/marielj/inputdata/atm/datm7/CLM1PT_data

./xmlchange ATM_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic

./xmlchange LND_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic

./xmlchange LND_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc

./xmlchange ATM_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc

./case.build

./preview_namelists

./preview_namelists

./case.build

./case.submit

./xmlchange PROJECT=UMIN0008

./case.build

./preview_namelists

./case.build

./case.submit

./xmlchange LND_DOMAIN_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_4_col_hillslope.nc

./xmlchange ATM_DOMAIN_MESH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_4_col_hillslope.nc

./case.build

./case.submit

