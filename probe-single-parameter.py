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

from clmmodtools import *

# #####
# Parameters
# #####

#Dictionary containing params and their test values (multipliers)
params = {'SLOPEBETA' : [-1000, -100, -10, -3, 0, 10, 10], 'BASEFLOW': [0, 2, 4, 6, 8], 'FFF': [0.1, 0.25, 0.5, 0.75, 1, 3, 5], 'FMAX' : [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]}

# #####
# Case Setup
# #####

#Source Root - Where the CESM code lives
SRCROOT_DIR = '/glade/u/home/marielj/ctsm-hillslope_hydrology'
#CIME Root - Where the CIME code lives, i.e. where the create_newcase scripts are
CIMEROOT_DIR = '/glade/u/home/marielj/ctsm-hillslope_hydrology/cime'
#Case Root - Where all the CESM cases are stored
CASEROOT_DIR = '/glade/u/home/marielj/cesm-hillslope/probing-cases'
#Forcing Data Root - Where the atmospheric forcing data is
CLMFORC_DIR = '/glade/work/marielj/inputdata/atm/datm7/CLM1PT_data'
#Clone case 
CLONE_DIR = '/glade/u/home/marielj/cesm-hillslope/hillslope-bayes-opt-soilpftmods'
#PARAM file
PARAM_FILE = '/glade/u/home/marielj/cesm-hillslope/calib-surf-files/clm50_params.c240105.nc'
#SURF file
SURF_FILE = '/glade/u/home/marielj/cesm-hillslope/calib-surf-files/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_3_col_hillslope_borealpftdistribution_bedrock.nc'

for PARAM in params:
    for i in range(0, len(params[PARAM])):
        CASE_NAME = 'hillslope_probing_' + PARAM + '_' + str(params[PARAM][i]) 
        CASE_DIR = CASEROOT_DIR + '/' + CASE_NAME
	
        #print(CASE_NAME)
        #print(params[PARAM][i])
 
        #Check if directory exists - if not, create new case
        if(not os.path.exists(CASE_DIR)):
            print('Case does not exist. Creating new case.')
            #Create case
            os.chdir(CIMEROOT_DIR + '/scripts')
            subprocess.check_output(['./create_clone', '--case=%s' % CASE_DIR, '--clone=%s' % CLONE_DIR])

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
        subprocess.check_output(['./xmlchange', 'DATM_MODE=1PT'])
        subprocess.check_output(['./xmlchange', 'CLM_FORCE_COLDSTART=off'])
        subprocess.check_output(['./xmlchange', 'CONTINUE_RUN=FALSE'])

        #Calendar
        subprocess.check_output(['./xmlchange', 'CALENDAR=NO_LEAP'])

        #Run start date
        subprocess.check_output(['./xmlchange', 'RUN_STARTDATE=2004-01-01'])

        #Stop options
        subprocess.check_output(['./xmlchange', 'STOP_OPTION=nyears'])
        subprocess.check_output(['./xmlchange', 'STOP_N=14'])

        #History files
        file_name = 'user_nl_clm'
        f = open(file_name, 'w')
        f.write(" fsurdat = '/glade/u/home/marielj/cesm-hillslope/calib-surf-files/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_3_col_hillslope_borealpftdistribution_bedrock.nc'\n") 
        f.write("paramfile = '/glade/u/home/marielj/cesm-hillslope/calib-surf-files/clm50_params.c240105.nc'\n")
        f.write("use_hillslope = .true.\n")
        f.write("use_hillslope_routing = .true.\n")
        f.write("use_init_interp = .true.\n")
        f.write("hist_nhtfrq = 0,0,-24,-24\n")
        f.write("hist_mfilt = 1,1,365,365\n")
        f.write("hist_dov2xy = .true.,.false.,.true.,.false.\n")
        f.write("hist_fincl2 = 'RAIN', 'H2OSNO', 'QSOIL', 'QVEGT', 'QSNOMELT', 'QRUNOFF', 'ZWT', 'ZWT_PERCH', 'SNOW', 'TSA', 'SOILICE', 'QINFL', 'QOVER', 'H2OSOI', 'TSOI', 'FSAT', 'FSNO', 'QICE', 'TREFMNAV', 'TREFMXAV'\n")
        f.write("hist_fincl3 = 'RAIN', 'H2OSNO', 'QSOIL', 'QVEGT', 'QSNOMELT', 'QRUNOFF', 'ZWT', 'ZWT_PERCH', 'SNOW', 'TSA', 'SOILICE', 'QINFL', 'QOVER', 'H2OSOI', 'TSOI', 'FSAT', 'FSNO', 'QICE', 'TREFMNAV', 'TREFMXAV'\n")
        f.write("hist_fincl4 = 'RAIN', 'H2OSNO', 'QSOIL', 'QVEGT', 'QSNOMELT', 'QRUNOFF', 'ZWT', 'ZWT_PERCH', 'SNOW', 'TSA', 'SOILICE', 'QINFL', 'QOVER', 'H2OSOI', 'TSOI', 'FSAT', 'FSNO', 'QICE', 'TREFMNAV', 'TREFMXAV'\n")
        #f.write("hillslope_soil_profile_method = 'FromFile'\n")
        f.write("n_dom_pfts = 5\n")

        ######
        # Make Parameter Change
        ######

        if(PARAM == 'BASEFLOW'):
            #Can change this value easily in the namelist files
            f.write(" baseflow_scalar = " + str(params[PARAM][i]*1e-2))
            #Change others back to base
            change_surf_param('FMAX', 0.3746, 0, SURF_FILE)
            change_param('slopebeta', -3, PARAM_FILE) 
            change_param('fff', 0.5, PARAM_FILE)

        f.close()
	
        if(PARAM == 'FFF'):
            #change value
            change_param('fff', params[PARAM][i], PARAM_FILE) 
            #set others back to base
            change_surf_param('FMAX', 0.3746, 0, SURF_FILE)
            change_param('slopebeta', -3, PARAM_FILE) 

        if(PARAM == 'SLOPEBETA'):
            #change value
            change_param('slopebeta', params[PARAM][i], PARAM_FILE) 
            #set others back to base
            change_surf_param('FMAX', 0.3746, 0, SURF_FILE)
            change_param('fff', 0.5, PARAM_FILE)
   
        if(PARAM == 'FMAX'):
            #change value
            change_surf_param('FMAX', params[PARAM][i], 0, SURF_FILE)
            #Set others back to base
            change_param('fff', 0.5, PARAM_FILE) 
            change_param('slopebeta', -3, PARAM_FILE) 

        ######
        # Run Simulation
        ######
        os.chdir(CASE_DIR)

        #Build
        pipe = subprocess.Popen(['./case.build'], stdout=subprocess.PIPE)
        result = pipe.communicate()[0]
        print(result)
        print(CASE_NAME + " Build Complete")

        #Run
        pipe = subprocess.Popen(['./case.submit'], stdout=subprocess.PIPE)
        result = pipe.communicate()[0]
        print(result)
        print(CASE_NAME + " Case Submitted")
