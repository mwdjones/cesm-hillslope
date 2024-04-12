./case.setup

./xmlchange DATM_MODE=CLM1PT

./xmlchange CLM_FORCE_COLDSTART=off

./xmlchange CONTINUE_RUN=FALSE

./xmlchange CLM_USRDAT_NAME=1x1pt_US-MBP

./xmlchange CALENDAR=NO_LEAP

./xmlchange RUN_STARTDATE=1990-01-01

./xmlchange DATM_CLMNCEP_YR_ALIGN=2011

./xmlchange DATM_CLMNCEP_YR_START=2011

./xmlchange DATM_CLMNCEP_YR_END=2017

./xmlchange STOP_OPTION=nyears

./xmlchange STOP_N=28

./xmlchange DIN_LOC_ROOT_CLMFORC=/glade/work/marielj/inputdata/atm/datm7/CLM1PT_data

./xmlchange ATM_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic

./xmlchange LND_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic

./xmlchange ATM_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc

./xmlchange LND_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc

./case.build --clean-all

./case.build

./case.submit

./case.build --clean-all

./case.build

./case.submit

