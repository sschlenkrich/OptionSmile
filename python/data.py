
import pandas as pd
import pymysql

from dateutils import iso_date

__RATES__ = None
__STOCKS__ = None
__OPTIONS__ = None
__VOLATILITIES__ = None

def connection(db_name):
    return pymysql.connect(
        host="localhost",
        user="root",
        passwd="",
        database=db_name,
    )


def initialise():
    global __RATES__
    global __STOCKS__
    global __OPTIONS__
    global __VOLATILITIES__
    __RATES__ = connection("rates")
    __STOCKS__ = connection("stocks")
    __OPTIONS__ = connection("options")
    __VOLATILITIES__ = connection("volatilities")
    return {
        "rates" : __RATES__,
        "stocks" : __STOCKS__,
        "options" : __OPTIONS__,
        "volatilities" : __VOLATILITIES__,
    }


def interest_rates(date, use_most_recent=False):
    date = iso_date(date)
    if use_most_recent:
        q = "select max(date) as max_date from us_treasury where date <= '%s'" % date
        df = pd.read_sql(q, __RATES__)
        if df.shape == (1, 1):
            date = iso_date(df.iloc[0]["max_date"])
        #
    #
    q = "select * from us_treasury where date='%s'" % date
    df = pd.read_sql(q, __RATES__)
    df.columns = [ # as period string
        "date", "1m", "2m", "3m", "6m", "1y", "2y", "3y", "5y", "7y", "10y", "20y", "30y"
    ]
    df = df.dropna(axis=1)
    return df


def spot_price(symbol, date, use_most_recent=False):
    date = iso_date(date)
    if use_most_recent:
        q = "select max(date) as max_date from ohlcv where act_symbol = '%s' and date <= '%s'" % (symbol, date)
        df = pd.read_sql(q, __STOCKS__)
        if df.shape == (1, 1):
            date = iso_date(df.iloc[0]["max_date"])
        #
    #
    q = "select * from ohlcv where act_symbol = '%s' and date='%s'" % (symbol, date)
    df = pd.read_sql(q, __STOCKS__)
    df = df[['date', 'act_symbol', 'close']]
    return df


def dividends(symbol, date, maximum=None):
    date = iso_date(date)
    q = \
    '''
    select act_symbol, Date('%s') as date, ex_date, amount
    from dividend
    where act_symbol = '%s'
    and ex_date > '%s'
    ''' % (date, symbol, date)
    limit_clause = ""
    max_date_clause = ""
    if maximum is not None:
        if type(maximum) == int:
            limit_clause = " limit %d" % maximum
        else:
            if type(maximum) != str:
                date_str = maximum.isoformat()
            else:
                date_str = maximum
            max_date_clause = " and ex_date <= '%s'" % date_str
    q = q + max_date_clause
    q = q + " order by ex_date"
    q = q + limit_clause
    df = pd.read_sql(q, __STOCKS__)
    return df


def smile_expiries(symbol, date):
    date = iso_date(date)
    q = "select distinct(expiration) as expiration from option_chain where act_symbol='%s' and date='%s'" % (symbol, date)
    df = pd.read_sql(q, __OPTIONS__)
    return df


def smile_prices(symbol, date, expiry_date = None, values = ['bid', 'ask']):
    date = iso_date(date)
    index = [
        "date", "act_symbol", "expiration", "call_put",
    ]
    columns = [
        "strike",
    ]
    # sql string for columns
    fields = ", ".join(index + columns + values)
    q = "select %s from option_chain where act_symbol='%s' and date='%s'" % (fields, symbol, date)
    if expiry_date is not None:
        if type(expiry_date) != str:
            expiry_date = expiry_date.isoformat()
        q = q + " and expiration='%s'" % expiry_date
    #
    df = pd.read_sql(q, __OPTIONS__)
    df = pd.melt(df,
        id_vars=index + columns,
        value_vars=values,
        var_name='data_name',
        value_name='data_value',
    )
    df = pd.pivot_table(df, values='data_value', index=index + ['data_name'], columns=columns)
    return df


def store_table(table, conn, table_name):
    sql = ("REPLACE INTO %s (" % table_name) + ", ".join(table.columns) + ") VALUES "
    for _, row in table.iterrows():
        line = str(tuple(row)) + ", "
        sql = sql + line
    sql = sql[:-2] + ";"
    # SQL does not understand nan
    sql = sql.replace("nan", "NULL")  # this is dangerous
    #
    with conn.cursor() as curs:
        curs.execute(sql)
    conn.commit()


