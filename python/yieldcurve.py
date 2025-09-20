
import numpy as np
import QuantLib as ql

import data
from dateutils import iso_date, ql_date, months


def continuous_rate(semi_anual_rate, months):
    if months <= 6:
        cont_rates = np.log(1.0 + semi_anual_rate * months / 12.0) / (months / 12.0)
    else:
        cont_rates = np.log(np.power(1.0 + semi_anual_rate/2.0, 2 * months / 12)) / (months / 12.0)
    return cont_rates

def yield_curve(date):
    df = data.interest_rates(iso_date(date))
    assert df.shape[0] == 1 
    maturity_periods = [ ql.Period(t) for t in df.columns[1:] ]
    maturity_months = [ months(p) for p in maturity_periods ]
    semi_anual_rates = df.iloc[0].values[1:]
    cont_rates = [ 
        float(continuous_rate(r/100.0, m))
        for (r, m) in zip(semi_anual_rates, maturity_months)
    ]
    cal = ql.UnitedStates(ql.UnitedStates.GovernmentBond)
    ref_date = ql_date(date)
    maturity_dates = [
        cal.advance(ref_date, p, ql.Following)
        for p in maturity_periods
    ]
    # reference date is the first date entry
    maturity_dates = [ ref_date ] + maturity_dates
    # apply constant extrapolation
    cont_rates = cont_rates[0:1] + cont_rates
    # InterpolatedZeroCurve<Linear>
    yc = ql.ZeroCurve(maturity_dates, cont_rates, ql.Actual365Fixed())
    ytsh = ql.YieldTermStructureHandle(yc)
    return ytsh
