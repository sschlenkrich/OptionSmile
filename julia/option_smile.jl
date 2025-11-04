
using CSV
using DataFrames
using Dates
using LsqFit
using MySQL
using Printf
using StatsPlots

using PiecewiseVanillaModel
pvm = PiecewiseVanillaModel  # alias



include("data.jl")
include("model.jl")
include("calibration.jl")
include("smile_plot.jl")
include("stock_plot.jl")
include("store_data.jl")

conn = connection()

conn_options = connection("options")
conn_stocks = connection("stocks")
conn_rates = connection("rates")

p1 = ModelParameter(
    NaN,
    NaN,
    NaN,
    [1, 2, 3, 5, 7, 10, 15, 20, 25, 30] .* 1.0e-2,
    "LOGNORMAL",
    "NOTHING",
    1.0e-1,
    :forwarddiff,
    10
)

p2 = ModelParameter(
    NaN,
    NaN,
    NaN,
    [1, 2, 3, 5, 7, 10, 15, 20, 25, 30] .* 1.0e-2,
    "LOGNORMAL",
    "NOTHING",
    1.0e-2,
    :forwarddiff,
    10
)

;
