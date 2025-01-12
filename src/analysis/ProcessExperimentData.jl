#######################################################################################################################
module ProcessExperimentData
########################################################################################################################
########################################################################################################################
# imports and exports
using Debugger
using Statistics
using JLD, HDF5
export process_filter_state, process_smoother_state, process_smoother_param, process_filter_nonlinear_obs, 
       process_smoother_nonlinear_obs, process_smoother_versus_shift, process_smoother_versus_tanl,   
       rename_smoother_state

########################################################################################################################
########################################################################################################################
# Scripts for processing experimental output data and writing to JLD and HDF5 to read into matplotlib later
#
# These scripts are designed to try to load every file according to the standard naming conventions
# and if these files cannot be loaded, to save inf as a dummy variable for missing or corrupted data.
########################################################################################################################

function process_filter_state()
    # creates an array of the average RMSE and spread for each experiment 
    # ensemble size is increasing from the origin on the horizontal axis
    # inflation is increasing from the origin on the vertical axis
    
    # time the operation
    t1 = time()

    # static parameters that are not varied 
    seed = 0
    tanl = 0.05
    nanl = 20000
    burn = 5000
    diffusion = 0.0
    h = 0.01
    obs_un = 1.0
    obs_dim = 40
    sys_dim = 40
    γ = 1.0
    
    # parameters in ranges that will be used in loops
    analysis_list = [
                     "fore", 
                     "filt",
                    ]
    stat_list = [
                 "rmse",
                 "spread",
                ]
    method_list = [
                   "enkf", 
                   "etkf",
                   "enkf-n-primal", 
                  ]
    ensemble_sizes = 15:2:41 
    total_ensembles = length(ensemble_sizes)
    inflations = LinRange(1.00, 1.10, 11)
    total_inflations = length(inflations)

    # define the storage dictionary here, looping over the method list
    data = Dict{String, Array{Float64}}()
    for method in method_list
        if method == "enkf-n"
            for analysis in analysis_list
                for stat in stat_list
                    # multiplicative inflation parameter should always be one, there is no dimension for this variable
                    data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_ensembles)
                end
            end
        else
            for analysis in analysis_list
                for stat in stat_list
                    # create storage for inflations and ensembles
                    data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_inflations, total_ensembles)
                end
            end
        end
    end

    # auxilliary function to process data, producing rmse and spread averages
    function process_data(fnames::Vector{String}, method::String)
        # loop ensemble size, last axis
        for j in 0:(total_ensembles - 1)
            if method[1:6] == "enkf-n"
                try
                    # attempt to load the file
                    tmp = load(fnames[j+1])
                    
                    # if successful, continue to unpack arrays and store the mean stats over 
                    # the experiment after the burn period for stationary statistics
                    for analysis in analysis_list
                        for stat in stat_list
                            analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                            
                            data[method * "_" * analyis * "_" * stat][j+1] = 
                            mean(analysis_stat[burn+1: nanl+burn])
                        end
                    end
                catch
                    # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                    for analysis in analysis_list
                        for stat in stat_list
                            analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                            data[method * "_" * analyis * "_" * stat][j+1] = inf
                        end
                    end
                end
            else
                # loop inflations, first axis
                for i in 1:total_inflations
                    try
                        # attempt to load the file
                        tmp = load(fnames[i + j*total_inflations])
                        
                        # if successful, continue to unpack arrays and store the mean stats over 
                        # the experiment after the burn period for stationary statistics
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                
                                data[method * "_" * analyis * "_" * stat][total_inflations + 1 - i, j + 1] =
                                mean(analysis_stat[burn+1: nanl+burn])
                            end
                        end
                    catch
                        # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                data[method * "_" * analyis * "_" * stat][total_inflations + 1 - i, j + 1] = inf
                            end
                        end
                    end
                end
            end
        end
    end

    # define path to data on server
    fpath = "/x/capa/scratch/cgrudzien/final_experiment_data/all_ens/"
    
    # generate the range of experiments, storing file names as a list
    for method in method_list
        fnames = [] 
        for N_ens in ensemble_sizes
            if method[1:6] == "enkf-n"
                
                # inflation is a static value of 1.0
                name = method * 
                        "_L96_state_seed_" * lpad(seed, 4, "0") *
                        "_diffusion_" * rpad(diffusion, 4, "0") * 
                        "_sys_dim_" * lpad(sys_dim, 2, "0") * 
                        "_obs_dim_" * lpad(obs_dim, 2, "0") * 
                        "_obs_un_" * rpad(obs_un, 4, "0") *
                        "_gamma_" * lpad(γ, 5, "0") *
                        "_nanl_" * lpad(nanl + burn, 5, "0") * 
                        "_tanl_" * rpad(tanl, 4, "0") * 
                        "_h_" * rpad(h, 4, "0") *
                        "_N_ens_" * lpad(N_ens, 3,"0") * 
                        "_state_inflation_" * rpad(round(1.0, digits=2), 4, "0") * 
                        ".jld"
                push!(fnames, fpath * method * "/diffusion_" * rpad(diffusion, 4, "0") * "/" * name)

            else
                # loop inflations
                for infl in inflations
                    name = method * 
                            "_L96_state_seed_" * lpad(seed, 4, "0") *
                            "_diffusion_" * rpad(diffusion, 4, "0") * 
                            "_sys_dim_" * lpad(sys_dim, 2, "0") * 
                            "_obs_dim_" * lpad(obs_dim, 2, "0") * 
                            "_obs_un_" * rpad(obs_un, 4, "0") *
                            "_gamma_" * lpad(γ, 5, "0") *
                            "_nanl_" * lpad(nanl + burn, 5, "0") * 
                            "_tanl_" * rpad(tanl, 4, "0") * 
                            "_h_" * rpad(h, 4, "0") *
                            "_N_ens_" * lpad(N_ens, 3,"0") * 
                            "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") * 
                            ".jld"
                    push!(fnames, fpath * method * "/diffusion_" * rpad(diffusion, 4, "0") * "/" * name)
                end
            end
        end

        # turn fnames into a string array, use this as the argument in process_data
        fnames = Array{String}(fnames)
        process_data(fnames, method)

    end

    # create jld file name with relevant parameters
    jlname = "processed_filter_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             ".jld"

    # create hdf5 file name with relevant parameters
    h5name = "processed_filter_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             ".h5"


    # write out file in jld
    save(jlname, data)

    # write out file in hdf5
    h5open(h5name, "w") do file
        for key in keys(data)
            h5write(h5name, key, data[key])
        end
    end
    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################

