string(APPEND CFLAGS " -g -qfullpath -qmaxmem=-1")
if (NOT DEBUG)
  string(APPEND CFLAGS " -O3")
endif()
if (compile_threaded)
  string(APPEND CFLAGS " -qsmp=omp")
endif()
if (DEBUG AND compile_threaded)
  string(APPEND CFLAGS " -qsmp=omp:noopt")
endif()
string(APPEND CPPDEFS " -DFORTRAN_SAME -DCPRIBM")
set(CPRE "-WF,-D")
set(FC_AUTO_R8 "-qrealsize=8")
string(APPEND FFLAGS " -g -qfullpath -qmaxmem=-1")
if (NOT DEBUG)
  string(APPEND FFLAGS " -O2 -qstrict -qinline=auto")
endif()
if (compile_threaded)
  string(APPEND FFLAGS " -qsmp=omp")
endif()
if (DEBUG)
  string(APPEND FFLAGS " -qinitauto=7FF7FFFF -qflttrap=ov:zero:inv:en")
endif()
if (DEBUG AND compile_threaded)
  string(APPEND FFLAGS " -qsmp=omp:noopt")
endif()
if (DEBUG AND COMP_NAME STREQUAL pop)
  string(APPEND FFLAGS " -C")
endif()
set(FIXEDFLAGS "-qsuffix=f=f -qfixed=132")
set(FREEFLAGS "-qsuffix=f=f90:cpp=F90")
set(HAS_F2008_CONTIGUOUS "TRUE")
if (compile_threaded)
  string(APPEND LDFLAGS " -qsmp=omp")
endif()
if (DEBUG AND compile_threaded)
  string(APPEND LDFLAGS " -qsmp=omp:noopt")
endif()
