
using Dates
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
    b76_volatilities::AbstractVector,
    )
    #
    F(x) = calibration_objective(x, p, strikes, b76_volatilities, p.alpha)
    x0 = initial_values(p)
    y0 = F(x0)
    lmfit_kwargs = (
        autodiff = p.autodiff,
        maxIter  = p.maxIter
    )
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


function interpolate(x_vec::AbstractVector, y_vec::AbstractVector, x_val)
    @assert length(x_vec) == length(y_vec)
    n = length(x_vec)
    idx1 = searchsortedfirst(x_vec, x_val)
    idx0 = idx1 - 1
    idx0 = min(max(idx0, 1), n)
    idx1 = min(max(idx1, 1), n)
    if idx1 == idx0
        return y_vec[idx0]
    else
        ρ = (x_val - x_vec[idx0]) / (x_vec[idx1] - x_vec[idx0])
        y_val = ρ * y_vec[idx1] + (1-ρ) * y_vec[idx0]
        return y_val
    end
end


actual365fixed(d1::Date, d2::Date) = (d2 - d1) / Day(1) / 365.0


function calibrated_model(
    df::DataFrame,
    p::ModelParameter,
    )
    float_type = Float64  # we may opt to use other types
    expiry = unique(df.expiration)
    @assert length(expiry) == 1 "length(expiry): $(length(expiry))"
    expiry = expiry[begin]
    date = df.date[begin]
    forward = float_type(df.price[begin])
    T = float_type(actual365fixed(date, expiry))
    strikes = Vector{float_type}(df.strike)
    vols = Vector{float_type}(df.mid)
    σ_b76 = interpolate(strikes, vols, forward)
    p_ = ModelParameter(σ_b76, forward, T, p.ds_relative, p.rexl, p.rexu, p.alpha, p.autodiff, p.maxIter)
    #
    return calibrated_model(p_, strikes, vols)
end


function calibrated_models(
    df::DataFrame,
    p::ModelParameter,
    )
    expiries = unique(df.expiration)
    models = []
    for expiry in expiries
        df2 = df[df.expiration.==expiry, :]
        try
            res = calibrated_model(df2, p)
            # maybe better check convergence here...
            push!(models, res.model)
        catch
            push!(models, nothing)
        end
    end
    return models
end
