if (NOT DEBUG)
  string(APPEND CFLAGS " -O2")
endif()
set(CONFIG_ARGS "--host=cray")
string(APPEND CPPDEFS " -DLINUX")
if (NOT DEBUG)
  string(APPEND FFLAGS " -O2")
endif()
set(NETCDF_PATH "$ENV{NETCDF_HOME}")
set(PIO_FILESYSTEM_HINTS "lustre")
set(SLIBS "-L${NETCDF_PATH}/lib -lnetcdf -lnetcdff -lpmi -L$ENV{MKL_PATH} -lmkl_rt")