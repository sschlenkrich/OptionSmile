
include("data.jl")
include("model.jl")
include("calibration.jl")
include("smile_plot.jl")
include("store_data.jl")

conn = connection()

p = ModelParameter(
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