function process_smoother_state()
    # Create an array of the time-average RMSE and spread for each experiment, past
    # a burn-in period to reach stationary statistics for the experiment.
    # Lag is increasing form the origin on the first axis, inflation is increasing
    # from the origin on the second axis, ensemble size is increasing from the origin
    # on the third axis.
    
    # time the operation
    t1 = time()

    # static parameters that are not varied 
    seed = 0
    tanl = 0.05
    h = 0.01
    obs_un = 1.0
    obs_dim = 40
    γ = 1.0
    sys_dim = 40
    nanl = 20000
    burn = 5000
    shift = 1
    mda = true
    diffusion = 0.00
    
    # parameters in ranges that will be used in loops
    method_list = [
                   "etks_classic", 
                   "enks-n-primal_classic",
                   "mles-n-transform_classic", 
                   "etks_single_iteration", 
                   "enks-n-primal_single_iteration",
                   "mles-n-transform_single_iteration", 
                   "ienks-transform",
                   "ienks-n-transform",
                   "lin-ienks-transform",
                   "lin-ienks-n-transform",
                  ]
    
    analysis_list = [
                     "fore",
                     "filt",
                     "post"
                    ]

    stat_list = [
                 "rmse",
                 "spread"
                ]
                 

    ensemble_sizes = 15:2:41
    total_ensembles = length(ensemble_sizes)
    inflations = LinRange(1.00, 1.10, 11)
    total_inflations = length(inflations)
    lags = 1:3:91
    total_lags = length(lags)

    # define the storage dictionary here, looping over the method list
    data = Dict{String, Array{Float64}}()
    for method in method_list
        if method[1:6] == "enks-n" || 
            method[1:6] == "mles-n" || 
            method[1:7] == "ienks-n" ||
            method[1:11] == "lin-ienks-n"
                # multiplicative inflation parameter should always be one, there is no dimension for this variable
                for analysis in analysis_list
                    for stat in stat_list
                        data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_lags, total_ensembles)
                    end
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_ensembles)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_ensembles)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_ensembles)
                end
        else
            # create storage for lags, inflations and ensembles
            for analysis in analysis_list
                for stat in stat_list
                    data[method * "_" * analysis * "_" * stat ] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
                end
            end
            if method[1:5] == "ienks"
                # for iterative schemes, additionally store statistics of iterations
                data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
                data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
                data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
            end
        end
    end

    # auxilliary function to process data, producing rmse and spread averages
    function process_data(fnames::Vector{String}, method::String)
        # loop lag, first axis
        for k in 0:total_lags - 1
            # loop ensemble size , last axis
            for j in 0:total_ensembles - 1
                if method[1:6] == "enks-n" || 
                    method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    try
                        # attempt to load the file
                        name = fnames[1+j+k*total_ensembles] 
                        tmp = load(name)
                        
                        # if successful, continue to unpack arrays and store the mean stats over 
                        # the experiment after the burn period for stationary statistics
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - k, 
                                                                           j + 1
                                                                          ] = mean(analysis_stat[burn+1: nanl+burn])
                            end
                        end
                        if method[1:5] == "ienks"
                            # for iterative methods, load the iteration counts for each analysis
                            iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                            
                            # compute the mean and standard deviation of the number of iterations given the configuration
                            data[method * "_iteration_mean"][
                                                             total_lags - k, 
                                                             j + 1
                                                            ] = mean(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - k,
                                                            j + 1
                                                           ] = std(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_median"][
                                                               total_lags - k, 
                                                               j + 1
                                                              ] = median(iter_seq[burn+1: nanl+burn]) 
                        end
                    catch
                        # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                        for analysis in analysis_list
                            for stat in stat_list
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - k, 
                                                                           j + 1
                                                                          ] = Inf 
                            end
                        end
                        if method[1:5] == "ienks"
                            data[method * "_iteration_mean"][
                                                             total_lags - k, 
                                                             j + 1
                                                            ] = Inf 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - k, 
                                                            j + 1
                                                           ] = Inf 
                            
                            data[method * "_iteration_median"][
                                                               total_lags - k, 
                                                               j + 1
                                                              ] = Inf 
                        end
                    end
                else
                    #loop inflation, middle axis
                    for i in 1:total_inflations
                        try
                            # attempt to load the file
                            name = fnames[i + j*total_inflations + k*total_ensembles*total_inflations] 
                            tmp = load(name)
                            
                            # if successful, continue to unpack arrays and store the mean stats over 
                            # the experiment after the burn period for stationary statistics
                            for analysis in analysis_list
                                for stat in stat_list
                                    analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - k, 
                                                                               total_inflations + 1 - i, 
                                                                               j + 1
                                                                              ] = mean(analysis_stat[burn+1: nanl+burn])
                                end
                            end
                            if method[1:5] == "ienks"
                                # for iterative methods, load the iteration counts for each analysis
                                iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                                
                                # compute the mean and standard deviation of the number of iterations given the configuration
                                data[method * "_iteration_mean"][
                                                                 total_lags - k, 
                                                                 total_inflations + 1 - i, 
                                                                 j+1
                                                                ] = mean(iter_seq[burn+1: nanl+burn]) 
                                
                                data[method * "_iteration_std"][
                                                                total_lags - k, 
                                                                total_inflations + 1 - i, 
                                                                j + 1
                                                               ] = std(iter_seq[burn+1: nanl+burn]) 
                                
                                data[method * "_iteration_median"][
                                                                   total_lags - k, 
                                                                   total_inflations + 1 - i, 
                                                                   j + 1
                                                                  ] = median(iter_seq[burn+1: nanl+burn]) 
                            end
                        catch
                            # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                            for analysis in analysis_list
                                for stat in stat_list
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - k, 
                                                                               total_inflations + 1 - i, 
                                                                               j + 1
                                                                              ] = Inf 
                                end
                            end
                            if method[1:5] == "ienks"
                                data[method * "_iteration_mean"][
                                                                 total_lags - k, 
                                                                 total_inflations + 1 - i, 
                                                                 j + 1
                                                                ] = Inf 
                                
                                data[method * "_iteration_std"][
                                                                total_lags - k, 
                                                                total_inflations + 1 - i, 
                                                                j + 1
                                                               ] = Inf 
                                
                                data[method * "_iteration_median"][
                                                                   total_lags - k, 
                                                                   total_inflations + 1 - i, 
                                                                   j + 1
                                                                  ] = Inf 
                            end
                        end
                    end
                end
            end
        end
    end

    # define path to data on server
    fpath = "/x/capa/scratch/cgrudzien/final_experiment_data/all_ens/"
    
    # generate the range of experiments, storing file names as a list
    for method in method_list
        fnames = []
        for lag in lags
            for N_ens in ensemble_sizes
                if method[1:6] == "enks-n" ||
                    method[1:6] == "mles-n" ||
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    
                    # inflation is a static value of 1.0
                    name = method * 
                            "_L96_state_seed_" * lpad(seed, 4, "0") *
                            "_diffusion_" * rpad(diffusion, 4, "0") *
                            "_sys_dim_" * lpad(sys_dim, 2, "0") * 
                            "_obs_dim_" * lpad(obs_dim, 2, "0") * 
                            "_obs_un_" * rpad(obs_un, 4, "0") *
                            "_gamma_" * lpad(γ, 5, "0") *
                            "_nanl_" * lpad(nanl + burn, 5, "0") * 
                            "_tanl_" * rpad(tanl, 4, "0") * 
                            "_h_" * rpad(h, 4, "0") *
                            "_lag_" * lpad(lag, 3, "0") * 
                            "_shift_" * lpad(shift, 3, "0") * 
                            "_mda_" * string(mda) *
                            "_N_ens_" * lpad(N_ens, 3,"0") * 
                            "_state_inflation_" * rpad(round(1.00, digits=2), 4, "0") * 
                            ".jld"

                    push!(fnames, fpath * method * "/" * name)

                elseif method == "etks_classic"
                    # MDA is not defined for the classic smoother, always set this to false
                    # but keep with the MDA true analysis as a reference value
                    # also finite size formalism is incompatible with MDA
                    for infl in inflations
                        # loop inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(seed, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") * 
                                "_obs_dim_" * lpad(obs_dim, 2, "0") * 
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") * 
                                "_tanl_" * rpad(tanl, 4, "0") * 
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") * 
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_false" *
                                "_N_ens_" * lpad(N_ens, 3,"0") * 
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") * 
                                ".jld"
                        
                        push!(fnames, fpath * method * "/" * name)
                    end
                else
                    # loop inflations
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(seed, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") * 
                                "_obs_dim_" * lpad(obs_dim, 2, "0") * 
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") * 
                                "_tanl_" * rpad(tanl, 4, "0") * 
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") * 
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_" * string(mda) *
                                "_N_ens_" * lpad(N_ens, 3,"0") * 
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") * 
                                ".jld"
                        
                        push!(fnames, fpath * method * "/" * name)
                    end
                end
            end
        end
        
        # turn fnames into a string array, use this as the argument in process_data
        fnames = Array{String}(fnames)
        process_data(fnames, method)

    end

    # create jld file name with relevant parameters
    jlname = "processed_smoother_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) * 
             "_shift_" * lpad(shift, 3, "0") * 
             ".jld"

    # create hdf5 file name with relevant parameters
    h5name = "processed_smoother_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) * 
             "_shift_" * lpad(shift, 3, "0") * 
             ".h5"

    # write out file in jld
    save(jlname, data)

    # write out file in hdf5
    h5open(h5name, "w") do file
        for key in keys(data)
            h5write(h5name, key, data[key])
        end
    end
    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################

function process_smoother_param()
    # Create an array of the time-average RMSE and spread for each experiment, past
    # a burn-in period to reach stationary statistics for the experiment.
    # Lag is increasing form the origin on the first axis, inflation is increasing
    # from the origin on the second axis, ensemble size is increasing from the origin
    # on the third axis.
    
    # time the operation
    t1 = time()

    # static parameters that are not varied 
    seed = 0
    tanl = 0.01
    h = 0.01
    obs_un = 0.1
    obs_dim = 20
    γ = 1.0
    sys_dim = 40
    nanl = 10000
    burn = 2000
    shift = 1
    mda = true
    diffusion = 0.012
    param_err = 0.03
    param_wlk = 0.0001
    param_infl = 1.0
    
    # parameters in ranges that will be used in loops
    method_list = [
                   "etks-classic", 
                   "etks-single-iteration",
                   "lin-ienks-transform",
                   "ienks-transform",
                  ]
    
    analysis_list = [
                     "fore",
                     "filt",
                     "post",
                     "param",
                    ]

    stat_list = [
                 "rmse",
                 "spread",
                ]
                 

    ensemble_sizes = 11:2:41
    total_ensembles = length(ensemble_sizes)
    inflations = LinRange(1.00, 1.10, 11)
    total_inflations = length(inflations)
    lags = 1:3:52
    total_lags = length(lags)

    # define the storage dictionary here, looping over the method list
    data = Dict{String, Array{Float64}}()
    for method in method_list
        if method[1:6] == "enks-n" || 
            method[1:6] == "mles-n" || 
            method[1:7] == "ienks-n" ||
            method[1:11] == "lin-ienks-n"
                # multiplicative inflation parameter should always be one, there is no dimension for this variable
                for analysis in analysis_list
                    for stat in stat_list
                        data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_lags, total_ensembles)
                    end
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_ensembles)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_ensembles)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_ensembles)
                end
        else
            # create storage for lags, inflations and ensembles
            for analysis in analysis_list
                for stat in stat_list
                    data[method * "_" * analysis * "_" * stat ] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
                end
            end
            if method[1:5] == "ienks"
                # for iterative schemes, additionally store statistics of iterations
                data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
                data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
                data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_inflations, total_ensembles)
            end
        end
    end

    # auxilliary function to process data, producing rmse and spread averages
    function process_data(fnames::Vector{String}, method::String)
        # loop lag, first axis
        for k in 0:total_lags - 1
            # loop ensemble size , last axis
            for j in 0:total_ensembles - 1
                if method[1:6] == "enks-n" || 
                    method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    try
                        # attempt to load the file
                        name = fnames[1+j+k*total_ensembles] 
                        tmp = load(name)
                        
                        # if successful, continue to unpack arrays and store the mean stats over 
                        # the experiment after the burn period for stationary statistics
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - k, 
                                                                           j + 1
                                                                          ] = mean(analysis_stat[burn+1: nanl+burn])
                            end
                        end
                        if method[1:5] == "ienks"
                            # for iterative methods, load the iteration counts for each analysis
                            iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                            
                            # compute the mean and standard deviation of the number of iterations given the configuration
                            data[method * "_iteration_mean"][
                                                             total_lags - k, 
                                                             j + 1
                                                            ] = mean(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - k,
                                                            j + 1
                                                           ] = std(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_median"][
                                                               total_lags - k, 
                                                               j + 1
                                                              ] = median(iter_seq[burn+1: nanl+burn]) 
                        end
                    catch
                        # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                        for analysis in analysis_list
                            for stat in stat_list
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - k, 
                                                                           j + 1
                                                                          ] = Inf 
                            end
                        end
                        if method[1:5] == "ienks"
                            data[method * "_iteration_mean"][
                                                             total_lags - k, 
                                                             j + 1
                                                            ] = Inf 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - k, 
                                                            j + 1
                                                           ] = Inf 
                            
                            data[method * "_iteration_median"][
                                                               total_lags - k, 
                                                               j + 1
                                                              ] = Inf 
                        end
                    end
                else
                    #loop inflation, middle axis
                    for i in 1:total_inflations
                        try
                            # attempt to load the file
                            name = fnames[i + j*total_inflations + k*total_ensembles*total_inflations] 
                            tmp = load(name)
                            
                            # if successful, continue to unpack arrays and store the mean stats over 
                            # the experiment after the burn period for stationary statistics
                            for analysis in analysis_list
                                for stat in stat_list
                                    analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - k, 
                                                                               total_inflations + 1 - i, 
                                                                               j + 1
                                                                              ] = mean(analysis_stat[burn+1: nanl+burn])
                                end
                            end
                            if method[1:5] == "ienks"
                                # for iterative methods, load the iteration counts for each analysis
                                iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                                
                                # compute the mean and standard deviation of the number of iterations given the configuration
                                data[method * "_iteration_mean"][
                                                                 total_lags - k, 
                                                                 total_inflations + 1 - i, 
                                                                 j+1
                                                                ] = mean(iter_seq[burn+1: nanl+burn]) 
                                
                                data[method * "_iteration_std"][
                                                                total_lags - k, 
                                                                total_inflations + 1 - i, 
                                                                j + 1
                                                               ] = std(iter_seq[burn+1: nanl+burn]) 
                                
                                data[method * "_iteration_median"][
                                                                   total_lags - k, 
                                                                   total_inflations + 1 - i, 
                                                                   j + 1
                                                                  ] = median(iter_seq[burn+1: nanl+burn]) 
                            end
                        catch
                            # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                            for analysis in analysis_list
                                for stat in stat_list
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - k, 
                                                                               total_inflations + 1 - i, 
                                                                               j + 1
                                                                              ] = Inf 
                                end
                            end
                            if method[1:5] == "ienks"
                                data[method * "_iteration_mean"][
                                                                 total_lags - k, 
                                                                 total_inflations + 1 - i, 
                                                                 j + 1
                                                                ] = Inf 
                                
                                data[method * "_iteration_std"][
                                                                total_lags - k, 
                                                                total_inflations + 1 - i, 
                                                                j + 1
                                                               ] = Inf 
                                
                                data[method * "_iteration_median"][
                                                                   total_lags - k, 
                                                                   total_inflations + 1 - i, 
                                                                   j + 1
                                                                  ] = Inf 
                            end
                        end
                    end
                end
            end
        end
    end

    # define path to data on server
    fpath = "/x/capa/scratch/cgrudzien/power_grid_data/"
    
    # generate the range of experiments, storing file names as a list
    for method in method_list
        fnames = []
        for lag in lags
            for N_ens in ensemble_sizes
                if method[1:6] == "enks-n" ||
                    method[1:6] == "mles-n" ||
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    
                    # inflation is a static value of 1.0
                    name = method * 
                            "_IEEE39bus_param_seed_" * lpad(seed, 4, "0") *
                            "_diff_" * rpad(diffusion, 5, "0") *
                            "_sysD_" * lpad(sys_dim, 2, "0") * 
                            "_obsD_" * lpad(obs_dim, 2, "0") * 
                            "_obsU_" * rpad(obs_un, 4, "0") *
                            "_gamma_" * lpad(γ, 5, "0") *
                            "_paramE_" * rpad(param_err, 4, "0") *
                            "_paramW_" * rpad(param_wlk, 6, "0") *
                            "_nanl_" * lpad(nanl + burn, 5, "0") * 
                            "_tanl_" * rpad(tanl, 4, "0") * 
                            "_h_" * rpad(h, 4, "0") *
                            "_lag_" * lpad(lag, 3, "0") * 
                            "_shift_" * lpad(shift, 3, "0") * 
                            "_mda_" * string(mda) *
                            "_nens_" * lpad(N_ens, 3,"0") * 
                            "_stateInfl_" * rpad(round(1.00, digits=2), 4, "0") * 
                            "_paramInfl_" * rpad(round(param_infl, digits=2), 4, "0") *
                            ".jld"

                    push!(fnames, fpath * method * "/" * name)

                elseif method == "etks-classic"
                    # MDA is not defined for the classic smoother, always set this to false
                    # but keep with the MDA true analysis as a reference value
                    # also finite size formalism is incompatible with MDA
                    for infl in inflations
                        # loop inflations
                        name = method * 
                                "_IEEE39bus_param_seed_" * lpad(seed, 4, "0") *
                                "_diff_" * rpad(diffusion, 5, "0") *
                                "_sysD_" * lpad(sys_dim, 2, "0") * 
                                "_obsD_" * lpad(obs_dim, 2, "0") * 
                                "_obsU_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_paramE_" * rpad(param_err, 4, "0") *
                                "_paramW_" * rpad(param_wlk, 6, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") * 
                                "_tanl_" * rpad(tanl, 4, "0") * 
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") * 
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_false" *
                                "_nens_" * lpad(N_ens, 3,"0") * 
                                "_stateInfl_" * rpad(round(infl, digits=2), 4, "0") * 
                                "_paramInfl_" * rpad(round(param_infl, digits=2), 4, "0") *
                                ".jld"
                        
                        push!(fnames, fpath * method * "/" * name)
                    end
                else
                    # loop inflations
                    for infl in inflations
                        name = method * 
                                "_IEEE39bus_param_seed_" * lpad(seed, 4, "0") *
                                "_diff_" * rpad(diffusion, 5, "0") *
                                "_sysD_" * lpad(sys_dim, 2, "0") * 
                                "_obsD_" * lpad(obs_dim, 2, "0") * 
                                "_obsU_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_paramE_" * rpad(param_err, 4, "0") *
                                "_paramW_" * rpad(param_wlk, 6, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") * 
                                "_tanl_" * rpad(tanl, 4, "0") * 
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") * 
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_" * string(mda) *
                                "_nens_" * lpad(N_ens, 3,"0") * 
                                "_stateInfl_" * rpad(round(infl, digits=2), 4, "0") * 
                                "_paramInfl_" * rpad(round(param_infl, digits=2), 4, "0") *
                                ".jld"
                        
                        push!(fnames, fpath * method * "/" * name)
                    end
                end
            end
        end
        # turn fnames into a string array, use this as the argument in process_data
        fnames = Array{String}(fnames)
        process_data(fnames, method)
    end

    # create jld file name with relevant parameters
    jlname = "processed_smoother_param" * 
             "_diffusion_" * rpad(diffusion, 5, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) * 
             "_shift_" * lpad(shift, 3, "0") * 
             "_pwlk_" * rpad(param_wlk, 6, "0") * 
             ".jld"

    # create hdf5 file name with relevant parameters
    h5name = "processed_smoother_param" * 
             "_diffusion_" * rpad(diffusion, 5, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) * 
             "_shift_" * lpad(shift, 3, "0") * 
             "_pwlk_" * rpad(param_wlk, 6, "0") * 
             ".h5"

    # write out file in jld
    save(jlname, data)

    # write out file in hdf5
    h5open(h5name, "w") do file
        for key in keys(data)
            h5write(h5name, key, data[key])
        end
    end
    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################
########################################################################################################################

function process_filter_nonlinear_obs()
    
    # time the operation
    t1 = time()

    # static parameters that are not varied 
    seed = 0
    tanl = 0.05
    h = 0.01
    obs_un = 1.0
    obs_dim = 40
    sys_dim = 40
    nanl = 20000
    burn = 5000
    diffusion = 0.00
    
    # parameters in ranges that will be used in loops
    method_list = [
                   "mlef-transform",
                   "mlef-n-transform",
                   "mlef-ls-transform",
                   "mlef-ls-n-transform"
                  ]
    
    analysis_list = [
                     "fore",
                     "filt",
                    ]

    stat_list = [
                 "rmse",
                 "spread"
                ]
                 
    ensemble_sizes = 15:2:41 
    total_ensembles = length(ensemble_sizes)
    inflations = LinRange(1.00, 1.10, 11)
    total_inflations = length(inflations)
    gammas = Array{Float64}(1:10)
    total_gammas = length(gammas)
    
    # define the storage dictionary here
    data = Dict{String, Array{Float64}}()
    for method in method_list
        if method[1:6] == "mlef-n" || 
            method[1:9] == "mlef-ls-n"
                for analysis in analysis_list
                    for stat in stat_list
                        # multiplicative inflation parameter should always be one, there is no dimension for this variable
                        data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_gammas,  total_ensembles)
                    end
                end
        else
            for analysis in analysis_list
                for stat in stat_list
                    # create storage for inflations and ensembles
                    data[method * "_" * analysis * "_" * stat ] = Array{Float64}(undef, total_gammas, total_inflations, total_ensembles)
                end
            end
        end
    end

    # auxilliary function to process data, producing rmse and spread averages
    function process_data(fnames::Vector{String}, method::String)
        # loop gammas, first axis
        for k in 0:total_gammas - 1
            # loop ensemble size, last axis
            for j in 0:total_ensembles - 1
                if method[1:6] == "mlef-n" || 
                    method[1:9] == "mlef-ls-n"
                    try
                        # attempt to load the file
                        name = fnames[1+j+k*total_ensembles] 
                        tmp = load(name)
                        
                        # if successful, continue to unpack arrays and store the mean stats over 
                        # the experiment after the burn period for stationary statistics
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_gammas - k, 
                                                                           j + 1,
                                                                          ] = mean(analysis_stat[burn+1: nanl+burn])
                            end
                        end
                    catch
                        # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                        for analysis in analysis_list
                            for stat in stat_list
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_gammas - k, 
                                                                           j + 1,
                                                                          ] = Inf 
                            end
                        end
                    end
                else
                    #loop inflation, middle axis
                    for i in 1:total_inflations
                        try
                            # attempt to load the file
                            name = fnames[i + j*total_inflations + k*total_ensembles*total_inflations] 
                            tmp = load(name)
                            
                            # if successful, continue to unpack arrays and store the mean stats over 
                            # the experiment after the burn period for stationary statistics
                            for analysis in analysis_list
                                for stat in stat_list
                                    analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_gammas - k, 
                                                                               total_inflations + 1 - i, 
                                                                               j + 1,
                                                                              ] = mean(analysis_stat[burn+1: nanl+burn])
                                end
                            end
                        catch
                            # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                            for analysis in analysis_list
                                for stat in stat_list
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_gammas - k, 
                                                                               total_inflations + 1 - i, 
                                                                               j + 1
                                                                              ] = Inf 
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    # define path to data on server
    fpath = "/x/capa/scratch/cgrudzien/final_experiment_data/versus_operator/"
    
    # generate the range of experiments, storing file names as a list
    for method in method_list
        fnames = []
        for γ in gammas
            for N_ens in ensemble_sizes
                if method[1:6] == "mlef-n" || 
                    method[1:9] == "mlef-ls-n"
                        name = method * 
                                "_L96_state_seed_" * lpad(seed, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_1.00" *
                                ".jld"

                    push!(fnames, fpath * method * "/" * name)
                else
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(seed, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") *
                                ".jld"
 
                        push!(fnames, fpath * method * "/" * name)
                    end
                end
            end
        end
        
        # turn fnames into a string array, use this as the argument in process_data
        fnames = Array{String}(fnames)
        process_data(fnames, method)
    end

    # create jld file name with relevant parameters
    jlname = "processed_filter_nonlinear_obs_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             ".jld"

    # create hdf5 file name with relevant parameters
    h5name = "processed_filter_nonlinear_obs_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             ".h5"

    # write out file in jld
    save(jlname, data)

    # write out file in hdf5
    h5open(h5name, "w") do file
        for key in keys(data)
            h5write(h5name, key, data[key])
        end
    end
    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################

function process_smoother_nonlinear_obs()
    # Create an array of the time-average RMSE and spread for each experiment, past
    # a burn-in period to reach stationary statistics for the experiment.
    # Lag is increasing form the origin on the first axis, inflation is increasing
    # from the origin on the second axis, gamma is increasing from the origin
    # on the third axis.
    
    # time the operation
    t1 = time()
    
    # static parameters that are not varied 
    seed = 0
    diffusion = 0.0
    tanl = 0.05
    h = 0.01
    obs_un = 1.0
    obs_dim = 40
    sys_dim = 40
    N_ens = 21
    nanl = 20000
    burn = 5000
    diffusion = 0.00
    mda = true
    shift = 1
    
    # parameters in ranges that will be used in loops
    method_list = [
                   "mles-transform_classic",
                   "mles-n-transform_classic",
                   "mles-transform_single_iteration",
                   "mles-n-transform_single_iteration",
                   "ienks-transform",
                   "ienks-n-transform",
                   "lin-ienks-transform",
                   "lin-ienks-n-transform",
                  ]
    
    analysis_list = [
                     "fore",
                     "filt",
                     "post"
                    ]

    stat_list = [
                 "rmse",
                 "spread"
                ]
                 

    gammas = Array{Float64}(0:11)
    total_gammas = length(gammas)
    inflations = LinRange(1.00, 1.10, 11)
    total_inflations = length(inflations)
    lags = 1:3:85
    total_lags = length(lags)
    
    # define the storage dictionary here, looping over the method list
    data = Dict{String, Array{Float64}}()
    for method in method_list
        if method[1:6] == "mles-n" || 
            method[1:7] == "ienks-n" ||
            method[1:11] == "lin-ienks-n"
                # multiplicative inflation parameter should always be one, there is no dimension for this variable
                for analysis in analysis_list
                    for stat in stat_list
                        data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_lags, total_gammas)
                    end
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_gammas)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_gammas)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_gammas)
                end
        else
            for analysis in analysis_list
                for stat in stat_list
                    data[method * "_" * analysis * "_" * stat ] = Array{Float64}(undef, total_lags, total_inflations, total_gammas)
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_inflations, total_gammas)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_inflations, total_gammas)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_inflations, total_gammas)
                end
            end
        end
    end

    # auxilliary function to process data, producing rmse and spread averages
    function process_data(fnames::Vector{String}, method::String)
        # loop gammas, last axis
        for k in 0:total_gammas - 1
            # loop lags, first axis
            for j in 0:total_lags - 1
                if method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    try
                        # attempt to load the file
                        name = fnames[1+j+k*total_lags] 
                        tmp = load(name)
                        
                        # if successful, continue to unpack arrays and store the mean stats over 
                        # the experiment after the burn period for stationary statistics
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - j,
                                                                           k + 1, 
                                                                          ] = mean(analysis_stat[burn+1: nanl+burn])
                            end
                        end
                        if method[1:5] == "ienks"
                            # for iterative methods, load the iteration counts for each analysis
                            iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                            
                            # compute the mean and standard deviation of the number of iterations given the configuration
                            data[method * "_iteration_mean"][
                                                             total_lags - j,
                                                             k + 1, 
                                                            ] = mean(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - j, 
                                                            k + 1
                                                           ] = std(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_median"][
                                                               total_lags - j, 
                                                               k + 1
                                                              ] = median(iter_seq[burn+1: nanl+burn]) 
                            
                        end
                    catch
                        # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                        for analysis in analysis_list
                            for stat in stat_list
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - j, 
                                                                           k + 1, 
                                                                          ] = Inf 
                            end
                        end
                        if method[1:5] == "ienks"
                            data[method * "_iteration_mean"][
                                                             total_lags - j,
                                                             k + 1, 
                                                            ] = Inf
                            
                            data[method * "_iteration_std"][
                                                            total_lags - j, 
                                                            k + 1
                                                           ] = Inf 
                        
                            data[method * "_iteration_median"][
                                                               total_lags - j, 
                                                               k + 1
                                                              ] = Inf 
                        
                        end
                    end
                else
                    #loop inflation, middle axis
                    for i in 1:total_inflations
                        try
                            # attempt to load the file
                            name = fnames[i + j*total_inflations + k*total_lags*total_inflations] 
                            tmp = load(name)
                            
                            # if successful, continue to unpack arrays and store the mean stats over 
                            # the experiment after the burn period for stationary statistics
                            for analysis in analysis_list
                                for stat in stat_list
                                    analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - j,
                                                                               total_inflations + 1 - i,
                                                                               k + 1, 
                                                                              ] = mean(analysis_stat[burn+1: nanl+burn])
                                end
                            end
                            if method[1:5] == "ienks"
                                # for iterative methods, load the iteration counts for each analysis
                                iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                                
                                # compute the mean and standard deviation of the number of iterations given the configuration
                                data[method * "_iteration_mean"][
                                                                 total_lags - j,
                                                                 total_inflations + 1 - i, 
                                                                 k + 1, 
                                                                ] = mean(iter_seq[burn+1: nanl+burn]) 

                                data[method * "_iteration_std"][
                                                                total_lags - j,
                                                                total_inflations + 1 - i, 
                                                                k + 1, 
                                                               ] = std(iter_seq[burn+1: nanl+burn]) 
                            
                                data[method * "_iteration_median"][
                                                                   total_lags - j,
                                                                   total_inflations + 1 - i, 
                                                                   k + 1, 
                                                                  ] = median(iter_seq[burn+1: nanl+burn]) 
                            
                            end
                        catch
                            # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                            for analysis in analysis_list
                                for stat in stat_list
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - j,
                                                                               total_inflations + 1 - i,
                                                                               k + 1, 
                                                                              ] = Inf 
                                end
                            end
                            
                            if method[1:5] == "ienks"
                                data[method * "_iteration_mean"][
                                                                 total_lags - j,
                                                                 total_inflations + 1 - i, 
                                                                 k + 1, 
                                                                ] = Inf 

                                data[method * "_iteration_std"][
                                                                total_lags - j,
                                                                total_inflations + 1 - i, 
                                                                k + 1, 
                                                               ] = Inf 
                            
                                data[method * "_iteration_median"][
                                                                   total_lags - j,
                                                                   total_inflations + 1 - i, 
                                                                   k + 1, 
                                                                  ] = Inf 
                            
                            end
                        end
                    end
                end
            end
        end
    end

    # define path to data on server
    
    # generate the range of experiments, storing file names as a list
    fpath = "/x/capa/scratch/cgrudzien/final_experiment_data/versus_operator/"
    for method in method_list
        fnames = []
        for γ in gammas
            for lag in lags
                if method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    
                    # inflation is a static value of 1.0
                    name = method * 
                        "_L96_state_seed_" * lpad(seed, 4, "0") *
                        "_diffusion_" * rpad(diffusion, 4, "0") *
                        "_sys_dim_" * lpad(sys_dim, 2, "0") *
                        "_obs_dim_" * lpad(obs_dim, 2, "0") *
                        "_obs_un_" * rpad(obs_un, 4, "0") *
                        "_gamma_" * lpad(γ, 5, "0") *
                        "_nanl_" * lpad(nanl + burn, 5, "0") *
                        "_tanl_" * rpad(tanl, 4, "0") *
                        "_h_" * rpad(h, 4, "0") *
                        "_lag_" * lpad(lag, 3, "0") *
                        "_shift_" * lpad(shift, 3, "0") * 
                        "_mda_" * string(mda) *
                        "_N_ens_" * lpad(N_ens, 3,"0") *
                        "_state_inflation_1.00" *
                        ".jld"

                    push!(fnames, fpath * method * "/" * name)

                elseif method[end-6:end] == "classic" 
                    # MDA is not defined for the classic smoother, always set this to false
                    # but keep with the MDA true analysis as a reference value
                    # also finite size formalism is incompatible with MDA
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(0, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") *
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_false" *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") *
                                ".jld"
 
                        push!(fnames, fpath * method * "/" * name)
                    end
                else
                    # loop inflations
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(0, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") *
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_" * string(mda) *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") *
                                ".jld"
 
                        push!(fnames, fpath * method * "/" * name)
                    end
                end
            end
        end
        
        # turn fnames into a string array, use this as the argument in process_data
        fnames = Array{String}(fnames)
        process_data(fnames, method)

    end

    # create jld file name with relevant parameters
    jlname = "processed_smoother_nonlinear_obs_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) *
             "_shift_" * lpad(shift, 3, "0") * 
             ".jld"

    # create hdf5 file name with relevant parameters
    h5name = "processed_smoother_nonlinear_obs_state" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) * 
             "_shift_" * lpad(shift, 3, "0") * 
             ".h5"

    # write out file in jld
    save(jlname, data)

    # write out file in hdf5
    h5open(h5name, "w") do file
        for key in keys(data)
            h5write(h5name, key, data[key])
        end
    end
    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################

