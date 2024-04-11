'''Imports'''

import numpy as np
import matplotlib.pyplot as plt
from matplotlib import gridspec
import pandas as pd
import xarray as xr
from bayes_opt import BayesianOptimization
from bayes_opt import UtilityFunction
import time
import seaborn as sns
from itertools import product
from scipy.interpolate import interp2d
import json
from glob import glob
import scipy.stats
from bayes_opt.util import load_logs

#ML
from sklearn.gaussian_process import GaussianProcessRegressor 


'''CLM CASE SETUP'''
from clmmodtools import *

#setup case
CASE_NAME = 'hillslope-bayes-opt'
CASE_DIR = '/glade/u/home/marielj/cesm-hillslope/' + CASE_NAME

'''LOAD CALIB DATA'''
dt2 =pd.read_csv('./rawdata/Streamflow_daily.csv', 
                 parse_dates=['Date'])

# Coerce the data into the types specified in the metadata  
dt2.Watershed = dt2.Watershed.astype('category') 

# Pull out 2015 year
stream = dt2[dt2.Date.dt.year == 2015]
stream = stream[stream.Watershed == 'S2'].reset_index(drop = True)

#Convert cm/day to mm/sec
m = 10/(60*60*24)
stream['Flow_mms'] = m*stream['Flow (cm/day)']

'''Load calibration WTE data'''               
dt1 =pd.read_csv('./rawdata/MEF_daily_peatland_water_table.csv', skiprows = 1, sep = ",",
                 names=["PEATLAND", "DATE", "WTE", "FLAG"],
                 parse_dates=['DATE'], 
                 na_values={'WTE':['NA',], 'FLAG':['NA',]})

# Coerce the data into the types specified in the metadata  
dt1.PEATLAND = dt1.PEATLAND.astype('category') 

dt1.WTE = pd.to_numeric(dt1.WTE, errors ='coerce')  
dt1.FLAG = dt1.FLAG.astype('category') 

# Pull out 2017 year
wte = dt1[dt1.DATE.dt.year == 2015]
wte = wte[wte.PEATLAND == 'S2'].reset_index(drop = True)
wte['WTD'] = -(422.0 - wte.WTE)


'''FUNCTION SETUP'''
def rsquared(x, y):
    slope, intercept, r_value, p_value, std_err = scipy.stats.linregress(x, y)
    return r_value**2


