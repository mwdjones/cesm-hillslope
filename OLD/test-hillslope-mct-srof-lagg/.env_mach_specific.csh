# This file is for user convenience only and is not used by the model
# Changes to this file will be ignored and overwritten
# Changes to the environment should be made in env_mach_specific.xml
# Run ./case.setup --reset to regenerate this file
source /glade/u/apps/ch/opt/lmod/7.5.3/lmod/lmod/init/csh
module purge 
module load ncarenv/1.3 python/3.7.9 cmake intel/19.1.1 esmf_libs mkl
module use /glade/p/cesmdata/cseg/PROGS/modulefiles/esmfpkgs/intel/19.1.1/
module load esmf-8.2.0b23-ncdfio-mpt-O mpt/2.22 netcdf-mpi/4.8.0 pnetcdf/1.12.2 ncarcompilers/0.5.0 pio/2.5.6
setenv OMP_STACKSIZE 1024M
setenv TMPDIR /glade/scratch/marielj
setenv MPI_TYPE_DEPTH 16
setenv MPI_IB_CONGESTED 1
setenv MPI_USE_ARRAY None
setenv TMPDIR /glade/scratch/marielj