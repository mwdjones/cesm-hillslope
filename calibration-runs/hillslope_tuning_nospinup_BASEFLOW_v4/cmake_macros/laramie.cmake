if (COMP_NAME STREQUAL gptl)
  string(APPEND CPPDEFS " -DHAVE_NANOTIME -DBIT64 -DHAVE_VPRINTF -DHAVE_BACKTRACE -DHAVE_SLASHPROC -DHAVE_COMM_F2C -DHAVE_TIMES -DHAVE_GETTIMEOFDAY")
endif()
set(NETCDF_PATH "$ENV{NETCDF}")
set(PIO_FILESYSTEM_HINTS "gpfs")
set(PNETCDF_PATH "$ENV{PNETCDF}")
