
struct ModelParameter{FloatType, StringType}
    σ_b76::FloatType
    forward::FloatType
    T::FloatType
    ds_relative::Vector{FloatType}
    rexl::StringType
    rexu::StringType
    alpha::FloatType
    autodiff::Symbol
    maxIter::Int
end


function model_inputs(x::AbstractVector)
    @assert length(x) ≥ 3  # atm vol parameter and at least two smile param's
    @assert length(x) % 2 == 1
    n_slope = (length(x) - 1) ÷ 2
    σ_atm = exp(x[begin])
    slope_lo = x[begin+1:begin+n_slope]
    slope_up = x[begin+n_slope+1:end]
    return (σ_atm = σ_atm, slope_lo = slope_lo, slope_up = slope_up)
end


function initial_values(σ_b76, forward, T, n_slope)
    @assert n_slope ≥ 1
    σ_atm = pvm.normal_volatility(σ_b76, forward, forward, T)
    slope_lo = zeros(n_slope)
    slope_up = zeros(n_slope)
    slope_lo[begin] = -σ_b76
    slope_up[begin] = σ_b76
    x = vcat(
        log(σ_atm),
        slope_lo,
        slope_up,
    )
    return x
end


function initial_values(p::ModelParameter)
    return initial_values(p.σ_b76, p.forward, p.T, length(p.ds_relative))
end


function model(x::AbstractVector, p::ModelParameter)
    (σ_atm, slope_lo, slope_up) = model_inputs(x)
    @assert length(slope_lo) == length(p.ds_relative) "slope_lo: $(length(slope_lo)), ds_relative: $(length(p.ds_relative))."
    @assert length(slope_up) == length(p.ds_relative) "slope_lo: $(length(slope_up)), ds_relative: $(length(p.ds_relative))."
    #
    ds = p.forward .* p.ds_relative
    #
    m = pvm.calibrated_model_from_slopes(
        p.forward,
        σ_atm,
        p.T,
        ds,
        ds,
        slope_lo,
        slope_up,
        p.rexl,
        p.rexu,
    )
    return m
end
