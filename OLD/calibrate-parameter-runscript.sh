#!/bin/bash
#PBS -N hillslope-tuning
#PBS -A UMIN0008
#PBS -l walltime=06:00:00
#PBS -q regular
#PBS -j oe
#PBS -k eod
#PBS -l select=3:ncpus=1:mpiprocs=1:mem=109GB
#PBS -m abe
#PBS -M jone3247@umn.edu

module load conda
conda activate cesm

### Run the executable
python calibrate-single-parameter.py
