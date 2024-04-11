string(APPEND CPPDEFS " -DHAVE_NANOTIME")
set(NETCDF_PATH "$ENV{TACC_NETCDF_DIR}")
set(PIO_FILESYSTEM_HINTS "lustre")
set(PNETCDF_PATH "$ENV{TACC_PNETCDF_DIR}")
string(APPEND LDFLAGS " -Wl,-rpath,${NETCDF_PATH}/lib")
string(APPEND SLIBS " -L${NETCDF_PATH}/lib -lnetcdff -lnetcdf")
