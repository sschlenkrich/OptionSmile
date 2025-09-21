
import numpy as np
import QuantLib as ql
import scipy


from dateutils import ql_date

def implied_forward(
    date,
    spot_price,
    yield_curve,
    dividend_dates,
    dividend_values,
    expiry_date,
    strike_price,
    call_price,
    put_price,
    div_rate_min = -0.05,
    div_rate_max = 0.05,
    ):
    #
    date = ql_date(date)
    expiry_date = ql_date(expiry_date)
    assert yield_curve.referenceDate() == date
    dividend_dates = [ ql_date(d) for d in dividend_dates ]
    dividend_values = [ float(v) for v in dividend_values ]
    dividend_schedule = ql.DividendSchedule(ql.DividendVector(
        dividend_dates, dividend_values
    ))
    #
    ql.Settings.instance().evaluationDate = date
    cal = ql.UnitedStates(ql.UnitedStates.GovernmentBond)
    #
    vol0 = 0.15  # initial guess
    volatility = ql.RelinkableQuoteHandle(ql.SimpleQuote(vol0))
    vol_ts = ql.BlackConstantVol(date, cal, volatility, ql.Actual365Fixed())
    vol_tsh = ql.BlackVolTermStructureHandle(vol_ts)
    #
    div0 = -0.05  # initial guess
    div_rate = ql.RelinkableQuoteHandle(ql.SimpleQuote(div0))
    div_ytsh = ql.YieldTermStructureHandle(ql.FlatForward(date, div_rate, ql.Actual365Fixed()))
    #
    S0 = ql.QuoteHandle(ql.SimpleQuote(spot_price))
    process = ql.GeneralizedBlackScholesProcess(
        S0, div_ytsh, yield_curve, vol_tsh
    )
    #
    exercise = ql.AmericanExercise(date, expiry_date)
    call_option = ql.VanillaOption(
        ql.PlainVanillaPayoff(ql.Option.Call, strike_price),
        exercise,
    )
    put_option = ql.VanillaOption(
        ql.PlainVanillaPayoff(ql.Option.Put, strike_price),
        exercise,
    )
    #
    def objective_f(div1):
        div_rate.linkTo(ql.SimpleQuote(div1))
        v_c = call_option.impliedVolatility(call_price, process, dividend_schedule)
        v_p = put_option.impliedVolatility(put_price, process, dividend_schedule)
        return v_c - v_p
    #
    div1 = scipy.optimize.brentq(
        objective_f, div_rate_min, div_rate_max,
    )
    #
    spot_adjustment = 0.0
    for d, v in zip(dividend_dates, dividend_values):
        if d <= expiry_date:
            spot_adjustment += v * yield_curve.discount(d) / div_ytsh.discount(d)
    #
    forward_price = (spot_price - spot_adjustment) * div_ytsh.discount(expiry_date) / yield_curve.discount(expiry_date)
    return float(forward_price), div1


def implied_forward_from_smile(
    date,
    spot_price,
    yield_curve,
    dividend_dates,
    dividend_values,
    expiry_date,
    strike_prices,
    call_prices,
    put_prices,
    div_rate_min = -0.05,
    div_rate_max = 0.05,
    ):
    #
    assert len(strike_prices) > 0
    assert strike_prices.shape == call_prices.shape
    assert strike_prices.shape == put_prices.shape
    #
    def forward(strike_price, call_price, put_price):
        return implied_forward(
            date,
            spot_price,
            yield_curve,
            dividend_dates,
            dividend_values,
            expiry_date,
            strike_price,
            call_price,
            put_price,
            div_rate_min,
            div_rate_max,
        )
    #
    if len(strike_prices) == 1:
        return forward(strike_prices[0], call_prices[0], put_prices[0])
    #
    if len(strike_prices) == 2:
        s0, d0 = forward(strike_prices[0], call_prices[0], put_prices[0])
        s1, d1 = forward(strike_prices[1], call_prices[1], put_prices[1])
        s_mid = 0.5 * (s0 + s1)
        d_mid = 0.5 * (d0 + d1)
        if s_mid < strike_prices[0]:
            return s0, d0
        if s_mid > strike_prices[1]:
            return s1, d1
        #
        return s_mid, d_mid
    # iterate...
    s0 = spot_price
    iters = 0
    max_iters = 2
    while True:
        iters += 1
        #
        idx_0 = np.searchsorted(strike_prices, s0)
        if idx_0 == 0:
            s0, d0 = forward(strike_prices[0], call_prices[0], put_prices[0])
        elif idx_0 == len(strike_prices):
            s0, d0 = forward(strike_prices[-1], call_prices[-1], put_prices[-1])
        else:
            s0, d0 = implied_forward_from_smile(
                date,
                spot_price,
                yield_curve,
                dividend_dates,
                dividend_values,
                expiry_date,
                strike_prices[idx_0-1:idx_0],
                call_prices[idx_0-1:idx_0],
                put_prices[idx_0-1:idx_0],
                div_rate_min,
                div_rate_max,
            )
        #
        idx_1 = np.searchsorted(strike_prices, s0)
        if (idx_1 == idx_0) or (iters > max_iters):
            return s0, d0
    # we should have returned earlier
    
