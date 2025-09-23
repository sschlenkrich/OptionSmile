
import numpy as np
import pandas as pd

import data

from dateutils import dt_date
from yieldcurve import yield_curve
from forward import implied_forward_from_smile
from volatilities import implied_volatilities

def smile_data(symbol, date):
    spot_price = float(data.spot_price(symbol, date).iloc[0]['close'])
    disc_ytsh = yield_curve(date)
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
        forward_price, div_yield = implied_forward_from_smile(
            date, spot_price, disc_ytsh, dividend_ex_dates, dividend_amounts, expiry_date, strikes, c_mid, p_mid
        )
        forward_prices.append(forward_price)
        dividend_yields.append(div_yield)
        # implied volatilities
        option_vols = []
        for _, row in prices.iterrows():
            data_name = row['data_name']
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
