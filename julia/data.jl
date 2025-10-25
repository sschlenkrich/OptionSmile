
function connection(db_name = "volatilities")
    return DBInterface.connect(
        MySQL.Connection,
        "localhost",
        "root",
        "",
        db=db_name,
       )
end

function query(conn, sql, drop_missing = true)
    df = DataFrame(DBInterface.execute(conn, sql))
    if drop_missing
        df = df[completecases(df), :]
        disallowmissing!(df)
    end
    return df
end

_sql(table, date) = "select * from $table where date = '$(string(date))';"
_sql(table, date, symbol) = "select * from $table where date = '$(string(date))' and act_symbol = '$symbol';"
_smile_indices(df) =
    (df.mid .> 0.01) .&
    (df.bid .> 0.01) .&
    (df.ask .> 0.01) .&
    ((df.call_put .== "Call") .| (df.strike .< df.price)) .&
    ((df.call_put .== "Put")  .| (df.strike .≥ df.price))

function smile_data(conn, symbol, date)
    df_v = query(conn, _sql("volatility", date, symbol))
    df_e = query(conn, _sql("forwardprice", date, symbol))
    df_smile = innerjoin(df_e, df_v, on=[:date, :act_symbol, :expiration])
    df_smile = df_smile[_smile_indices(df_smile), :]
    return df_smile
end

function smile_data(conn, date)
    df_v = query(conn, _sql("volatility", date))
    df_e = query(conn, _sql("forwardprice", date))
    df_smile = innerjoin(df_e, df_v, on=[:date, :act_symbol, :expiration])
    df_smile = df_smile[_smile_indices(df_smile), :]
    return df_smile
end

function volatility_dates(conn, symbol, start_date, end_date)
    q = "select distinct(date) as date from forwardprice "
    q = q * "where act_symbol = '$symbol' "
    q = q * "and date >= '$(string(start_date))' "
    q = q * "and date <= '$(string(end_date))' "
    q = q * "order by date;"
    return query(conn, q, false)
end
