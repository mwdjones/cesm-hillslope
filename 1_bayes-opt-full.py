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
CASE_NAME = 'hillslope-bayes-opt-medlynslope'
CASE_DIR = '/glade/u/home/marielj/cesm-hillslope/' + CASE_NAME
calib_year = 2015

'''LOAD CALIB DATA'''
## Calibration Streamflow data
dt2 =pd.read_csv('./rawdata/Streamflow_daily.csv', 
                 parse_dates=['Date'])

# Coerce the data into the types specified in the metadata  
dt2.Watershed = dt2.Watershed.astype('category') 

#Convert cm/day to mm/day
dt2['flow_mmday'] = 10*dt2['Flow (cm/day)']

# Pull out 2017 year
stream_calib = dt2[dt2.Date.dt.year == calib_year]
stream_calib = stream_calib[stream_calib.Watershed == 'S2'].reset_index(drop = True)

## Load calibration WTE              
dt1 =pd.read_csv('./rawdata/MEF_daily_peatland_water_table.csv', skiprows = 1, sep = ",",
                 names=["PEATLAND", "DATE", "WTE", "FLAG"],
                 parse_dates=['DATE'], 
                 na_values={'WTE':['NA',], 'FLAG':['NA',]})

# Coerce the data into the types specified in theA metadata  
dt1.PEATLAND = dt1.PEATLAND.astype('category') 
dt1.WTE = pd.to_numeric(dt1.WTE, errors ='coerce')  
dt1.FLAG = dt1.FLAG.astype('category') 

bog_elev = 422.06
dt1['WTD'] =  -(bog_elev - dt1.WTE)

# Pull out calib year
wte_calib = dt1[dt1.DATE.dt.year == calib_year]
wte_calib = wte_calib[wte_calib.PEATLAND == 'S2'].reset_index(drop = True)

## Load calibration ET data
dt3 = xr.load_dataset('/glade/derecho/scratch/swensosc/Ameriflux/AMF_US-MBP_set.nc').to_dataframe().reset_index()

#Replace Nan
flux = dt3.replace(-9999, np.NaN)
flux['time'] = pd.to_datetime(flux.time).dt.round('15min')
#convert LE to AET
lhv = 2.5e6 #J/kg latent heat of vaporization
sphh = 1800 # seconds per half hour
flux['OET'] = flux.LE/lhv * sphh #et in mm/halfhour
#resample to daily timestep
flux_daily = flux.set_index('time').resample('D').mean().reset_index() #et in mm/day
flux_daily['OET'] = flux_daily['OET']*24 #half hours to daily (halved while i figure wtf id going on)
flux_daily = flux_daily[(flux_daily.time.dt.year > 2011) & (flux_daily.time.dt.year < 2018)].reset_index(drop = True)

#pull out calibration data
flux_calib = flux_daily[flux_daily.time.dt.year == calib_year]

'''FUNCTION SETUP'''
def rvalue(obs, mod):
    nanmask = np.isfinite(obs)
    y = obs[nanmask]
    x = mod[nanmask]
    slope, intercept, r_value, p_value, std_err = scipy.stats.linregress(x, y)
    return r_value

def calcLCE(obs, mod):
    r = rvalue(obs, mod)
    alpha = np.nanstd(mod)/np.nanstd(obs)
    beta = np.nanmean(mod)/np.nanmean(obs)
    return 1 -np.sqrt(((r*alpha - 1)**2) + ((r/alpha - 1)**2) + (beta - 1)**2)

def calcCompoundLCE(observedWTE, modelWTE, observedQ, modelQ, observedET, modelET):
    wteLCE = calcLCE(observedWTE, modelWTE)
    qLCE = calcLCE(observedQ, modelQ)
    etLCE = calcLCE(observedET, modelET)

    #Could replace later with different weights
    return np.mean([wteLCE, qLCE, etLCE])

