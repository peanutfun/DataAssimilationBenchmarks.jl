########################################################################################################################
module SingleExperimentDriver 
########################################################################################################################
# imports and exports
using Random, Distributions
using Debugger
using Distributed
using LinearAlgebra
using JLD
using DeSolvers
using L96 
using EnsembleKalmanSchemes
using FilterExps
using SmootherExps
export filter_state_exp, filter_param_exp, classic_smoother_state_exp, classic_smoother_param_exp, 
        hybrid_smoother_state_exp, hybrid_smoother_param_exp, iterative_smoother_state_exp

########################################################################################################################
########################################################################################################################
## Timeseries data 
########################################################################################################################
# observation timeseries to load into the experiment as truth twin
# timeseries are named by the model, seed to initialize, the integration scheme used to produce, number of analyses,
# the spinup length, and the time length between observation points
#
time_series = "./data/timeseries/l96_timeseries_seed_0000_dim_40_diff_0.00_tanl_0.05_nanl_50000_spin_5000_h_0.010.jld"
#time_series = "./data/timeseries/l96_timeseries_seed_0000_dim_40_diff_0.00_tanl_0.10_nanl_50000_spin_5000_h_0.010.jld"
#time_series = "./data/timeseries/l96_timeseries_seed_0000_dim_40_diff_0.10_tanl_0.05_nanl_50000_spin_5000_h_0.005.jld"
#time_series = "./data/timeseries/l96_timeseries_seed_0000_dim_40_diff_0.10_tanl_0.10_nanl_50000_spin_5000_h_0.005.jld"
########################################################################################################################

########################################################################################################################
## Experiments to run as a single function call
########################################################################################################################

########################################################################################################################
# Filters
########################################################################################################################
## filter_state single run for degbugging, arguments are
## [time_series, scheme, seed, obs_un, obs_dim, N_ens, infl] = args

function filter_state_exp()
    args = (time_series, "enkf-n", 0, 1.0, 40, 25, 1.00)
    filter_state(args)
end


########################################################################################################################
## filter_param single run for degbugging, arguments are
## [time_series, scheme, seed, obs_un, obs_dim, param_err, param_wlk, N_ens, state_infl, param_infl] = args

function filter_param_exp()
    args = (time_series, "etkf", 0, 1.0, 40, 0.03, 0.0000, 25, 1.02, 1.0)
    filter_param(args)
end


########################################################################################################################

########################################################################################################################
# Classic smoothers
########################################################################################################################
## classic_state single run for degbugging, arguments are
## [time_series, method, seed, lag, shift, obs_un, obs_dim, N_ens, infl] = args

function classic_smoother_state_exp()
    args = (time_series, "etks", 0, 51, 1, 1.0, 40, 35, 1.05)
    classic_state(args)
end


########################################################################################################################
## classic_param single run for debugging, arguments are
## [time_series, method, seed, lag, shift, obs_un, obs_dim, param_err, param_wlk, N_ens, state_infl, param_infl] = args

function classic_smoother_param_exp()
    args = (time_series, "enks", 0, 1, 1, 1.0, 40, 0.03, 0.01, 24, 1.08, 1.0) 
    classic_param(args)
end


########################################################################################################################

########################################################################################################################
# Hybrid smoothers
########################################################################################################################
# hybrid_state single run for degbugging, arguments are
# [time_series, method, seed, lag, shift, adaptive, mda, obs_un, obs_dim, N_ens, infl] = args

function hybrid_smoother_state_exp()
    args = (time_series, "etks", 0, 3, 1, false, 1.0, 40, 25, 1.00)
    hybrid_state(args)
end


########################################################################################################################
# hybrid_param single run for debugging, arguments are
# time_series, method, seed, lag, shift, mda, obs_un, obs_dim, param_err, 
# param_wlk, N_ens, state_infl, param_infl = args

function hybrid_smoother_param_exp()
    args = (time_series, "etks", 0, 1, 1, false, 1.0, 40, 0.03, 0.0100, 25, 1.05, 1.00)
    hybrid_param(args)
end


########################################################################################################################
# Iterative smoothers
########################################################################################################################
# iterative_state single run for degbugging, arguments are
# [time_series, method, seed, lag, shift, mda, obs_un, obs_dim, N_ens, infl] = args
function iterative_smoother_state_exp()
    args = (time_series, "ienks-bundle", 0, 2, 1, false, 1.0, 40, 25, 1.02)
    iterative_state(args)
end


########################################################################################################################


end
