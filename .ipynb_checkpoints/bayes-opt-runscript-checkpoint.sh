#!/bin/bash
#PBS -N bayes-opt
#PBS -A UMIN0008
#PBS -l walltime=12:00:00
#PBS -q main
#PBS -j oe
#PBS -k eod
#PBS -l select=3:ncpus=1:mpiprocs=1:mem=109GB
#PBS -m abe
#PBS -M jone3247@umn.edu

module load conda
conda activate ncdf

### Run the executable
python bayes-opt-full.py
