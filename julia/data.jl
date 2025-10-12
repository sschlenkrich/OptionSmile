
using DataFrames
using MySQL

function connection(db_name = "volatilities")
    return DBInterface.connect(
        MySQL.Connection,
        "localhost",
        "root",
        "",
        db=db_name,
       )
end

function smile_data(conn, symbol, date)
    sql = "select * from smile where date = '$(string(date))' and act_symbol = '$symbol';"
    df = DataFrame(DBInterface.execute(conn, sql))
    return df
end


function smile_data(conn, date)
    sql = "select * from smile where date = '$(string(date))';"
    df = DataFrame(DBInterface.execute(conn, sql))
    return df
end