function process_smoother_versus_tanl()
    # Create an array of the time-average RMSE and spread for each experiment, past
    # a burn-in period to reach stationary statistics for the experiment.
    # Lag is increasing form the origin on the first axis, inflation is increasing
    # from the origin on the second axis, tanl is increasing from the origin
    # on the third axis.
    
    # time the operation
    t1 = time()
    
    # static parameters that are not varied 
    seed = 0
    diffusion = 0.0
    h = 0.01
    obs_un = 1.0
    obs_dim = 40
    sys_dim = 40
    N_ens = 21
    nanl = 20000
    burn = 5000
    diffusion = 0.00
    mda = true
    shift = 1
    γ = 1.0
    
    # parameters in ranges that will be used in loops
    method_list = [
                   "etks_classic",
                   "enks-n-primal_classic",
                   "mles-n-transform_classic",
                   "etks_single_iteration",
                   "enks-n-primal_single_iteration",
                   "mles-n-transform_single_iteration",
                   "ienks-transform",
                   "ienks-n-transform",
                   "lin-ienks-transform",
                   "lin-ienks-n-transform",
                  ]
    
    analysis_list = [
                     "fore",
                     "filt",
                     "post"
                    ]

    stat_list = [
                 "rmse",
                 "spread"
                ]
                 

    tanls = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50]
    total_tanls = length(tanls)
    inflations = LinRange(1.00, 1.10, 11)
    total_inflations = length(inflations)
    lags = 1:3:52
    total_lags = length(lags)
    
    # define the storage dictionary here, looping over the method list
    data = Dict{String, Array{Float64}}()
    for method in method_list
        if method[1:6] == "enks-n" || 
            method[1:6] == "mles-n" || 
            method[1:7] == "ienks-n" ||
            method[1:11] == "lin-ienks-n"
                # multiplicative inflation parameter should always be one, there is no dimension for this variable
                for analysis in analysis_list
                    for stat in stat_list
                        data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_lags, total_tanls)
                    end
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_tanls)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_tanls)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_tanls)
                end
        else
            for analysis in analysis_list
                for stat in stat_list
                    data[method * "_" * analysis * "_" * stat ] = Array{Float64}(undef, total_lags, total_inflations, total_tanls)
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_inflations, total_tanls)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_inflations, total_tanls)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_inflations, total_tanls)
                end
            end
        end
    end

    # auxilliary function to process data, producing rmse and spread averages
    function process_data(fnames::Vector{String}, method::String)
        # loop tanls, last axis
        for k in 0:total_tanls - 1
            # loop lags, first axis
            for j in 0:total_lags - 1
                if method[1:6] == "enks-n" || 
                    method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    try
                        # attempt to load the file
                        name = fnames[1+j+k*total_lags] 
                        tmp = load(name)
                        
                        # if successful, continue to unpack arrays and store the mean stats over 
                        # the experiment after the burn period for stationary statistics
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - j,
                                                                           k + 1, 
                                                                          ] = mean(analysis_stat[burn+1: nanl+burn])
                            end
                        end
                        if method[1:5] == "ienks"
                            # for iterative methods, load the iteration counts for each analysis
                            iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                            
                            # compute the mean and standard deviation of the number of iterations given the configuration
                            data[method * "_iteration_mean"][
                                                             total_lags - j,
                                                             k + 1, 
                                                            ] = mean(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - j, 
                                                            k + 1
                                                           ] = std(iter_seq[burn+1: nanl+burn]) 
                            
                            data[method * "_iteration_median"][
                                                               total_lags - j, 
                                                               k + 1
                                                              ] = std(iter_seq[burn+1: nanl+burn]) 
                            
                        end
                    catch
                        # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                        for analysis in analysis_list
                            for stat in stat_list
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - j, 
                                                                           k + 1, 
                                                                          ] = Inf 
                            end
                        end
                        if method[1:5] == "ienks"
                            data[method * "_iteration_mean"][
                                                             total_lags - j,
                                                             k + 1, 
                                                            ] = Inf
                            
                            data[method * "_iteration_std"][
                                                            total_lags - j, 
                                                            k + 1
                                                           ] = Inf 
                        
                            data[method * "_iteration_median"][
                                                               total_lags - j, 
                                                               k + 1
                                                              ] = Inf 
                        
                        end
                    end
                else
                    #loop inflation, middle axis
                    for i in 1:total_inflations
                        try
                            # attempt to load the file
                            name = fnames[i + j*total_inflations + k*total_lags*total_inflations] 
                            tmp = load(name)
                            
                            # if successful, continue to unpack arrays and store the mean stats over 
                            # the experiment after the burn period for stationary statistics
                            for analysis in analysis_list
                                for stat in stat_list
                                    analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - j,
                                                                               total_inflations + 1 - i,
                                                                               k + 1, 
                                                                              ] = mean(analysis_stat[burn+1: nanl+burn])
                                end
                            end
                            if method[1:5] == "ienks"
                                # for iterative methods, load the iteration counts for each analysis
                                iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                                
                                # compute the mean and standard deviation of the number of iterations given the configuration
                                data[method * "_iteration_mean"][
                                                                 total_lags - j,
                                                                 total_inflations + 1 - i, 
                                                                 k + 1, 
                                                                ] = mean(iter_seq[burn+1: nanl+burn]) 

                                data[method * "_iteration_std"][
                                                                total_lags - j,
                                                                total_inflations + 1 - i, 
                                                                k + 1, 
                                                               ] = std(iter_seq[burn+1: nanl+burn]) 
                                
                                data[method * "_iteration_median"][
                                                                   total_lags - j,
                                                                   total_inflations + 1 - i, 
                                                                   k + 1, 
                                                                  ] = std(iter_seq[burn+1: nanl+burn]) 
                            end
                        catch
                            # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                            for analysis in analysis_list
                                for stat in stat_list
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - j,
                                                                               total_inflations + 1 - i,
                                                                               k + 1, 
                                                                              ] = Inf 
                                end
                            end
                            
                            if method[1:5] == "ienks"
                                data[method * "_iteration_mean"][
                                                                 total_lags - j,
                                                                 total_inflations + 1 - i, 
                                                                 k + 1, 
                                                                ] = Inf 

                                data[method * "_iteration_std"][
                                                                total_lags - j,
                                                                total_inflations + 1 - i, 
                                                                k + 1, 
                                                               ] = Inf 
                                
                                data[method * "_iteration_median"][
                                                                   total_lags - j,
                                                                   total_inflations + 1 - i, 
                                                                   k + 1, 
                                                                  ] = Inf 
                            end
                        end
                    end
                end
            end
        end
    end

    # define path to data on server
    
    # generate the range of experiments, storing file names as a list
    fpath = "/x/capa/scratch/cgrudzien/final_experiment_data/versus_tanl/"
    for method in method_list
        fnames = []
        for tanl in tanls
            for lag in lags
                if method[1:6] == "enks-n" || 
                    method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    
                    # inflation is a static value of 1.0
                    name = method * 
                        "_L96_state_seed_" * lpad(seed, 4, "0") *
                        "_diffusion_" * rpad(diffusion, 4, "0") *
                        "_sys_dim_" * lpad(sys_dim, 2, "0") *
                        "_obs_dim_" * lpad(obs_dim, 2, "0") *
                        "_obs_un_" * rpad(obs_un, 4, "0") *
                        "_gamma_" * lpad(γ, 5, "0") *
                        "_nanl_" * lpad(nanl + burn, 5, "0") *
                        "_tanl_" * rpad(tanl, 4, "0") *
                        "_h_" * rpad(h, 4, "0") *
                        "_lag_" * lpad(lag, 3, "0") *
                        "_shift_" * lpad(shift, 3, "0") * 
                        "_mda_" * string(mda) *
                        "_N_ens_" * lpad(N_ens, 3,"0") *
                        "_state_inflation_1.00" *
                        ".jld"

                    push!(fnames, fpath * method * "/" * name)

                elseif method[end-6:end] == "classic" 
                    # MDA is not defined for the classic smoother, always set this to false
                    # but keep with the MDA true analysis as a reference value
                    # also finite size formalism is incompatible with MDA
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(0, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") *
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_false" *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") *
                                ".jld"
 
                        push!(fnames, fpath * method * "/" * name)
                    end
                else
                    # loop inflations
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(0, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") *
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_" * string(mda) *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") *
                                ".jld"
 
                        push!(fnames, fpath * method * "/" * name)
                    end
                end
            end
        end
        
        # turn fnames into a string array, use this as the argument in process_data
        fnames = Array{String}(fnames)
        process_data(fnames, method)

    end

    # create jld file name with relevant parameters
    jlname = "processed_smoother_state_versus_tanl" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) *
             "_shift_" * lpad(shift, 3, "0") * 
             ".jld"

    # create hdf5 file name with relevant parameters
    h5name = "processed_smoother_state_versus_tanl" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) * 
             "_shift_" * lpad(shift, 3, "0") * 
             ".h5"

    # write out file in jld
    save(jlname, data)

    # write out file in hdf5
    h5open(h5name, "w") do file
        for key in keys(data)
            h5write(h5name, key, data[key])
        end
    end
    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################

