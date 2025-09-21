
import pandas as pd
import pymysql

__RATES__ = None
__STOCKS__ = None
__OPTIONS__ = None

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
    __RATES__ = connection("rates")
    __STOCKS__ = connection("stocks")
    __OPTIONS__ = connection("options")
    return (__RATES__, __STOCKS__, __OPTIONS__)


def interest_rates(date):
    if type(date) != str:
        date = date.isoformat()
    q = "select * from us_treasury where date='%s'" % date
    df = pd.read_sql(q, __RATES__)
    df.columns = [ # as period string
        "date", "1m", "2m", "3m", "6m", "1y", "2y", "3y", "5y", "7y", "10y", "20y", "30y"
    ]
    df = df.dropna(axis=1)
    return df


def spot_price(symbol, date):
    if type(date) != str:
        date = date.isoformat()
    q = "select * from ohlcv where act_symbol = '%s' and date='%s'" % (symbol, date)
    df = pd.read_sql(q, __STOCKS__)
    df = df[['date', 'act_symbol', 'close']]
    return df


def dividends(symbol, date, maximum=None):
    if type(date) != str:
        date = date.isoformat()
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
    q = "select distinct(expiration) as expiration from option_chain where act_symbol='%s' and date='%s'" % (symbol, date)
    df = pd.read_sql(q, __OPTIONS__)
    return df


def smile_prices(symbol, date, expiry_date = None, values = ['bid', 'ask']):
    if type(date) != str:
        date = date.isoformat()
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
