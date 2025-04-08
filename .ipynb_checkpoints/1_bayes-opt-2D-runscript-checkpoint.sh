#!/bin/bash
#PBS -N bayes-opt
#PBS -A UMIN0008
#PBS -m abe
#PBS -M jone3247@umn.edu
#PBS -j oe
#PBS -k eod
#PBS -q main
#PBS -l walltime=10:00:00
#PBS -l select=2:ncpus=128:mpiprocs=128

module load conda
conda activate ncdf

### Run the executable
python 1_bayes-opt-2D.py