function process_smoother_versus_shift()
    # Create an array of the time-average RMSE and spread for each experiment, past
    # a burn-in period to reach stationary statistics for the experiment.
    # Lag is increasing form the origin on the first axis, inflation is increasing
    # from the origin on the second axis, shift is increasing from the origin
    # on the third axis.
    
    # time the operation
    t1 = time()

    # static parameters that are not varied 
    seed = 0
    diffusion = 0.0
    tanl = 0.05
    h = 0.01
    obs_un = 1.0
    obs_dim = 40
    sys_dim = 40
    N_ens = 21
    nanl = 20000
    burn = 5000
    diffusion = 0.00
    mda = true
    γ = 1.0
    
    # parameters in ranges that will be used in loops
    method_list = [
                   "etks_classic",
                   "enks-n-primal_classic",
                   "mles-n-transform_classic",
                   "etks_single_iteration",
                   "enks-n-primal_single_iteration",
                   "mles-n-transform_single_iteration",
                   "ienks-transform",
                   "ienks-n-transform",
                   "lin-ienks-transform",
                   "lin-ienks-n-transform",
                  ]
    
    analysis_list = [
                     "fore",
                     "filt",
                     "post"
                    ]

    stat_list = [
                 "rmse",
                 "spread"
                ]
                 

    inflations = LinRange(1.00, 1.10, 11)
    total_inflations = length(inflations)
    lags = [1, 2, 4, 8, 16, 32, 48, 64, 80, 96]
    total_lags = length(lags)
    #shifts = copy(lags)
    shifts = [1, 2, 4, 8, 16, 32, 48, 64, 80, 96]
    total_shifts = length(shifts)

    # define the storage dictionary here, looping over the method list
    data = Dict{String, Array{Float64}}()
    for method in method_list
        if method[1:6] == "enks-n" || 
            method[1:6] == "mles-n" || 
            method[1:7] == "ienks-n" ||
            method[1:11] == "lin-ienks-n"
                # multiplicative inflation parameter should always be one, there is no dimension for this variable
                for analysis in analysis_list
                    for stat in stat_list
                        data[method * "_" * analysis * "_" * stat] = Array{Float64}(undef, total_lags, total_shifts)
                    end
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef, total_lags, total_shifts)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_shifts)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_shifts)
                end
        else
            for analysis in analysis_list
                for stat in stat_list
                    data[method * "_" * analysis * "_" * stat ] = Array{Float64}(undef, total_lags, total_inflations, total_shifts)
                end
                if method[1:5] == "ienks"
                    # for iterative schemes, additionally store statistics of iterations
                    data[method * "_iteration_mean"] = Array{Float64}(undef,  total_lags, total_inflations, total_shifts)
                    data[method * "_iteration_std"] = Array{Float64}(undef, total_lags, total_inflations, total_shifts)
                    data[method * "_iteration_median"] = Array{Float64}(undef, total_lags, total_inflations, total_shifts)
                end
            end
        end
    end

    # auxilliary function to process data, producing rmse and spread averages
    function process_data(fnames::Vector{String}, method::String)
        # loop shifts, last axis
        for k in 0:total_shifts - 1
            # loop lags, first axis
            for j in 0:total_lags - 1
                if method[1:6] == "enks-n" || 
                    method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    try
                        # attempt to load the file
                        name = fnames[1+j+k*total_lags] 
                        tmp = load(name)
                        
                        # if successful, continue to unpack arrays and store the mean stats over 
                        # the experiment after the burn period for stationary statistics
                        for analysis in analysis_list
                            for stat in stat_list
                                analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - j,
                                                                           k + 1, 
                                                                          ] = mean(analysis_stat[burn+1: nanl+burn])
                            end
                        end
                        if method[1:5] == "ienks"
                            # for iterative methods, load the iteration counts for each analysis
                            iter_seq = tmp["iteration_sequence"]::Vector{Float64}

                            # for shift > 1, calculate a different burn value for the missmatch between the number of observations
                            # and the number of analyses
                            iter_burn = convert(Int64, round(burn / (shifts[k + 1])) )
                            
                            # compute the mean and standard deviation of the number of iterations given the configuration
                            data[method * "_iteration_mean"][
                                                             total_lags - j,
                                                             k + 1, 
                                                            ] = mean(iter_seq[iter_burn+1: end]) 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - j,
                                                            k + 1,
                                                           ] = std(iter_seq[iter_burn+1: end]) 
                       
                            data[method * "_iteration_median"][
                                                               total_lags - j,
                                                               k + 1,
                                                              ] = median(iter_seq[iter_burn+1: end]) 
                       
                        end
                    catch
                        # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                        for analysis in analysis_list
                            for stat in stat_list
                                data[method * "_" * analysis * "_" * stat][
                                                                           total_lags - j,
                                                                           k + 1,
                                                                          ] = Inf 
                            end
                        end
                        if method[1:5] == "ienks"
                            data[method * "_iteration_mean"][
                                                             total_lags - j,
                                                             k + 1, 
                                                            ] = Inf 
                            
                            data[method * "_iteration_std"][
                                                            total_lags - j,
                                                            k + 1,
                                                           ] = Inf 
                            
                            data[method * "_iteration_median"][
                                                               total_lags - j,
                                                               k + 1,
                                                              ] = Inf 
                        end
                    end
                else
                    #loop inflation, middle axis
                    for i in 1:total_inflations
                        try
                            # attempt to load the file
                            name = fnames[i + j*total_inflations + k*total_lags*total_inflations] 
                            tmp = load(name)
                            
                            # if successful, continue to unpack arrays and store the mean stats over 
                            # the experiment after the burn period for stationary statistics
                            for analysis in analysis_list
                                for stat in stat_list
                                    analysis_stat = tmp[analysis * "_" * stat]::Vector{Float64}
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - j,
                                                                               total_inflations + 1 - i,
                                                                               k + 1,
                                                                              ] = mean(analysis_stat[burn+1: nanl+burn])
                                end
                            end
                            if method[1:5] == "ienks"
                                # for iterative methods, load the iteration counts for each analysis
                                iter_seq = tmp["iteration_sequence"]::Vector{Float64}
                                
                                # for shift > 1, calculate a different burn value for the missmatch between the number of observations
                                # and the number of analyses
                                iter_burn = convert(Int64, round(burn / (shifts[k + 1])) )

                                # compute the mean and standard deviation of the number of iterations given the configuration
                                data[method * "_iteration_mean"][
                                                                 total_lags - j,
                                                                 total_inflations + 1 - i, 
                                                                 k + 1,
                                                                ] = mean(iter_seq[iter_burn+1: end]) 

                                data[method * "_iteration_std"][
                                                                total_lags - j,
                                                                total_inflations + 1 - i, 
                                                                k + 1, 
                                                               ] = std(iter_seq[iter_burn+1: end]) 
                            
                                data[method * "_iteration_median"][
                                                                   total_lags - j,
                                                                   total_inflations + 1 - i, 
                                                                   k + 1, 
                                                                  ] = median(iter_seq[iter_burn+1: end]) 
                            
                            end
                        catch
                            # file is missing or corrupted, load infinity to represent an incomplete or unstable experiment
                            for analysis in analysis_list
                                for stat in stat_list
                                    data[method * "_" * analysis * "_" * stat][
                                                                               total_lags - j,
                                                                               total_inflations + 1 - i,
                                                                               k + 1,
                                                                              ] = Inf 
                                end
                            end
                            if method[1:5] == "ienks"
                                data[method * "_iteration_mean"][
                                                                 total_lags - j,
                                                                 total_inflations + 1 - i, 
                                                                 k + 1,
                                                                ] = Inf 

                                data[method * "_iteration_std"][
                                                                total_lags - j,
                                                                total_inflations + 1 - i, 
                                                                k + 1, 
                                                               ] = Inf 
                            
                                data[method * "_iteration_median"][
                                                                   total_lags - j,
                                                                   total_inflations + 1 - i, 
                                                                   k + 1, 
                                                                  ] = Inf 
                            
                            end
                        end
                    end
                end
            end
        end
    end

    # define path to data on server
    
    # generate the range of experiments, storing file names as a list
    fpath = "/x/capa/scratch/cgrudzien/final_experiment_data/versus_shift/"
    for method in method_list
        fnames = []
        for shift in shifts
            for lag in lags
                if method[1:6] == "enks-n" || 
                    method[1:6] == "mles-n" || 
                    method[1:7] == "ienks-n" ||
                    method[1:11] == "lin-ienks-n"
                    
                    # inflation is a static value of 1.0
                    name = method * 
                        "_L96_state_seed_" * lpad(seed, 4, "0") *
                        "_diffusion_" * rpad(diffusion, 4, "0") *
                        "_sys_dim_" * lpad(sys_dim, 2, "0") *
                        "_obs_dim_" * lpad(obs_dim, 2, "0") *
                        "_obs_un_" * rpad(obs_un, 4, "0") *
                        "_gamma_" * lpad(γ, 5, "0") *
                        "_nanl_" * lpad(nanl + burn, 5, "0") *
                        "_tanl_" * rpad(tanl, 4, "0") *
                        "_h_" * rpad(h, 4, "0") *
                        "_lag_" * lpad(lag, 3, "0") *
                        "_shift_" * lpad(shift, 3, "0") * 
                        "_mda_" * string(mda) *
                        "_N_ens_" * lpad(N_ens, 3,"0") *
                        "_state_inflation_1.00" *
                        ".jld"

                    push!(fnames, fpath * method * "/" * name)

                elseif method[end-6:end] == "classic" 
                    # MDA is not defined for the classic smoother, always set this to false
                    # but keep with the MDA true analysis as a reference value
                    # also finite size formalism is incompatible with MDA
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(0, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") *
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_false" *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") *
                                ".jld"
 
                        push!(fnames, fpath * method * "/" * name)
                    end
                else
                    # loop inflations
                    for infl in inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(0, 4, "0") *
                                "_diffusion_" * rpad(diffusion, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") *
                                "_obs_dim_" * lpad(obs_dim, 2, "0") *
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_gamma_" * lpad(γ, 5, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") *
                                "_tanl_" * rpad(tanl, 4, "0") *
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") *
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_" * string(mda) *
                                "_N_ens_" * lpad(N_ens, 3,"0") *
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") *
                                ".jld"
 
                        push!(fnames, fpath * method * "/" * name)
                    end
                end
            end
        end
        
        # turn fnames into a string array, use this as the argument in process_data
        fnames = Array{String}(fnames)
        process_data(fnames, method)

    end

    # create jld file name with relevant parameters
    jlname = "processed_smoother_state_v_shift" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) *
             ".jld"

    # create hdf5 file name with relevant parameters
    h5name = "processed_smoother_state_v_shift" * 
             "_diffusion_" * rpad(diffusion, 4, "0") *
             "_tanl_" * rpad(tanl, 4, "0") * 
             "_nanl_" * lpad(nanl, 5, "0") * 
             "_burn_" * lpad(burn, 5, "0") * 
             "_mda_" * string(mda) * 
             ".h5"

    # write out file in jld
    save(jlname, data)

    # write out file in hdf5
    h5open(h5name, "w") do file
        for key in keys(data)
            h5write(h5name, key, data[key])
        end
    end
    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################

