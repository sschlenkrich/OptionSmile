
function stock_plot(
    conn,
    symbol::String,
    start_date::String,
    end_date::String,
    )
    #
    q = "select date, act_symbol, close from ohlcv "
    q = q * "where act_symbol = '$symbol' "
    q = q * "and date >= '$(string(start_date))' "
    q = q * "and date <= '$(string(end_date))' "
    q = q * "order by date;"
    df = query(conn, q)
    #
    p = plot(df.date, df.close,
        title = "Close price $(symbol)",
        xlabel = "date",
        ylabel = "price",
        titlefontsize = 10,
        xguidefontsize = 10,
        yguidefontsize = 10,
        label = nothing,
        seriestype = :path,
        marker = :circle,
        markersize = 2,
        size = (800, 600),
        )
    return p
end

