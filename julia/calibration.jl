
using LsqFit

function calibration_objective(x, p, strikes, b76_volatilities, α)
    @assert length(strikes) == length(b76_volatilities)
    m = model(x, p)
    σ_model = [
        pvm.lognormal_volatility(m, strike)
        for strike in strikes
    ]
    F_vols = (σ_model .- b76_volatilities) ./ p.σ_b76
    if α > 0.0
        n_ds = length(p.ds_relative)
        x_l = @view x[ begin + 2        : begin + n_ds ]  # (n_ds-1) elements, skipping first/second
        x_u = @view x[ begin + n_ds + 2 : end          ]  # skip one element
        F_x = vcat(x_l, x_u)
        #
        # ensure α acts independent of number of inputs/outputs
        F_vols = (1.0/max(1, length(F_vols))) .* F_vols
        F_x = (1.0/max(1, length(F_x))) .* F_x
        # apply convex combination
        F_vols = vcat((1.0-α) .* F_vols, α .* F_x)
    end
    return F_vols
end

function calibrated_model(
    p::ModelParameter,
    strikes::AbstractVector,
    b76_volatilities::AbstractVector;
    α = 0.0,
    lmfit_kwargs = (
        autodiff = :forwarddiff,
        maxIter  = 10
    ),
    )
    #
    F(x) = calibration_objective(x, p, strikes, b76_volatilities, α)
    x0 = initial_values(p)
    y0 = F(x0)
    res = LsqFit.lmfit(
        F,
        x0,
        eltype(y0)[];
        lmfit_kwargs...
    )
    #
    m = model(res.param, p)
    return (model = m, result = res)
end
