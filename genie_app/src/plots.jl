
import PlotlyBase
using Printf

import PiecewiseVanillaModel
pvm = PiecewiseVanillaModel

function stock_traces(
    conn,
    act_symbol,
    start_date,
    end_date,
    )
    #
    q = "select * from ohlcv "
    q = q * "where act_symbol = '$act_symbol' "
    q = q * "and date >= '$(string(start_date))' "
    q = q * "and date <= '$(string(end_date))' "
    q = q * "order by date;"
    df = OptionSmile.query(conn, q)
    #
    trace = PlotlyBase.ohlc(
        df,
        x=:date,
        open=:open,
        high=:high,
        low=:low,
        close=:close,
        showlegend = false,
    )
    #
    min_price = minimum(df.low)
    max_price = maximum(df.high)
    #
    return (
        traces = [ trace ],
        min_price = min_price,
        max_price = max_price,
    )
end

function obs_date_trace(obs_date, min_price, max_price)
    PlotlyBase.scatter(
        x = [ obs_date,  obs_date  ],
        y = [ min_price, max_price ],
        showlegend = false,
        mode = :lines,
        line = PlotlyBase.attr(
            color = :grey,
            width = 2,
        ),
    )
end


function stock_layout(
    act_symbol,
    )
    #
    PlotlyBase.Layout(
        title="Stock price " * act_symbol,
        xaxis=PlotlyBase.attr(
            title="date",
            showgrid=true
        ),
        yaxis=PlotlyBase.attr(
            title="price",
            showgrid=true,
        )
    )
end


function smile_traces(
    conn,
    act_symbol,
    date,
    param,
    )
    #
    df = OptionSmile.smile_data(conn, act_symbol, date)
    #
    marker_size = 6
    marker_symbols = [ :circle, :square, :diamond ]
    n = length(marker_symbols)
    #
    line_width = 1.0
    #
    implied_vol_traces = PlotlyBase.AbstractTrace[]
    vol_params_traces = PlotlyBase.AbstractTrace[]
    expiries = unique(df.expiration)
    for (idx, expiry) in enumerate(expiries)
        df_e = df[df.expiration.==expiry, :]
        df_p = df_e[df_e.call_put.=="Put", :]
        df_c = df_e[df_e.call_put.=="Call", :]
        #
        scaling = 100.0  # vols in percentage
        #
        p_mid = df_p.mid .* scaling
        c_mid = df_c.mid .* scaling
        #
        p_err_bot = (df_p.mid .- df_p.bid) .* scaling
        p_err_top = (df_p.ask .- df_p.mid) .* scaling
        #
        c_err_bot = (df_c.mid .- df_c.bid) .* scaling
        c_err_top = (df_c.ask .- df_c.mid) .* scaling
        #
        trace_p = PlotlyBase.scatter(
            x = df_p.strike,
            y = p_mid,
            name = "P $(string(expiry))",
            mode = :markers,
            marker = PlotlyBase.attr(
                size = marker_size,
                symbol = marker_symbols[begin + (idx%n)],
                color = :darkblue,
            ),
            error_y = PlotlyBase.attr(
                type = :data,
                array = p_err_top,
                arrayminus = p_err_bot,
                thickness = line_width,
                visible = true
            ),
            line_width = line_width,
        )
        #
        trace_c = PlotlyBase.scatter(
            x = df_c.strike,
            y = c_mid,
            name = "C $(string(expiry))",
            mode = :markers,
            marker = PlotlyBase.attr(
                size = marker_size,
                symbol = marker_symbols[begin + (idx%n)],
                color = :darkred,
            ),
            error_y = PlotlyBase.attr(
                type = :data,
                array = c_err_top,
                arrayminus = c_err_bot,
                thickness = line_width,
                visible = true
            ),
        )
        #
        push!(implied_vol_traces, trace_p)
        push!(implied_vol_traces, trace_c)
    end
    models = OptionSmile.calibrated_models(df, param)
    for (idx, model) in enumerate(models)
        if isnothing(model)
            continue
        end
        #
        s0 = @sprintf "%.2f" model.s0
        T = (@sprintf "%.0f" round(model.T * 365.0)) * "d"
        #
        s_min = model.s0 - model.dsl[end]
        s_max = model.s0 + model.dsu[end]
        #
        s_extrap = 0.1 * (s_max - s_min)
        s_min -= s_extrap
        s_max += s_extrap
        #
        delta = (s_max - s_min) / 100.0
        strikes = collect(s_min:delta:s_max)
        ivols = [
            try
                pvm.lognormal_volatility(model, s)
            catch
                NaN
            end
            for s in strikes
        ]
        #
        scaling = 100.0  # implied vols in percentage
        trace_v = PlotlyBase.scatter(
            x = strikes,
            y = ivols .* scaling,
            name = "T: $T",
            mode = :lines,
            showlegend = false,
            line = PlotlyBase.attr(
                color = :green,
                width = line_width,
            ),
        )
        push!(implied_vol_traces, trace_v)
        #
        lvols = [
            try
                pvm.local_volatility(model, s)
            catch
                NaN
            end
            for s in strikes
        ]
        #
        trace_v = PlotlyBase.scatter(
            x = strikes,
            y = lvols,
            name = "T: $T",
            mode = :lines,
            showlegend = false,
            line = PlotlyBase.attr(
                color = :green,
                width = line_width,
            ),
        )
        push!(vol_params_traces, trace_v)
        #
        strikes = model.s0 .+ vcat(reverse(-model.dsl), [0.0], model.dsu)
        lvols = model.v0 .+ vcat(reverse(model.dvl), [0.0], model.dvu)
        trace_v = PlotlyBase.scatter(
            x = strikes,
            y = lvols,
            name = "S0: $s0, T: $T",
            mode = :markers,
            marker_size = marker_size,
            marker_symbol = marker_symbols[begin + (idx%n)],
            marker_color = :green,
        )
        push!(vol_params_traces, trace_v)
    end
    return (implied_vol_traces, vol_params_traces)