def store_forward_prices(df):
    store_table(df, __VOLATILITIES__, "forwardprice")

def store_volatilities(df):
    store_table(df, __VOLATILITIES__, "volatility")


def queue_all(symbols = None, dates_ascending = False):
    sql = "select distinct date, act_symbol from option_chain"
    all_chains = pd.read_sql(sql, __OPTIONS__)
    if symbols is not None:
        all_chains = all_chains[all_chains["act_symbol"].isin(symbols)]
    #
    sql = "select distinct date, act_symbol from volatility"
    all_vols = pd.read_sql(sql, __VOLATILITIES__)
    if symbols is not None:
        all_vols = all_vols[all_vols["act_symbol"].isin(symbols)]
    #
    all_chains['KEY'] = all_chains['date'].astype(str).str.cat(all_chains['act_symbol'], sep="|")
    all_vols['KEY'] = all_vols['date'].astype(str).str.cat(all_vols['act_symbol'], sep="|")
    intersect = pd.merge(all_chains['KEY'], all_vols['KEY'], how='inner', on='KEY')
    #
    open_chains = all_chains[~all_chains['KEY'].isin(intersect['KEY'])].drop("KEY", axis=1)
    sort_asc = (dates_ascending, True)
    open_chains = open_chains.sort_values(by=['date', 'act_symbol'], ascending=sort_asc)
    return open_chains


def queue_new(symbols = None, dates_ascending = True):
    sql = "select max(date) as date from volatility"
    max_date_df = pd.read_sql(sql, __VOLATILITIES__)
    max_date_str = iso_date(max_date_df.iloc[0]['date'])
    #
    sql = "select distinct date, act_symbol from option_chain where date > '%s'" % max_date_str
    all_chains = pd.read_sql(sql, __OPTIONS__)
    if symbols is not None:
        all_chains = all_chains[all_chains["act_symbol"].isin(symbols)]
    #
    sort_asc = (dates_ascending, True)
    open_chains = all_chains.sort_values(by=['date', 'act_symbol'], ascending=sort_asc)
    return open_chains


def update_database(conn):
    sql_pull = "CALL DOLT_PULL('post-no-preference')"
    sql_push = "CALL DOLT_PUSH('origin', 'master')"
    try:
        df = pd.read_sql(sql_pull, conn)
        mess_pull = "PULL: " + df.iloc[0]["message"]
    except Exception as e:
        mess_pull = "ERROR while pull " + str(conn.db) + ". " + str(e)
    #
    try:
        df = pd.read_sql(sql_push, conn)
        mess_push = "PUSH: " + df.iloc[0]["message"]
    except Exception as e:
        mess_push = "ERROR while push " + str(conn.db) + ". " + str(e)
    #
    return (mess_pull, mess_push)

def update_rates():
    return update_database(__RATES__)

def update_stocks():
    return update_database(__STOCKS__)

def update_options():
    return update_database(__OPTIONS__)

def pull_volatilities():
    sql_pull = "CALL DOLT_PULL('origin')"
    conn = __VOLATILITIES__
    try:
        df = pd.read_sql(sql_pull, conn)
        mess_pull = "PULL: " + df.iloc[0]["message"]
    except Exception as e:
        mess_pull = "ERROR while pull " + str(conn.db) + ". " + str(e)
    #
    return mess_pull

def push_volatilities(date):
    sql_commit = "CALL DOLT_COMMIT('-a', '-m', 'Update for %s')" % str(date)
    sql_push = "CALL DOLT_PUSH('origin', 'main')"
    conn = __VOLATILITIES__
    try:
        df = pd.read_sql(sql_commit, conn)
        mess_comm = "COMMIT: " + df.iloc[0]["hash"]
    except Exception as e:
        mess_comm = "ERROR while commit " + str(conn.db) + ". " + str(e)
    #
    try:
        df = pd.read_sql(sql_push, conn)
        mess_push = "PUSH: " + df.iloc[0]["message"]
    except Exception as e:
        mess_push = "ERROR while push " + str(conn.db) + ". " + str(e)
    #
    return (mess_comm, mess_push)
