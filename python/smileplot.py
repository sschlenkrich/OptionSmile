
import datetime
import numpy as np
import plotly.graph_objects as go

from dateutils import iso_date
from smiledata import smile_data


def atm_data(data):
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


def smile_volatilities(data, call_put, data_name):
    return np.array(data[
        (data['call_put']==call_put) &(data['data_name']==data_name)
        ].drop(['call_put', 'data_name'], axis=1).iloc[0])


def smile_plot(symbol, date, overlapp_idx = 3):
    data = smile_data(symbol, date)
    traces = []
    #
    atm_expiries, atm_strikes, atm_vols = atm_data(data)
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
        strikes = np.array(option_volatilities.columns[2:])
        expiries = np.array([expiry_date] * len(strikes))
        atm_idx = np.searchsorted(strikes, forward_price)
        c_idx = max(atm_idx-overlapp_idx, 0)
        p_idx = min(atm_idx+overlapp_idx, len(strikes))
        #
        c_vols_mid = smile_volatilities(option_volatilities, 'Call', 'mid')
        c_vols_bid = smile_volatilities(option_volatilities, 'Call', 'bid')
        c_vols_ask = smile_volatilities(option_volatilities, 'Call', 'ask')
        c_vols_up = c_vols_ask - c_vols_mid
        c_vols_do = c_vols_mid - c_vols_bid
        #
        p_vols_mid = smile_volatilities(option_volatilities, 'Put', 'mid')
        p_vols_bid = smile_volatilities(option_volatilities, 'Put', 'bid')
        p_vols_ask = smile_volatilities(option_volatilities, 'Put', 'ask')
        p_vols_up = p_vols_ask - p_vols_mid
        p_vols_do = p_vols_mid - p_vols_bid
        #
        trace = go.Scatter3d(
            x=expiries[c_idx:], y=strikes[c_idx:], z=c_vols_mid[c_idx:],
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
            x=expiries[:p_idx], y=strikes[:p_idx], z=p_vols_mid[:p_idx],
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
