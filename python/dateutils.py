
import QuantLib as ql

def ql_date(date):
    if type(date) == ql.Date:
        return date
    if type(date) != str:
        date = date.isoformat()
    return ql.Date(date[:10], 'YYYY-MM-DD')

def iso_date(date):
    if type(date) == str:
        return date
    if type(date) == ql.Date:
        return date.ISO()
    #
    return date.isoformat()

def months(period):
    if type(period) != ql.Period:
        period = ql.Period(period)
    months_per_unit = 0
    if period.units() == ql.Days:
        months_per_unit = 1.0 / 30
    if period.units() == ql.Weeks:
        months_per_unit = 1.0 / 4
    if period.units() == ql.Months:
        months_per_unit = 1
    if period.units() == ql.Years:
        months_per_unit = 12
    return period.length() * months_per_unit

