./case.setup

./xmlchange DATM_MODE=1PT

./xmlchange CLM_FORCE_COLDSTART=off

./xmlchange CONTINUE_RUN=FALSE

./xmlchange CALENDAR=NO_LEAP

./xmlchange RUN_STARTDATE=2004-01-01

./xmlchange STOP_OPTION=nyears

./xmlchange STOP_N=14

./case.build

./case.submit

