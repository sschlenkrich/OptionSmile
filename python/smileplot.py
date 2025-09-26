
import datetime
import numpy as np
import plotly.graph_objects as go

from dateutils import iso_date
from smiledata import smile_data


def _atm_data(data):
    vols = []
    for forward_price, option_volatilities in zip(data['forward_prices'], data['option_volatilities']):
        tmp = option_volatilities[option_volatilities['data_name']=='mid'].dropna(axis=1)
        strikes = tmp.columns[2:]
        c_vols = np.array(tmp[tmp['call_put']=='Call'].drop(['call_put', 'data_name'], axis=1).iloc[0])
        p_vols = np.array(tmp[tmp['call_put']=='Put'].drop(['call_put', 'data_name'], axis=1).iloc[0])    
        atm_vol_c = np.interp(forward_price, strikes, c_vols)
        atm_vol_p = np.interp(forward_price, strikes, p_vols)
        vols.append(float(0.5*(atm_vol_c + atm_vol_p)))
    #
    dates = [ data['date'] ] + list(data['expiry_dates'])
    strikes = [ data['spot_price'] ] + data['forward_prices']
    vols = [ vols[0] ] + vols
    return dates, strikes, vols


def _smile_volatilities(data, data_name):
    return np.array(data[data['data_name']==data_name
        ].drop(['call_put', 'data_name'], axis=1).iloc[0])


def smile_plot(symbol, date, overlapp_idx = 3, without_nan=True):
    data = smile_data(symbol, date)
    traces = []
    #
    atm_expiries, atm_strikes, atm_vols = _atm_data(data)
    trace = go.Scatter3d(
        x=atm_expiries, y=atm_strikes, z=atm_vols,
            name='ATM',
            line=dict( color='orange', width=1 ),
            marker=dict( size=2, color='orange' )
            )
    traces.append(trace)
    #
    overlapp_idx = 3  # how much overlapp for C/P
    for expiry_date, forward_price, option_volatilities in zip(data['expiry_dates'], data['forward_prices'], data['option_volatilities']):
        #
        c_vols = option_volatilities[option_volatilities['call_put']=='Call']
        p_vols = option_volatilities[option_volatilities['call_put']=='Put']
        if without_nan:
            c_vols = c_vols.dropna(axis=1)
            p_vols = p_vols.dropna(axis=1)
        #
        c_strikes = np.array(c_vols.columns[2:])
        p_strikes = np.array(p_vols.columns[2:])
        atm_idx_c = np.searchsorted(c_strikes, forward_price)
        atm_idx_p = np.searchsorted(p_strikes, forward_price)
        c_idx = max(atm_idx_c - overlapp_idx, 0)
        p_idx = min(atm_idx_p + overlapp_idx, len(p_strikes))
        #
        c_expiries = np.array([expiry_date] * len(c_strikes))
        p_expiries = np.array([expiry_date] * len(p_strikes))
        #
        c_vols_mid = _smile_volatilities(c_vols, 'mid')
        c_vols_bid = _smile_volatilities(c_vols, 'bid')
        c_vols_ask = _smile_volatilities(c_vols, 'ask')
        c_vols_up = c_vols_ask - c_vols_mid
        c_vols_do = c_vols_mid - c_vols_bid
        #
        p_vols_mid = _smile_volatilities(p_vols, 'mid')
        p_vols_bid = _smile_volatilities(p_vols, 'bid')
        p_vols_ask = _smile_volatilities(p_vols, 'ask')
        p_vols_up = p_vols_ask - p_vols_mid
        p_vols_do = p_vols_mid - p_vols_bid
        #
        trace = go.Scatter3d(
            x=c_expiries[c_idx:], y=c_strikes[c_idx:], z=c_vols_mid[c_idx:],
            name='C ' + iso_date(expiry_date),
            line=dict( color='red', width=1 ),
            marker=dict( size=2, color='red' ),
            error_z = dict(
                array=c_vols_up[c_idx:],
                arrayminus=c_vols_do[c_idx:],
            ),
        )
        traces.append(trace)
        #
        trace = go.Scatter3d(
            x=p_expiries[:p_idx], y=p_strikes[:p_idx], z=p_vols_mid[:p_idx],
            name='P ' + iso_date(expiry_date),
            line=dict( color='blue', width=1 ),
            marker=dict( size=2, color='blue' ),
            error_z = dict(
                array=p_vols_up[:p_idx],
                arrayminus=p_vols_do[:p_idx],
            ),
        )
        traces.append(trace)
    #
    x_start = data['date'] - datetime.timedelta(days=1)
    x_end = data['expiry_dates'][-1] + datetime.timedelta(days=1)
    x_ticks = atm_expiries
    title_text = 'Implied Volatilities, ' + data['symbol'] + ', ' + iso_date(data['date'])
    #
    layout = go.Layout(
        title=dict(text = title_text),
        scene = dict(
            xaxis = dict(
                title = dict(text='expiry'),
                range = (x_start, x_end),
                tickvals = x_ticks,
            ),
            yaxis = dict(
                title = dict(text='strike'),
            ),
            zaxis = dict(
                title = dict(text='volatility'),
                tickformat =',.0%',
            )
        ),
        width=800,
        height=800,
    )
    fig = go.Figure(data=traces, layout=layout)
    return fig
