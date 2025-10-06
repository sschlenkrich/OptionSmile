
CREATE VIEW smile AS
SELECT a.date, a.act_symbol, a.expiration, a.price,
       b.strike, b.call_put, b.mid, b.bid, b.ask
FROM forwardprice a inner join volatility b
on
  a.date = b.date
  and a.act_symbol = b.act_symbol
  and a.expiration = b.expiration
  and b.mid > 0.01
  and b.bid > 0.01
  and b.ask > 0.01
  and (b.call_put = 'Call' or b.strike < a.price)
  and (b.call_put = 'Put' or b.strike >= a.price)
;
