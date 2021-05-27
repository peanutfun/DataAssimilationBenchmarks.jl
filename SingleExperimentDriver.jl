########################################################################################################################
module SingleExperimentDriver
########################################################################################################################
########################################################################################################################
# imports and exports
using Debugger
using FilterExps, SmootherExps, GenerateTimeSeries
export filter_state_exp, filter_param_exp, classic_smoother_state_exp, classic_smoother_param_exp,
        single_iteration_smoother_state_exp, single_iteration_smoother_param_exp, iterative_smoother_state_exp,
        l96_timeseries_exp

########################################################################################################################
########################################################################################################################
## Time series data
########################################################################################################################
# observation timeseries to load into the experiment as truth twin
# timeseries are named by the model, seed to initialize, the integration scheme used to produce, number of analyses,
# the spinup length, and the time length between observation points
#
time_series = "./data/time_series/l96_timeseries_seed_0000_dim_40_diff_0.00_tanl_0.05_nanl_50000_spin_5000_h_0.010.jld"
#time_series = "./data/time_series/l96_time_series_seed_0000_dim_40_diff_0.00_tanl_0.10_nanl_50000_spin_5000_h_0.010.jld"
#time_series = "./data/time_series/l96_time_series_seed_0000_dim_40_diff_0.10_tanl_0.05_nanl_50000_spin_5000_h_0.005.jld"
#time_series = "./data/time_series/l96_time_series_seed_0000_dim_40_diff_0.10_tanl_0.10_nanl_50000_spin_5000_h_0.005.jld"
########################################################################################################################

########################################################################################################################
## Generate time series data
########################################################################################################################
## Experiments to run as a single function call, arguments are
## [seed, states_dim, tanl, diffusion] = args

function l96_timeseries_exp()
    args = (0, 40, 0.05, 0.00)
    l96_timeseries(args)
end
########################################################################################################################
# Filters
########################################################################################################################
## filter_state single run for degbugging, arguments are
## [time_series, scheme, seed, obs_un, obs_dim, γ, N_ens, infl] = args

function filter_state_exp()
    args = (time_series, "etkf", 0, 1.0, 40, 5.00, 25, 1.03)
    filter_state(args)
end


########################################################################################################################
## filter_param single run for degbugging, arguments are
## [time_series, scheme, seed, obs_un, obs_dim, γ, param_err, param_wlk, N_ens, state_infl, param_infl] = args

function filter_param_exp()
    args = (time_series, "etkf", 0, 1.0, 40, 1.0, 0.03, 0.0000, 25, 1.02, 1.0)
    filter_param(args)
end


########################################################################################################################

########################################################################################################################
# Classic smoothers
########################################################################################################################
## classic_state single run for degbugging, arguments are
# time_series, method, seed, lag, shift, obs_un, obs_dim, γ, N_ens, infl = args

function classic_smoother_state_exp()
    args = (time_series, "etks", 0, 4, 4, 1.0, 40, 1.0, 25, 1.03)
    classic_state(args)
end


########################################################################################################################
## classic_param single run for debugging, arguments are
# time_series, method, seed, lag, shift, obs_un, obs_dim, γ,
# param_err, param_wlk, N_ens, state_infl, param_infl = args

function classic_smoother_param_exp()
    args = (time_series, "etks", 0, 10, 1, 1.0, 40, 1.0, 0.03, 0.001, 25, 1.03, 1.0)
    classic_param(args)
end


########################################################################################################################

########################################################################################################################
# Single iteration smoothers
########################################################################################################################
## single_iteration_state single run for degbugging, arguments are
# time_series, method, seed, lag, shift, adaptive, mda, obs_un, obs_dim, γ, N_ens, infl = args

function single_iteration_smoother_state_exp()
    args = (time_series, "etks", 0, 16, 4, false, 1.0, 40, 1.0, 21, 1.03)
    single_iteration_state(args)
end


########################################################################################################################
## single_iteration_param single run for debugging, arguments are
# time_series, method, seed, lag, shift, mda, obs_un, obs_dim, γ,
# param_err, param_wlk, N_ens, state_infl, param_infl = args

function single_iteration_smoother_param_exp()
    args = (time_series, "etks", 0, 10, 1, false, 1.0, 40, 1.0, 0.03, 0.0010, 21, 1.01, 1.00)
    single_iteration_param(args)
end


########################################################################################################################
# Iterative smoothers
########################################################################################################################
## iterative_state single run for degbugging, arguments are
# time_series, method, seed, lag, shift, adaptive, mda, obs_un, obs_dim, γ, N_ens, infl = args
function iterative_smoother_state_exp()
    args = (time_series, "ienks-transform", 0, 10, 1, false, 1.0, 40, 1.0, 21, 1.03)
    iterative_state(args)
end

########################################################################################################################

end
