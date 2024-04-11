#!/usr/bin/env cesm
# -*- coding: utf-8 -*-
"""
Useful functions for integrating mods and other test into CLM runs

Available functions:
    change_param()
    change_pft_param()
    setup_mef_case()
    
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

def change_param(param, value, param_file):
    #param - string name of target parameter
    #value - float value for target parameter
    #param_file - param file to be edited, will be overwritten with new value
    
    #Load data
    dat = xr.load_dataset(param_file)
    
    #Check to make sure the size of existing data matches the replacement data
    #Add or comment out as needed
    if hasattr(value, "__len__"):
        print('Error: attempting to replace scalar value with array')
        return
    
    # Write value
    dat[param] = value
    
    # Save netcdf
    dat.to_netcdf(param_file)
    
    #Check
    dat_check = xr.load_dataset(param_file)
    if(dat_check[param] == value):
        print('Value successfully changed')
        return
    else:
        print('Failed to change value')
        return
    
def change_surf_param(param, value, ind, param_file):
    #param - string name of target parameter
    #value - float value for target parameter
    #param_file - param file to be edited, will be overwritten with new value
    
    #Load data
    dat = xr.load_dataset(param_file)
    
    #Check to make sure the size of existing data matches the replacement data
    #Add or comment out as needed
    if hasattr(value, "__len__"):
        print('Error: attempting to replace scalar value with array')
        return
    
    # Write value
    if(param == 'fmax'):
        dat[param][ind] = value
    else:
        dat[param][ind][0] = value
    
    # Save netcdf
    dat.to_netcdf(param_file)
    
    #Check
    dat_check = xr.load_dataset(param_file)
    if(param == 'fmax'):
        if(dat_check[param][ind] == value):

            print('Value successfully changed')
            return
        else:
            print('Failed to change value')
            return
    else:
        if(dat_check[param][ind][0] == value):

            print('Value successfully changed')
            return
        else:
            print('Failed to change value')
            return

def change_pft_param(param, pft, value, param_file):
    #param - string name of target parameter
    #pft - integer of the pft type (12 for arctic grass)
    #value - float value for target parameter
    #param_file - param file to be edited, will be overwritten with new value
    
    #Load data
    dat = xr.load_dataset(param_file)
    
    #Check to make sure the size of existing data matches the replacement data
    #Add or comment out as needed
    if hasattr(value, "__len__"):
        print('Error: attempting to replace scalar value with array. Cannot handle multipe pfts at once.')
        return
    elif len(dat[param].values) == 1:
        print('Error: target variable is not pft dependent. Use change_param for replacing scalar paramters.')
        return
    
    # Write value
    dat[param][pft] = value
    
    # Save netcdf
    dat.to_netcdf(param_file)
    
    #Check
    dat_check = xr.load_dataset(param_file)
    if(dat_check[param][pft] == value):
        #print('Value successfully changed')
        return
    else:
        print('Failed to change value')
        return

    
def change_hillslope_param(param, col, value, param_file):
    #param - string name of target parameter
    #pft - integer of the pft type (12 for arctic grass)
    #value - float value for target parameter
    #param_file - param file to be edited, will be overwritten with new value
    
    #Load data
    dat = xr.load_dataset(param_file)
    
    #Check to make sure the size of existing data matches the replacement data
    #Add or comment out as needed
    if hasattr(value, "__len__"):
        print('Error: attempting to replace scalar value with array. Cannot handle multipe columns at once.')
        return
    elif len(dat[param].values) == 1:
        print('Error: target variable is not column dependent. Use change_param for replacing scalar paramters.')
        return
    
    # Write value
    dat[param][col] = value
    
    # Save netcdf
    dat.to_netcdf(param_file)
    
    #Check
    dat_check = xr.load_dataset(param_file)
    if(dat_check[param][col] == value):
        #print('Value successfully changed')
        return
    else:
        print('Failed to change value')
        return
    
def change_nl_param(param, value):
    #param - string name of the target parameter
    #value - float value for the target parameter
    ### MUST BE RUN AFTER NAVIGATING TO THE CASE DIR
    
    file_name = 'user_nl_clm'
    
    #Delete Previous Instance
    try:
        with open(file_name, 'r') as fr:
            # reading line by line
            lines = fr.readlines()

            # pointer for position
            ptr = 1

            # opening in writing mode
            with open(file_name, 'w') as fw:
                for line in lines:
                    if param not in line:
                        fw.write(line)
                        ptr += 1
                    elif param in line:
                        #print("Deleted")
                        ptr += 1

                #Rewrite
                fw.write("\n " + param + " = " + str(value)) 
                print('New value added')  
   
    except:
        print("There was an error replacing the parameter value.")
         
            
    return

    

def setup_mef_case(CASEROOT_DIR, CASE_NAME, MODS = True, nyears = 7, BUILD = True):
    #CASEROOT_DIR - Where the new cesm case will be stored
    #CASE_NAME - case name for case created
    #MODS - boolean to include parameter manipulation mods, default is true
    #nyears - number of years to run the simulation for, default is 7 (all years)
    #BUILD - boolean 'to build or not to build'

    ######
    # Case Setup
    ######

    #Source Root - Where the CESM code lives
    SRCROOT_DIR = '/glade/u/home/marielj/cesm2.1.3'
    #CIME Root - Where the CIME code lives, i.e. where the create_newcase scripts are
    CIMEROOT_DIR = '/glade/u/home/marielj/cesm2.1.3/cime'
    #User Mods Dir - Where the surface and domain files are
    USER_MODS_DIR = '/glade/u/home/marielj/cesm2.1.3/components/clm/tools/PTCLM/mydatafiles/1x1pt_US-MBP'
    #Forcing Data Root - Where the atmospheric forcing data is
    CLMFORC_DIR = '/glade/work/marielj/inputdata/atm/datm7/CLM1PT_data'
    COMPSET = '2000_DATM%1PT_CLM50%SP_SICE_SOCN_MOSART_SGLC_SWAV'  #I1PtClm50SpGs
    #Case Dir
    CASE_DIR = CASEROOT_DIR + '/' + CASE_NAME
    
    #Check if directory exists - if not, create new case, if so, exit
    if(not os.path.exists(CASE_DIR)):
        print('Case does not exist. Creating new case.')
        #Create case
        os.chdir(CIMEROOT_DIR + '/scripts')
        subprocess.check_output(['./create_newcase',
                        '--case=%s' % CASE_DIR,
                        '--compset=%s' % COMPSET,
                        '--user-mods-dir=%s' % USER_MODS_DIR,
                        '--res=CLM_USRDAT', 
                        '--project=UMIN0008', 
                        '--run-unsupported',
                        '--handle-preexisting-dirs=r'])
    else:
        print('Case already exists.')
        return
    
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
    subprocess.check_output(['./xmlchange', 'RUN_STARTDATE=2011-01-01'])

    #Align with tower data
    subprocess.check_output(['./xmlchange', 'DATM_CLMNCEP_YR_ALIGN=2011'])
    subprocess.check_output(['./xmlchange', 'DATM_CLMNCEP_YR_START=2011'])
    subprocess.check_output(['./xmlchange', 'DATM_CLMNCEP_YR_END=2017'])

    #Stop options
    subprocess.check_output(['./xmlchange', 'STOP_OPTION=nyears'])
    subprocess.check_output(['./xmlchange', 'STOP_N=%s' % nyears])

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
    f.write(" fsurdat = '/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/arcticgrass-organic/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_c230220_v3.nc'\n") #change to v4 or v3 depending on mixed PFTs or arctic grass respectively
    f.write(" finidat = '/glade/u/home/marielj/clm_frost/cesm_cases/spinup/finaldata/1ptBGC_spinup_grass.clm2.r.0201-01-01-00000.nc'\n") #Also change to the matching restart file
    f.write(" hist_nhtfrq = 0,-24\n")
    f.write(" hist_mfilt  = 1200,365\n")
    f.write(" hist_fincl2 = 'RAIN', 'H2OSNO', 'QSOIL', 'QVEGT', 'QSNOMELT', 'QRUNOFF', 'ZWT', 'ZWT_PERCH', 'SNOW', 'TSA', 'SOILICE', 'QINFL', 'QOVER', 'H2OSOI', 'TSOI'\n")

    if(MODS):
        #set new param file
        f.write(" paramfile = '/glade/work/marielj/inputdata/lnd/clm2/paramdata/clm5_params_augmented_base.c171117.nc'")
        f.close() 
        
        #Copy user mods from directory to case directory -- DO NOT change the CLM_USER_MODS xml
        USR_MODS_DIR='/glade/u/home/marielj/clm_frost/cesm_cases/calibration-mods/modified-source-files/'
        os.chdir(USR_MODS_DIR)

        shutil.copy2('SoilHydrologyMod.F90', CASE_DIR + '/SourceMods/src.clm')
        shutil.copy2('readParamsMod.F90', CASE_DIR + '/SourceMods/src.clm')
        shutil.copy2('initVerticalMod.F90', CASE_DIR + '/SourceMods/src.clm')
            
        #Check files made it
        if(os.path.exists(CASE_DIR + '/SourceMods/src.clm/SoilHydrologyMod.F90')):
            print('Mods copied successfully.')
        os.chdir(CASE_DIR)
    
    print('Case is setup and ready for building.')
    
    if(BUILD):
        os.chdir(CASE_DIR)
    
        pipe = subprocess.Popen(['./case.build', '--clean-all'], stdout=subprocess.PIPE)
        pipe = subprocess.Popen(['qcmd', '-- ./case.build'], stdout=subprocess.PIPE)
        result = pipe.communicate()[0]
        print(result)
        print("Case is built and ready to run.")
        
    else:
        return
