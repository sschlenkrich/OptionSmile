
using Printf
using StatsPlots

function smile_plot(conn, symbol, date)
    df = smile_data(conn, symbol, date)
    return smile_plot(df)
end


function smile_plot(df::DataFrame, seriestype = :path)
    legend_position = :outerright
    markers = [ :circle, :rect, :diamond ]
    n = length(markers)
    marker_size = 1.5
    date = df.date[begin]
    symbol = df.act_symbol[begin]
    expiries = unique(df.expiration)
    p = plot(
        title = "$symbol, $(string(date))",
        xlabel = "strike",
        ylabel = "volatility",
        titlefontsize = 10,
        xguidefontsize = 10,
        yguidefontsize = 10,
        legend_position = legend_position,
        )
    for (idx, expiry) in enumerate(expiries)
        df_e = df[df.expiration.==expiry, :]
        df_p = df_e[df_e.call_put.=="Put", :]
        df_c = df_e[df_e.call_put.=="Call", :]
        #
        p_err_bot = df_p.mid .- df_p.bid
        p_err_top = df_p.ask .- df_p.mid
        #
        c_err_bot = df_c.mid .- df_c.bid
        c_err_top = df_c.ask .- df_c.mid
        #
        plot!(p, df_p.strike, df_p.mid,
            yerror = (p_err_bot, p_err_top),
            label = "P $(string(expiry))",
            color = :blue,
            seriestype = seriestype,
            markershape = markers[idx%n + 1],
            markersize = marker_size,
        )
        plot!(p, df_c.strike, df_c.mid,
            yerror = (c_err_bot, c_err_top),
            label = "C $(string(expiry))",
            seriestype = seriestype,
            color = :red,
            markershape = markers[idx%n + 1],
            markersize = marker_size,
        )
    end
    return p
end

function model_plot(m, ref_strikes = nothing, ref_vols = nothing)
    marker_size = 2.0
    p1 = plot(
        title = "Model-implied volatilities",
        xlabel = "strike",
        ylabel = "volatility",
        titlefontsize = 10,
        xguidefontsize = 10,
        yguidefontsize = 10,
        )
    s_min = m.s0 - m.dsl[end]
    s_max = m.s0 + m.dsu[end]
    #
    s_extrap = 0.1 * (s_max - s_min)
    s_min -= s_extrap
    s_max += s_extrap
    #
    delta = (s_max - s_min) / 100.0
    strikes = collect(s_min:delta:s_max)
    vols = [
        try
            pvm.lognormal_volatility(m, s)
        catch
            NaN
        end
        for s in strikes
    ]
    lvols = [
        try
            pvm.local_volatility(m, s)
        catch
            NaN
        end
        for s in strikes
    ]
    #
    plot!(p1, strikes, vols,
        label = "S0: $(string(m.s0)), T: $(string(m.T))",
        color = :blue,
    )
    #
    if !isnothing(ref_strikes) && !isnothing(ref_vols)
        plot!(p1, ref_strikes, ref_vols,
            label = nothing,
            color = :red,
            markersize = marker_size,
            seriestype = :scatter,
        )
    end
    #
    p2 = plot(
        title = "Volatility parameters",
        xlabel = "strike",
        ylabel = "volatility",
        titlefontsize = 10,
        xguidefontsize = 10,
        yguidefontsize = 10,
        )
    plot!(p2, strikes, lvols,
        label = nothing,
        color = :blue,
    )
    #
    strikes = m.s0 .+ vcat(reverse(-m.dsl), [0.0], m.dsu)
    lvols = m.v0 .+ vcat(reverse(m.dvl), [0.0], m.dvu)
    plot!(p2, strikes, lvols,
        label = nothing,
        color = :blue,
        markersize = marker_size,
        seriestype = :scatter,
    )

    #
    l = @layout [a ; b ]
    p = plot(p1, p2; layout = l)
    return p
end


function smile_plot(df::DataFrame, models::Vector{Any})
    markers = [ :circle, :rect, :diamond ]
    legend_position = :outerright
    n = length(markers)
    marker_size = 1.5
    p1 = smile_plot(df, :scatter)
    p2 = plot(
        title = "Volatility parameters",
        xlabel = "strike",
        ylabel = "volatility",
        titlefontsize = 10,
        xguidefontsize = 10,
        yguidefontsize = 10,
        legend_position = legend_position,
        )
    for (idx, m) in enumerate(models)
        if isnothing(m)
            continue
        end
        s_min = m.s0 - m.dsl[end]
        s_max = m.s0 + m.dsu[end]
        #
        s_extrap = 0.1 * (s_max - s_min)
        s_min -= s_extrap
        s_max += s_extrap
        #
        delta = (s_max - s_min) / 100.0
        strikes = collect(s_min:delta:s_max)
        vols = [
            try
                pvm.lognormal_volatility(m, s)
            catch
                NaN
            end
            for s in strikes
        ]
        lvols = [
            try
                pvm.local_volatility(m, s)
            catch
                NaN
            end
            for s in strikes
        ]
        #
        s0 = @sprintf "%.2f" m.s0
        T = @sprintf "%.2f" m.T
        #
        plot!(p1, strikes, vols,
            label = nothing,
            color = :green,
        )
        #
        plot!(p2, strikes, lvols,
            label = nothing,
            color = :green,
        )
        #
        strikes = m.s0 .+ vcat(reverse(-m.dsl), [0.0], m.dsu)
        lvols = m.v0 .+ vcat(reverse(m.dvl), [0.0], m.dvu)
        plot!(p2, strikes, lvols,
            label = "S0: $s0, T: $T",
            color = :green,
            markershape = markers[idx%n + 1],
            markersize = marker_size,
            seriestype = :scatter,
        )
    end
    #
    l = @layout [a ; b ]
    p = plot(p1, p2;
        layout = l,
        size = (800, 600),
    )
    return p
end


function smile_plot(
    conn,
    symbol::String,
    date::String,
    p::ModelParameter,
    )
    #
    df = smile_data(conn, symbol, date)
    models = calibrated_models(df, p)
    p = smile_plot(df, models)
    return p
end


function smile_plot_date_all(
    conn,
    date::String,
    p::ModelParameter,
    path::String,
    )
    #
    df = smile_data(conn, date)
    symbols = unique(df.act_symbol)
    for symbol in symbols
        println("Process $symbol.")
        df2 = df[df.act_symbol.==symbol, :]
        models = calibrated_models(df2, p)
        plt = smile_plot(df2, models)
        file_name = path * date * "_" * symbol * ".png"
        savefig(plt, file_name)
    end
end