end

function _lim(s::String)
    if s == ""
        return nothing
    end
    return parse(Float64, s)
end

function implied_vol_layout(
    act_symbol,
    date,
    x_min_text,
    x_max_text,
    y_min_text,
    y_max_text,
    )
    #
    PlotlyBase.Layout(
        title="Implied volatility $act_symbol, $(string(date))",
        xaxis=PlotlyBase.attr(
            title="strike",
            showgrid=true,
            range = (_lim(x_min_text), _lim(x_max_text)),
        ),
        yaxis=PlotlyBase.attr(
            title="volatility (%)",
            showgrid=true,
            range = (_lim(y_min_text), _lim(y_max_text)),
        )
    )
end


function vol_parameter_layout(
    act_symbol,
    date,
    model_param,
    x_min_text,
    x_max_text,
    y_min_text,
    y_max_text,
    )
    #
    α = @sprintf "%.2e" model_param.alpha
    PlotlyBase.Layout(
        title="Volatility model parameters, α = $α",
        xaxis=PlotlyBase.attr(
            title="strike",
            showgrid=true,
            range = (_lim(x_min_text), _lim(x_max_text)),
        ),
        yaxis=PlotlyBase.attr(
            title="abs volatility (price)",
            showgrid=true,
            range = (_lim(y_min_text), _lim(y_max_text)),
        )
    )
end


function plot_ranges(min_price, max_price)
    margin = 0.3
    x_min = (1.0-margin) * min_price
    x_max = (1.0+margin) * max_price
    σ_max = 1.0 * max_price
    x_min_text = string(10 * round(Int, x_min/10.0))
    x_max_text = string(10 * round(Int, x_max/10.0))
    y1_min_text = "0"
    y1_max_text = "100"
    y2_min_text = "0"
    y2_max_text = string(10 * round(Int, σ_max/10.0))
    #
    return (
        x_min_text = x_min_text,
        x_max_text = x_max_text,
        y1_min_text = y1_min_text,
        y1_max_text = y1_max_text,
        y2_min_text = y2_min_text,
        y2_max_text = y2_max_text,
    )
end