def blackbox_clm_wte(baseflow, fmax, slopebeta, fff, conifslope, decidslope, grassslope):
    #change parameter in netcdf file
    target_surface_file = '/glade/u/home/marielj/cesm-hillslope/calib-surf-files/surfdata_1x1pt_US-MBP_hist_16pfts_Irrig_CMIP6_simyr2000_HAND_3_col_hillslope_lagg_pftdist_soildepth.nc'
    target_param_file = '/glade/u/home/marielj/cesm-hillslope/calib-surf-files/clm50_params_medlynslope_bayesopt.c240105.nc'
    target_param1 = 'baseflow_scalar'
    target_param2 = 'FMAX' 
    target_param3 = 'slopebeta'
    target_param4 = 'fff'
    target_param5 = 'medlynslope'
    base_grass_ms = 5.25
    base_conif_ms = 2.3499999
    base_decid_ms = 4.44999981

    #change grass parameters 
    change_pft_param(target_param5, 13, grassslope*base_grass_ms, target_param_file)

    #change tree parameters
    change_pft_param(target_param5, 2, conifslope*base_conif_ms, target_param_file) #conif
    change_pft_param(target_param5, 8, decidslope*base_decid_ms, target_param_file) #decid
    
    #change surface parameters
    change_surf_param(target_param2, fmax, 0, target_surface_file)

    #change param file
    change_param(target_param3, slopebeta, target_param_file)
    change_param(target_param4, fff, target_param_file)
    
    os.chdir(CASE_DIR)
    
    #change namelist parameters
    change_nl_param(target_param1, baseflow)

    #run case
    pipe = subprocess.Popen(['./case.submit'], stdout=subprocess.PIPE)
    #result = pipe.communicate()[0]
    #print(result)
    #print(CASE_NAME + " Run Complete")
    
    #time delay -- check if archived data exists, if not wait 5 more seconds
    #Have to check for the column specific run here for proper bog wte calibration
    SCRATCH_DIR = '/glade/derecho/scratch/marielj/archive/' + CASE_NAME + '/lnd/hist/'
    while(not os.path.exists(SCRATCH_DIR + CASE_NAME + '.clm2.h3.2015-01-01-00000.nc')):
        time.sleep(5)
    
    #find WTE data in scracth directory
    os.chdir(SCRATCH_DIR)
    
    #Open data h1 and h3 data files
    coldata = xr.load_dataset(CASE_NAME + '.clm2.h3.2015-01-01-00000.nc')
    data = xr.load_dataset(CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')
    
    #Compute correlation metric
    spday = 86400
    data['ET'] = data.QVEGT + data.QSOIL
    observedWTE = np.array(wte_calib.WTD)
    modelWTE = -np.array(coldata.sel(column = 1).sel(time = slice("2015-01-01", "2015-12-31")).ZWT.values)
    observedQ = np.array(stream_calib.flow_mmday)
    modelQ = spday*np.array(data.sel(time = slice("2015-01-01", "2015-12-31")).QRUNOFF.values.ravel())
    observedET = np.array(flux_calib.OET)
    modelET = spday*np.array(data.sel(time = slice("2015-01-01", "2015-12-31")).ET.values.ravel())
    #Compound Lee Choi Efficiency
    LCE = calcCompoundLCE(observedWTE, modelWTE, observedQ, modelQ, observedET, modelET)
    
    #remove data
    os.remove(CASE_NAME + '.clm2.h3.2015-01-01-00000.nc')
    os.remove(CASE_NAME + '.clm2.h2.2015-01-01-00000.nc')
    
    #return efficiency metric
    return LCE


'''SAVE PROGRESS'''
from bayes_opt.logger import JSONLogger
from bayes_opt.event import Events

clm_optimizer = BayesianOptimization(f = blackbox_clm_wte, 
                                    pbounds = {'baseflow': (0,10),
                                               'fmax': (0.1, 0.7), 
                                               'slopebeta' : (-10e2, 10), 
                                               'fff' : (0.1, 5), 
                                               'conifslope' : (1, 40), 
                                               'decidslope' : (1, 40), 
                                               'grassslope' : (1, 40)}, 
                                    random_state = 75832, 
                                    verbose = 0
                                    )
#Load existing logs
load_logs(clm_optimizer, logs=["/glade/u/home/marielj/cesm-hillslope/logs/hillslope_logs_medlynslope.json"])
print("New optimizer is now aware of {} points.".format(len(clm_optimizer.space)))

#logger object records optimization search
logger = JSONLogger(path="/glade/u/home/marielj/cesm-hillslope/logs/hillslope_logs_medlynslope.json", reset = False)
clm_optimizer.subscribe(Events.OPTIMIZATION_STEP, logger)


#Aquisition function
acquisition_function = UtilityFunction(kind = "ucb", kappa = 0.1)

#update bounds range - go a little higher on both scalars
clm_optimizer.set_bounds(new_bounds={"baseflow": (0, 20), 
                                    "grassslope" : (1, 60), 
                                    "fff" : (0.01, 5), 
                                    "fmax" : (0.01, 0.7)})


'''RUN OPTIMIZATION'''
clm_optimizer.maximize(init_points = 0, n_iter = 10,
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