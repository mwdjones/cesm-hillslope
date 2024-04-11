./xmlchange RESUBMIT=3,STOP_N=50,STOP_OPTION=nyears

./xmlchange DATM_CLMNCEP_YR_ALIGN=1

./xmlchange DATM_CLMNCEP_YR_START=2011

./xmlchange DATM_CLMNCEP_YR_END=2017

./case.build

./case.submit

./preview_namelists

