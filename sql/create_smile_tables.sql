
CREATE TABLE expiry_parameter (
    date date,
    act_symbol varchar(10),
    expiration date,
    price float,
    expiry_time float,
    normal_volatility float,
    log_volatility float,
    rexl varchar(10),
    rexu varchar(10),
    alpha float,
    PRIMARY KEY (
        date,
        act_symbol,
        expiration
    )
);

CREATE TABLE smile_parameter (
    date date,
    act_symbol varchar(10),
    expiration date,
    relative_strike decimal(7,4),
    volatility_offset float,
    PRIMARY KEY (
        date,
        act_symbol,
        expiration,
        relative_strike
    )
);