function rename_data_smoother_state()
    # old script with some basic utilities to load, revise and save data back in place
    # not actively maintained, just adjusted as needed
    t1 = time()
    tanl = 0.05
    h = 0.01
    obs_un = 1.0
    obs_dim = 40
    sys_dim = 40
    nanl = 20000
    burn = 5000
    shift = 1
    mda = false
    diffusion = 0.00
    method_list = [
                   "ienks-transform",
                   "ienks-n-transform",
                  ]
    
    stat_list = [
                 "rmse",
                 "spread"
                ]
                 

    ensemble_sizes = 15:2:41 
    total_ensembles = length(ensemble_sizes)
    total_inflations = LinRange(1.00, 1.10, 11)
    total_inflation = length(total_inflations)
    total_lags = 1:3:52
    total_lag = length(total_lags)

    # auxilliary function to process data
    function process_data(fnames::Vector{String}, method::String)
        # loop lag
        for k in 0:total_lag - 1
            # loop ensemble size 
            for j in 0:total_ensembles - 1
                if method == "enks-n_single_iteration" || 
                    method == "enks-n_classic" ||
                    method == "etks_adaptive_single_iteration" ||
                    method == "ienks-n-bundle" || 
                    method == "ienks-n-transform"
                    name = fnames[1+j+k*total_ensembles]
                    try
                        # attempt to load the file
                        tmp = load(name)
                        for stat in stat_list
                            tmp["iteration_sequence"] = tmp["iteration_sequence"] + 1.0
                        end
                        save(name, tmp)
                    catch
                        print("error on " * name * "\n")
                    end
                else
                    #loop inflation
                    for i in 1:total_inflation
                        name = fnames[i + j*total_inflation + k*total_ensembles*total_inflation]
                        try
                            # attempt to load the file
                            tmp = load(name)
                            for stat in stat_list
                                tmp["iteration_sequence"] = tmp["iteration_sequence"] + 1.0
                            end
                            save(name, tmp)
                        catch
                            print("error on " * name * "\n")
                        end
                    end
                end
            end
        end
    end

    # for each DA method in the experiment, process the data, loading into the dictionary
    fpath = "/x/capc/cgrudzien/DataAssimilationBenchmarks/storage/smoother_state/"
    for method in method_list
        fnames = []
        for lag in total_lags
            for N_ens in ensemble_sizes
                if method == "enks-n_classic" ||
                    method == "enks-n_single_iteration" ||
                    method == "ienks-n-bundle" ||
                    method == "ienks-n-transform" ||
                    method == "etks_adaptive_single_iteration"
                        name = method * 
                                "_L96_state_seed_" * lpad(seed, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") * 
                                "_obs_dim_" * lpad(obs_dim, 2, "0") * 
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") * 
                                "_tanl_" * rpad(tanl, 4, "0") * 
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") * 
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_" * string(mda) *
                                "_N_ens_" * lpad(N_ens, 3,"0") * 
                                "_state_inflation_" * rpad(round(1.00, digits=2), 4, "0") * 
                                ".jld"

                    push!(fnames, fpath * method * "/diffusion_" * rpad(diffusion, 4, "0") * "/" * name)
                else
                    for infl in total_inflations
                        name = method * 
                                "_L96_state_seed_" * lpad(seed, 4, "0") *
                                "_sys_dim_" * lpad(sys_dim, 2, "0") * 
                                "_obs_dim_" * lpad(obs_dim, 2, "0") * 
                                "_obs_un_" * rpad(obs_un, 4, "0") *
                                "_nanl_" * lpad(nanl + burn, 5, "0") * 
                                "_tanl_" * rpad(tanl, 4, "0") * 
                                "_h_" * rpad(h, 4, "0") *
                                "_lag_" * lpad(lag, 3, "0") * 
                                "_shift_" * lpad(shift, 3, "0") * 
                                "_mda_" * string(mda) *
                                "_N_ens_" * lpad(N_ens, 3,"0") * 
                                "_state_inflation_" * rpad(round(infl, digits=2), 4, "0") * 
                                ".jld"
                        
                        push!(fnames, fpath * method * "/diffusion_" * rpad(diffusion, 4, "0") * "/" * name)
                    end
                end
            end
        end
        fnames = Array{String}(fnames)
        process_data(fnames, method)
    end

    print("Runtime " * string(round((time() - t1)  / 60.0, digits=4))  * " minutes\n")
end


########################################################################################################################
#process_smoother_state()
process_smoother_param()
#process_smoother_nonlinear_obs()
#process_smoother_versus_shift()
#process_smoother_versus_tanl()

end
