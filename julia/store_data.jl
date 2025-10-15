

function store_model(
    conn,
    date,
    act_symbol::String,
    expiration,
    model::pvm.Model,
    param::ModelParameter,
    α::Number,
    )
    #
    date = Date(date)
    expiration = Date(expiration)
    expiry_time = model.T
    price = model.s0
    normal_volatility = pvm.normal_volatility(model, model.s0)
    log_volatility = pvm.lognormal_volatility(model, model.s0)
    #
    dsl_relative = round.(model.dsl ./ model.s0, digits = 4)
    dsu_relative = round.(model.dsu ./ model.s0, digits = 4)
    relative_strikes = vcat(
        -1 .* reverse(dsl_relative),
        dsu_relative,
    )
    #
    volatility_offset = vcat(
        reverse(model.dvl),
        model.dvu,
    )
    #
    sql = "REPLACE INTO expiry_parameter ("
    sql = sql * "date, "
    sql = sql * "act_symbol, "
    sql = sql * "expiration, "
    sql = sql * "price, "
    sql = sql * "expiry_time, "
    sql = sql * "normal_volatility, "
    sql = sql * "log_volatility,"
    sql = sql * "rexl,"
    sql = sql * "rexu,"
    sql = sql * "alpha"
    sql = sql * ") VALUES ("
    sql = sql * "'" * string(date) * "', "
    sql = sql * "'" * act_symbol * "', "
    sql = sql * "'" * string(expiration) * "', "
    sql = sql * string(price) * ", "
    sql = sql * string(expiry_time) * ", "
    sql = sql * string(normal_volatility) * ", "
    sql = sql * string(log_volatility) * ", "
    sql = sql * "'" * param.rexl * "', "
    sql = sql * "'" * param.rexu * "', " 
    sql = sql * string(α) * ");"
    # println(sql)
    DBInterface.execute(conn, sql)
    #
    sql = "REPLACE INTO smile_parameter ("
    sql = sql * "date, "
    sql = sql * "act_symbol, "
    sql = sql * "expiration, "
    sql = sql * "relative_strike, "
    sql = sql * "volatility_offset"
    sql = sql * ") VALUES "
    first3 = "'" * string(date) * "', "
    first3 = first3 * "'" * act_symbol * "', "
    first3 = first3 * "'" * string(expiration) * "', "
    for (rel_strike, vol_offset) in zip(relative_strikes, volatility_offset)
        row = "(" * first3
        row = row * string(rel_strike) * ", "
        row = row * string(vol_offset) * "), "
        sql = sql * row
    end
    sql = sql[begin:end-2] * ";"
    # println(sql)
    DBInterface.execute(conn, sql)
end


function store_model(
    conn,
    df::DataFrame,
    param::ModelParameter,
    ;
    α = 0.0,
    lmfit_kwargs = (
        autodiff = :forwarddiff,
        maxIter  = 10
    ),
    )
    #
    @assert length(unique(df.date)) == 1
    @assert length(unique(df.act_symbol)) == 1
    @assert length(unique(df.expiration)) == 1
    #
    date = df.date[begin]
    act_symbol = df.act_symbol[begin]
    expiration = df.expiration[begin]
    #
    local model
    try
        (model, _) = calibrated_model(df, p, α=α, lmfit_kwargs=lmfit_kwargs)
    catch
        @warn "Cannot calibrate model for $act_symbol, $(string(date)), expiry $(string(expiration))."
        return
    end
    #
    store_model(conn, date, act_symbol, expiration, model, param, α)
    @info "Store model for $act_symbol, $(string(date)), expiry $(string(expiration))."
end


function store_models(
    conn,
    df::DataFrame,
    param::ModelParameter,
    ;
    α = 0.0,
    lmfit_kwargs = (
        autodiff = :forwarddiff,
        maxIter  = 10
    ),
    )
    symbols = unique(df.act_symbol)
    for symbol in symbols
        df2 = df[df.act_symbol.==symbol, :]
        expiries = unique(df2.expiration)
        for expiry in expiries
            df3 = df2[df2.expiration.==expiry, :]
            store_model(conn, df3, param, α=α, lmfit_kwargs=lmfit_kwargs)
        end
    end
end

