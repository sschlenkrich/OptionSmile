CREATE TABLE forwardprice (
    date date,
    act_symbol varchar(10),
    expiration date,
    price float,
    PRIMARY KEY (
        date,
        act_symbol,
        expiration
    )
);

CREATE TABLE volatility (
    date date,
    act_symbol varchar(10),
    expiration date,
    strike decimal(7,2),
    call_put varchar(4),
    mid float,
    bid float,
    ask float,
    PRIMARY KEY (
        date,
        act_symbol,
        expiration,
        strike,
        call_put
    )
);
