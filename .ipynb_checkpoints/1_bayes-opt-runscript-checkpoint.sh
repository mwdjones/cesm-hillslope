#!/bin/bash
#PBS -N bayes-opt
#PBS -A UMIN0008
#PBS -l walltime=4:00:00
#PBS -q main@desched1
#PBS -j oe
#PBS -k eod
#PBS -l select=3:ncpus=1:mpiprocs=1:mem=109GB
#PBS -m abe
#PBS -M jone3247@umn.edu

module load conda
conda activate ncdf

### Run the executable
python 1_bayes-opt-full.py
