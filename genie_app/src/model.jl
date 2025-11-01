
function model_parameter(
    smoothing::Number,
    rexl::String,
    rexu::String,
    smoothing_range = (1.0, 10.0),
    )
    #
    s0 = smoothing_range[1]
    s1 = smoothing_range[2]
    f(s) = 10.0^(0.5 * (s - s0))
    alpha = f(smoothing) / f(s1)
    #
    param = OptionSmile.ModelParameter{Float64, String}(
        NaN,
        NaN,
        NaN,
        OptionSmile.p2.ds_relative,
        rexl,
        rexu,
        alpha,
        OptionSmile.p2.autodiff,
        OptionSmile.p2.maxIter,
    )
    return param
end
