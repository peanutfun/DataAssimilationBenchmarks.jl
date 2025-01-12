# Analysis

## Processing experiment outputs

The `analysis` directory contains scripts for batch processing the outputs from experiments into time-averaged
RMSE and spread and arranging these outputs in an array for plotting.  This should be modified based on the
local paths to stored data.  This will try to load files based on parameter settings written in the name of
the output .jld2 file and if this is not available, this will store `Inf` values in the place of missing data.

## Validating results
Benchmark configurations for the above filtering and smoothing experiments are available in the open access article
[Grudzien et al. 2022](https://gmd.copernicus.org/articles/15/7641/2022/gmd-15-7641-2022.html),
with details on the algorithm and parameter specifications discussed in the experiments section.  Performance of filtering and
smoothing schemes should be validated versus the numerical results for root mean square error and ensemble spread.
Simple versions of these diagnostics are built for automatic testing of the filter and smoother experiments for state and parameter estimation
in the L96-s model.  Further test cases are currently in development.  The deterministic Runge-Kutta and Euler scheme for ODEs are
validated in the package tests, estimating the order of convergence with the least-squares log-10 line fit between step size
and discretization error.  Test cases for the stochastic integration schemes are in development, but numerical results with these
schemes can be validated versus the results in the open-access article 
[Grudzien et al. 2020](https://gmd.copernicus.org/articles/13/1903/2020/).