def blackbox_clm(baseflow, fmax):
    #change parameter in netcdf file
    target_surface_file = '/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_3_col_hillslope_lagg_pft_soildepth.nc'
    target_param1 = 'baseflow_scalar'
    target_param2 = 'FMAX' 
    
    #change fmax
    change_surf_param(target_param2, fmax, 0, target_surface_file)
    
    os.chdir(CASE_DIR)
    
    #change baseflow_scalar
    change_nl_param(target_param1, baseflow)
    
    #run case
    pipe = subprocess.Popen(['./case.submit'], stdout=subprocess.PIPE)
    #result = pipe.communicate()[0]
    #print(result)
    #print(CASE_NAME + " Run Complete")
    
    #time delay -- check if archived data exists, if not wait 5 more seconds
    SCRATCH_DIR = '/glade/derecho/scratch/marielj/archive/' + CASE_NAME + '/lnd/hist/'
    while(not os.path.exists(SCRATCH_DIR + CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')):
        time.sleep(5)
    
    #find WTE data in scracth directory
    os.chdir(SCRATCH_DIR)
    
    #Open data h1 data file
    dat = xr.load_dataset(CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')
    mod = dat.QRUNOFF.values.reshape(365)
    meas = np.array(stream['Flow_mms'])
    
    #Compute correlation
    r2_plot = rsquared(meas, mod)
    
    #remove data
    os.remove(CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')
    
    #return average annual WTE
    return r2_plot

'''
def blackbox_NDclm(baseflow, fmax, sand, clay):
    #change parameter in netcdf file
    target_surface_file = '/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_3_col_hillslope_lagg_pft_soildepth_mineral_nofmax.nc'
    target_param1 = 'baseflow_scalar'
    target_param2 = 'FMAX' 
    target_param3 = 'PCT_CLAY'
    target_param4 = 'PCT_SAND'
    
    #change fmax
    change_surf_param(target_param2, fmax, 0, target_surface_file)
    #Assign to the top part of the soil column (indices 0 through 7)
    for i in range(0, 8):
        change_surf_param(target_param3, clay, i, target_surface_file)
        change_surf_param(target_param4, sand, i, target_surface_file)
    
    os.chdir(CASE_DIR)
    
    #change baseflow_scalar
    change_nl_param(target_param1, baseflow)
    
    #run case
    pipe = subprocess.Popen(['qcmd', '-- ./case.submit'], stdout=subprocess.PIPE)
    #result = pipe.communicate()[0]
    #print(result)
    #print(CASE_NAME + " Run Complete")
    
    #time delay -- check if archived data exists, if not wait 5 more seconds
    SCRATCH_DIR = '/glade/scratch/marielj/archive/' + CASE_NAME + '/lnd/hist/'
    while(not os.path.exists(SCRATCH_DIR + CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')):
        time.sleep(5)
    
    #find WTE data in scracth directory
    os.chdir(SCRATCH_DIR)
    
    #Open data h1 data file
    dat = xr.load_dataset(CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')
    mod = dat.QRUNOFF.values.reshape(365)
    meas = np.array(stream['Flow_mms'])
    
    #Compute correlation
    r2_plot = rsquared(meas, mod)
    
    #remove data
    os.remove(CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')
    
    #return average annual WTE
    return r2_plot
    


def blackbox_clm_wte(baseflow, fmax):
    #change parameter in netcdf file
    target_surface_file = '/glade/work/marielj/inputdata/lnd/clm2/surfdata_map/hillslope/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_3_col_hillslope_lagg_pft_soildepth_nofmax.nc'
    target_param1 = 'baseflow_scalar'
    target_param2 = 'FMAX' 
    
    #change fmax
    change_surf_param(target_param2, fmax, 0, target_surface_file)
    
    os.chdir(CASE_DIR)
    
    #change baseflow_scalar
    change_nl_param(target_param1, baseflow)
    
    #run case
    pipe = subprocess.Popen(['qcmd', '-- ./case.submit'], stdout=subprocess.PIPE)
    #result = pipe.communicate()[0]
    #print(result)
    #print(CASE_NAME + " Run Complete")
    
    #time delay -- check if archived data exists, if not wait 5 more seconds
    #Have to check for the column specific run here for proper bog wte calibration
    SCRATCH_DIR = '/glade/scratch/marielj/archive/' + CASE_NAME + '/lnd/hist/'
    while(not os.path.exists(SCRATCH_DIR + CASE_NAME + '.clm2.h3.2015-01-01-00000.nc')):
        time.sleep(5)
    
    #find WTE data in scracth directory
    os.chdir(SCRATCH_DIR)
    
    #Open data h1 data file
    dat = xr.load_dataset(CASE_NAME + '.clm2.h3.2015-01-01-00000.nc')
    mod = -np.array(dat.sel(column = 1).ZWT).reshape(365) #take SPECIFICALLY the bog water table
    meas = np.array(wte.WTD)
    
    #Compute correlation
    r2_plot = rsquared(meas, mod)
    
    #remove data
    os.remove(CASE_NAME + '.clm2.h3.2015-01-01-00000.nc')
    
    #return average annual WTE
    return r2_plot
'''


'''SAVE PROGRESS'''
from bayes_opt.logger import JSONLogger
from bayes_opt.event import Events

clm_optimizer = BayesianOptimization(f = blackbox_clm, 
                                    pbounds = {'baseflow': (0,10),
                                               'fmax': (0, 0.4)}, 
                                    random_state = 57289, 
                                    verbose = 0
                                    )
#Load existing logs
#load_logs(clm_optimizer, logs=["/glade/u/home/marielj/cesm-hillslope/hillslope_full_log.json"])
#print("New optimizer is now aware of {} points.".format(len(clm_optimizer.space)))

#logger object records optimization search
logger = JSONLogger(path="/glade/u/home/marielj/cesm-hillslope/logs/hillslope_logs_exploitation_stream.json", reset = False)
clm_optimizer.subscribe(Events.OPTIMIZATION_STEP, logger)


#Aquisition function
acquisition_function = UtilityFunction(kind = "ucb", kappa = 1)



'''RUN OPTIMIZATION'''
clm_optimizer.maximize(init_points = 20, n_iter = 60,
                       aquisition_function = acquisition_function,
                       allow_duplicate_points = True)


'''PLOT PROGRESS'''
#for p in ['baseflow', 'fmax']:
#    x = [res["params"][p] for res in clm_optimizer.res]
#    
#    fig, ax = plt.subplots(1, 1, figsize = (8,1))
#    plt.eventplot(x, orientation='horizontal', colors='b', alpha = 0.4)
#    plt.axis('off')
#    plt.suptitle(p)
#    plt.savefig('/glade/u/home/marielj/cesm-hillslope/figures/bayesopt/param_' + p + '_bayesopt.pdf')