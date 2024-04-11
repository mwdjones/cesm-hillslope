#!/usr/bin/env cesm
# -*- coding: utf-8 -*-
"""
Created on Mon Feb 13 09:50:00 2023
Modifying CLM code to test parameter sensitivity. For now this will run without spinup. When the spin up issues are solved, the 
parameter adjustements will be made in between the prespinup (AD) and the spinup.

@author: M.W. Jones
"""

import os
import glob
import subprocess
import shutil

import numpy as np
import matplotlib.pyplot as plt
import pandas as pd
import xarray as xr

# #####
# Parameters
# #####

#Dictionary containing params and their test values (multipliers)
params = {'BASEFLOW': [10e-8, 10e-7, 10e-6, 10e-4, 10e-2, 1, 2], 
			'FMAX' : [0.0001, 0.001, 0.005, 0.01, 0.05, 0.075, 0.1], 
			'PCT_CLAY':[0, 5, 10, 20, 30], 
			'SLATOP':[0.004, 0.008, 0.016, 0.032, 0.04],
			'PCT_SAND':[0, 5, 10, 20, 30]}

PARAM = 'FMAX' 

# #####
# Case Setup
# #####

#Source Root - Where the CESM code lives
SRCROOT_DIR = '/glade/u/home/marielj/ctsm-hillslope_hydrology'
#CIME Root - Where the CIME code lives, i.e. where the create_newcase scripts are
CIMEROOT_DIR = '/glade/u/home/marielj/ctsm-hillslope_hydrology/cime'
#Case Root - Where all the CESM cases are stored
CASEROOT_DIR = '/glade/u/home/marielj/cesm-hillslope/calibration-runs'
#User Mods Dir - Where the surface and domain files are
USER_MODS_DIR = '/glade/work/marielj/inputdata/'
#Forcing Data Root - Where the atmospheric forcing data is
CLMFORC_DIR = '/glade/work/marielj/inputdata/atm/datm7/CLM1PT_data'
COMPSET = '2000_DATM%1PT_CLM50%SP_SICE_SOCN_SROF_SGLC_SWAV_SIAC_SESP'

