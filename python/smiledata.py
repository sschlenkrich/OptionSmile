
import warnings

import numpy as np
import pandas as pd

import data

from dateutils import dt_date, iso_date, ql_date
from yieldcurve import yield_curve
from forward import implied_forward_from_smile
from volatilities import implied_volatilities

def smile_data(symbol, date):
    df_spot = data.spot_price(symbol, date)
    if df_spot.shape[0] == 0:
        return dict(message = "ERROR. No spot price for symbol " + symbol + ", date " + iso_date(date) + ".")
    if df_spot.shape[0] > 1:
        return dict(message = "ERROR. No unique spot price for symbol " + symbol + ", date " + iso_date(date) + ".")
    spot_price = float(df_spot.iloc[0]['close'])
    #
    try:
        disc_ytsh = yield_curve(date)
    except Exception as e:
        return dict(message = "ERROR. Cannot build yield curve for date " + iso_date(date) + ". " + str(e))
    #
    df_expiries = data.smile_expiries(symbol, date)
    if df_expiries.shape[0] == 0:
        return dict(message = "ERROR. No expiries for symbol " + symbol + ", date " + iso_date(date) + ".")
    #
    expiry_dates = np.array(data.smile_expiries(symbol, date)['expiration'])
    # dividends = data.dividends(symbol, date, expiry_dates[-1])
    dividends = data.dividends(symbol, date, 4)
    dividend_ex_dates = np.array(dividends['ex_date'])
    dividend_amounts = np.array(dividends['amount'])
    #
    option_prices = []
    forward_prices = []
    dividend_yields = []
    option_volatilities = []
    for expiry_date in expiry_dates:
        prices = data.smile_prices(symbol, date, expiry_date)
        # derive mid-prices from bid/ask
        strikes = np.array(prices.columns)
        prices = prices.reset_index().drop(['date', 'act_symbol', 'expiration'], axis=1)
        mid_prices = prices.drop(['data_name'], axis=1).groupby(['call_put']).mean().reset_index()
        mid_prices['data_name'] = 'mid'
        # append price data for mid
        prices = pd.concat([prices, mid_prices], ignore_index=True)
        option_prices.append(prices)
        # implied forward
        c_mid = np.array(mid_prices[mid_prices['call_put']=='Call'].drop(['data_name', 'call_put'], axis=1).iloc[0])
        p_mid = np.array(mid_prices[mid_prices['call_put']=='Put'].drop(['data_name', 'call_put'], axis=1).iloc[0])
        # we aim for a robust strategy for estimate forward prices
        forward_price = None
        div_yield = None
        for div_rate_min, div_rate_max in [(-0.05, 0.05), (-0.25, 0.25)]:
            try:
                forward_price, div_yield = implied_forward_from_smile(
                    date, spot_price, disc_ytsh, dividend_ex_dates, dividend_amounts, expiry_date, strikes,
                    c_mid, p_mid, div_rate_min, div_rate_max)
                break  # exit loop if successful
            except:
                warnings.warn("" \
                    "Warning. Cannot calculate forward price for " + symbol + \
                    ", date " + iso_date(date) + \
                    ", expiry " + iso_date(expiry_date) + \
                    ", div-yield range " + str((div_rate_min, div_rate_max)) + "."
                )
        #
        if forward_price is None:
            forward_price = spot_price / disc_ytsh.discount(ql_date(expiry_date))
        if div_yield is None:
            div_yield = 0.0
        #
        forward_prices.append(forward_price)
        dividend_yields.append(div_yield)
        # implied volatilities
        option_vols = []
        for _, row in prices.iterrows():
            cp = 1 if row['call_put']=='Call' else -1
            prices = np.array(row[strikes])
            vols = implied_volatilities(
                date, spot_price, disc_ytsh, dividend_ex_dates, dividend_amounts, div_yield, expiry_date, strikes, prices, cp
            )
            # collect results
            d = { 'call_put' : row['call_put'], 'data_name' : row['data_name'] }
            for s, v in zip(strikes, vols):
                d[s] = v
            option_vols.append(d)
        #
        option_vols = pd.DataFrame(option_vols)
        option_volatilities.append(option_vols)
    #
    return dict(
        message = None,
        symbol = symbol,
        date = dt_date(date),
        spot_price = spot_price,
        expiry_dates = expiry_dates,
        dividend_ex_dates = dividend_ex_dates,
        dividend_amounts = dividend_amounts,
        option_prices = option_prices,
        forward_prices = forward_prices,
        dividend_yields = dividend_yields,
        option_volatilities = option_volatilities,
    )


def store_smile_data(smile_dict=None, symbol=None, date=None):
    if smile_dict is None:
        smile_dict = smile_data(symbol, date)
    #
    if smile_dict['message'] is not None:
        # an error occured and we cannot store results
        return smile_dict
    #
    symbol = smile_dict['symbol']
    date = iso_date(smile_dict['date'])
    #
    table = pd.DataFrame()
    table['expiration'] = smile_dict['expiry_dates']
    table['price'] = smile_dict['forward_prices']
    table['act_symbol'] = smile_dict['symbol']
    table['date'] = smile_dict['date']
    # store table cannot handle datetime.dates
    table['expiration'] = table['expiration'].astype(str)
    table['date'] = table['date'].astype(str)
    # we need the correct order of columns
    fwd_table = table[['date', 'act_symbol', 'expiration', 'price']]
    #
    try:
        data.store_forward_prices(fwd_table)
    except Exception as e:
        return dict(message = "ERROR. Cannot store forward prices for symbol " + symbol + ", date " + date + ". " + str(e))
    #
    vol_tables = []
    for expiry, volatilities in zip(smile_dict['expiry_dates'], smile_dict['option_volatilities']):
        table = pd.melt(
            volatilities,
            id_vars=['call_put', 'data_name'],
            var_name='strike',
            value_name='volatility',
        )
        table = pd.pivot_table(
            table,
            values=['volatility'],
            index = ['call_put', 'strike'],
            columns = ['data_name'],
            dropna = False,
        ).reset_index()
        table.columns = ['call_put', 'strike', 'ask', 'bid', 'mid']
        table['expiration'] = expiry
        vol_tables.append(table)
    #
    table = pd.concat(vol_tables)
    table['date'] = smile_dict['date']
    table['act_symbol'] = smile_dict['symbol']
    #
    table['date'] = table['date'].astype(str)
    table['expiration'] = table['expiration'].astype(str)
    #
    vol_table = table[['date', 'act_symbol', 'expiration', 'strike', 'call_put', 'mid', 'bid', 'ask']]
    #
    try:
        data.store_volatilities(vol_table)
    except Exception as e:
        return dict(message = "ERROR. Cannot store volatilities for symbol " + symbol + ", date " + date + ". " + str(e))
    #
    # We collect some statistics for logging
    mess = "DONE. Store %d forward prices and %d volatilities for symbol %s, date %s." % \
        (fwd_table.shape[0], vol_table.shape[0], symbol, date)
    return dict(message = mess)
