if (NOT DEBUG)
  string(APPEND CFLAGS " -O2")
endif()
set(CONFIG_ARGS "--host=cray")
set(ESMF_LIBDIR "/projects/ccsm/esmf-6.3.0rp1/lib/libO/Linux.intel.64.openmpi.default")
if (NOT DEBUG)
  string(APPEND FFLAGS " -O2")
endif()
set(NETCDF_PATH "$ENV{NETCDFROOT}")
set(PIO_FILESYSTEM_HINTS "lustre")
set(PNETCDF_PATH "$ENV{PNETCDFROOT}")
string(APPEND SLIBS " -L${NETCDF_PATH}/lib -lnetcdff -L/projects/ccsm/BLAS-intel -lblas_LINUX")