for i in range(0, len(params[PARAM])):
	CASE_NAME = 'hillslope_tuning_nospinup_' + PARAM + '_v' + str(i) 
	CASE_DIR = CASEROOT_DIR + '/' + CASE_NAME
	
	#print(CASE_NAME)
	#print(params[PARAM][i])

	#Check if directory exists - if not, create new case
	if(not os.path.exists(CASE_DIR)):
		print('Case does not exist. Creating new case.')
		#Create case
		os.chdir(CIMEROOT_DIR + '/scripts')
		subprocess.check_output(['./create_clone',
						'--case=%s' % CASE_DIR,
						'--clone=/glade/u/home/marielj/cesm-hillslope/test-hillslope-mct-srof',   
						'--user-mods-dir=%s' % USER_MODS_DIR, 
						'--project=UMIN0008'])
        
	else:
		print('Case already exists.')

	os.chdir(CASE_DIR)

	######
	# Set up case
	######

	pipe = subprocess.Popen(['./case.setup'], stdout=subprocess.PIPE)
	result = pipe.communicate()[0]
	print(result)
	print('Setup complete')

	######
	# Change XML
	######

	#General
	subprocess.check_output(['./xmlchange', 'DATM_MODE=CLM1PT'])
	subprocess.check_output(['./xmlchange', 'CLM_FORCE_COLDSTART=off'])
	subprocess.check_output(['./xmlchange', 'CONTINUE_RUN=FALSE'])
	subprocess.check_output(['./xmlchange', 'CLM_USRDAT_NAME=1x1pt_US-MBP'])

	#Calendar
	subprocess.check_output(['./xmlchange', 'CALENDAR=NO_LEAP'])

	#Run start date
	subprocess.check_output(['./xmlchange', 'RUN_STARTDATE=1990-01-01'])

	#Align with tower data
	subprocess.check_output(['./xmlchange', 'DATM_CLMNCEP_YR_ALIGN=2011'])
	subprocess.check_output(['./xmlchange', 'DATM_CLMNCEP_YR_START=2011'])
	subprocess.check_output(['./xmlchange', 'DATM_CLMNCEP_YR_END=2017'])

	#Stop options
	subprocess.check_output(['./xmlchange', 'STOP_OPTION=nyears'])
	subprocess.check_output(['./xmlchange', 'STOP_N=28'])

	#Set Forcing data directory
	subprocess.check_output(['./xmlchange', 'DIN_LOC_ROOT_CLMFORC=%s' % CLMFORC_DIR])
    
    #Change domain paths
	subprocess.check_output(['./xmlchange', 'ATM_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic'])
	subprocess.check_output(['./xmlchange', 'LND_DOMAIN_PATH=/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic'])
	subprocess.check_output(['./xmlchange', 'ATM_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc'])
	subprocess.check_output(['./xmlchange', 'LND_DOMAIN_FILE=domain.lnd.1x1pt_US-MBP_navy.230220.nc'])
    
	
	#History files
	file_name = 'user_nl_clm'
	f = open(file_name, 'w')
	f.write(" fsurdat = '/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_3_col_hillslope_lagg_pft_soildepth_measparam.nc'\n") 
	f.write(" use_hillslope = .true.\n") #Additional namelist params for hillslope
	f.write(" use_hillslope_routing = .true.\n")
	f.write(" use_init_interp = .true.\n")
	f.write(" hillslope_pft_distribution_method = 'FromFile'\n")
	f.write(" hillslope_soil_profile_method = 'FromFile'\n")
	f.write(" hist_nhtfrq = 0,0,-24,-24\n")
	f.write(" hist_mfilt = 1,1,365,365\n")
	f.write(" hist_dov2xy = .true.,.false.,.true.,.false.\n")
	f.write(" hist_fincl2 = 'RAIN', 'H2OSNO', 'QSOIL', 'QVEGT', 'QSNOMELT', 'QRUNOFF', 'ZWT', 'ZWT_PERCH', 'SNOW', 'TSA', 'SOILICE', 'QINFL', 'QOVER', 'H2OSOI', 'TSOI', 'FSAT', 'FSNO', 'QICE', 'TREFMNAV', 'TREFMXAV'\n")
	f.write(" hist_fincl3 = 'RAIN', 'H2OSNO', 'QSOIL', 'QVEGT', 'QSNOMELT', 'QRUNOFF', 'ZWT', 'ZWT_PERCH', 'SNOW', 'TSA', 'SOILICE', 'QINFL', 'QOVER', 'H2OSOI', 'TSOI', 'FSAT', 'FSNO', 'QICE', 'TREFMNAV', 'TREFMXAV'\n")
	f.write(" hist_fincl4 = 'RAIN', 'H2OSNO', 'QSOIL', 'QVEGT', 'QSNOMELT', 'QRUNOFF', 'ZWT', 'ZWT_PERCH', 'SNOW', 'TSA', 'SOILICE', 'QINFL', 'QOVER', 'H2OSOI', 'TSOI', 'FSAT', 'FSNO', 'QICE', 'TREFMNAV', 'TREFMXAV'\n")
    
	######
	# Make Parameter Change
	######

	if(PARAM == 'BASEFLOW'):
		#Can change this value easily in the namelist files
		f.write(" baseflow_scalar = " + str(params[PARAM][i]*1e-2))

	if(PARAM == 'FMAX'):
		#Can change this value easily in the namelist files
		f.write(" soil_fmax = " + str(params[PARAM][i]))
        
	if(PARAM == 'PCT_CLAY'):
		#Can change this value easily in the namelist files
		f.write(" soil_clay = " + str(params[PARAM][i]))

	if(PARAM == 'PCT_SAND'):
		#Can change this value easily in the namelist files
		f.write(" soil_sand = " + str(params[PARAM][i]))
        
	if((PARAM == 'FROOTLEAF') | (PARAM == 'SLATOP') | (PARAM == 'LEAFLONG')):
		#Add new param file to namelist modifications
		PARAM_FILE = '/glade/u/home/marielj/cesm-hillslope/calibration-runs/params/' + PARAM + '/params_modified_' + PARAM + '_v' + str(i) + '.nc'
		f.write(" paramfile = '" + PARAM_FILE + "'")     

	f.close() 

	
	######
	# Run Simulation
	######
	
	#Clear run directory
	pipe = subprocess.Popen(['./case.build', '--clean-all'], stdout=subprocess.PIPE)

	#Build
	pipe = subprocess.Popen(['qcmd', '-- ./case.build'], stdout=subprocess.PIPE)
	result = pipe.communicate()[0]
	print(result)
	print(CASE_NAME + " Build Complete")

	#Run
	pipe = subprocess.Popen(['qcmd', '-- ./case.submit'], stdout=subprocess.PIPE)
	result = pipe.communicate()[0]
	print(result)
	print(CASE_NAME + " Run Complete")

	######
	# Store Output
	######

	
	#Make Save Folder
	#Check for directory
	if(not os.path.exists('/glade/u/home/marielj/cesm-hillslope/calibration-runs/stored-data/%s' % CASE_NAME)):
		os.mkdir('/glade/u/home/marielj/cesm-hillslope/calibration-runs/stored-data/%s' % CASE_NAME)
		print('New save directory for: ' + CASE_NAME)
	
	'''
	SAVEPATH = '/glade/u/home/marielj/cesm-hillslope/calibration-runs/stored-data/%s' + CASE_NAME
	SCRATCH_DIR = '/glade/scratch/marielj/archive/' + CASE_NAME + '/lnd/hist/'
	FILE_NAME = '*' + '.h1.' + '*'

	#Check if history files have been saved, if not, save them -- not finding files
	os.chdir(SCRATCH_DIR)

	files = glob.glob(FILE_NAME)
	for file in files:
		if(not os.path.isfile(SAVEPATH + '/' + file)):
			shutil.copy2(file, SAVEPATH)
			print(file + " did not exist. Saved.")
		else:
			print(file + " already exists.")
	'''

