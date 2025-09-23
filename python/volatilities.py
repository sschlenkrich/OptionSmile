
import numpy as np
import QuantLib as ql

from dateutils import ql_date


def implied_volatilities(
    date,
    spot_price,
    yield_curve,
    dividend_dates,
    dividend_values,
    dividens_yield,
    expiry_date,
    strike_prices,
    option_prices,
    call_put,
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
    div_rate = ql.QuoteHandle(ql.SimpleQuote(dividens_yield))
    div_ytsh = ql.YieldTermStructureHandle(ql.FlatForward(date, div_rate, ql.Actual365Fixed()))
    #
    S0 = ql.QuoteHandle(ql.SimpleQuote(spot_price))
    process = ql.GeneralizedBlackScholesProcess(
        S0, div_ytsh, yield_curve, vol_tsh
    )
    #
    exercise = ql.AmericanExercise(date, expiry_date)
    options = [
        ql.VanillaOption(ql.PlainVanillaPayoff(call_put, strike), exercise)
        for strike in strike_prices
    ]
    implied_vols = []
    for option, option_price in zip(options, option_prices):
        try:
            v = option.impliedVolatility(option_price, process, dividend_schedule)
        except:
            v = np.nan
        implied_vols.append(v)
    #
    return np.array(implied_vols)
