
The *Option Smile Modelling* app displays and interpolates implied volatilities for stock options.

### Analytics

The **Implied volatility** plot (top-left plot) displays implied log-normal volatilities for about three option expires. Data is illustrated for a given observation date (see *Volatility date* below) and symbol.

Option-implied volatilities are displayed for bid/mid/ask prices of call (C) and put (P) options. Solid green lines represent the model-implied volatilities derived from our [piece-wise option pricing model](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5214566).

The **Volatility model parameter** plot (top-right plot) displays calibrated volatility model parameters. The model parameters are calibrated such that option-implied volatilities are matched *as close as possible*.

Note that the volatility model parameters are conceptually different from the implied volatilities. The parameters are ingredients of the piece-wise option pricing model. Details and properties of the model parameters can be controlled via the smoothing and extrapolation properties.

The **Stock price plot** displays open/high/low/close prices of the stock for the selected symbol and the date range. Stock prices are shown to visually link volatility moves to market moves.

### Usage

Select a stock via the **Symbol** dropdown list. The app covers most of the S&P 500 index constituents.

Select a start date for the simulation time series via the **Start date** field. The app contains data since 2020.

Select an end date for the simulation time series via the **End date** field. The period between start date and end date should not be larger than about three months to limit memory and calculation resources.

Use the **Update range** button to calculate and display the stock price data (lower plot) for the selected symbol, start date and end date. This function also calculates the dates for volatility simulation.

Select a date for ad-hoc volatility plotting via the **Volatility date** field. This field is reset to the start date after an update of the simulation time series.

Use the **Update volatility** button to calibrate smile models and display implied volatilities for the selected *Volatility date*.

Use the **Simulate volatility** button to run model calibration and volatility display for available dates between start date and end date. The simulation can be interrupted and stopped via the **Stop** button.

#### Piece-wise Model Calibration Properties

Piece-wise option pricing model calibration can be controlled by the smoothing and extrapolation parameters in the right panel.

The **Smoothing** property controls the smoothness of the volatility model parameters during model calibration. A smaller smoothing value puts more weight on fitting option-implied volatility data. Resulting volatility model parameters can show pronounced spikes. A larger smoothing value puts more weight on smooth and stable volatility parameters at the expense of a (slightly) deteriorated volatility fit.

The **Left extrapolation** and **Right extrapolation** properties control the modelling of the tails of the stock price distribution. A *LOGNORMAL* value yield a log-normal tail distribution. A *NORMAL* value yields a normal tail distribution. For the value *LINEAR*, the volatility model parameters are extrapolated linearly. This choice yields a shifted log-normal tail distribution.

#### Plotting Properties

The ranges of the volatility plots can be controlled by the fields **x_min**, **x_max**, **y_min (left)**, **y_max (left)**, **y_min (right)** and **y_max (right)**.

The plot range fields may be left empty, e.g., via a **Clear** button. In that case the plot range is adjusted to the plot data.

### Data and Methodology

We use input data for option prices, stock prices, dividends and interest rates from [dolthub / post-no-preference](https://www.dolthub.com/users/post-no-preference/repositories).

Option prices are converted to implied forwards and implied volatilities using [QuantLib (Python)](https://github.com/lballabio). Resulting data is stored at [dolthub](https://www.dolthub.com/repositories/sschlenkrich/volatilities). Details on the conversion methodology are stated at the data repository.

The [piece-wise option pricing model](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5214566) is implemented in the [Julia](https://julialang.org) package [PiecewiseVanillaModel.jl](https://github.com/sschlenkrich/PiecewiseVanillaModel.jl). The calibration methodology for this app is specified [here](https://github.com/sschlenkrich/OptionSmile/blob/main/julia/calibration.jl).


### Solution Stack

The app source code is available at [GitHub](https://github.com/sschlenkrich/OptionSmile).

We use a stack of open source technology components.

| Component | Usage        |
| --------- | ------------ |
| [Genieframework](https://genieframework.com) | Web app development |
| [Julia](https://julialang.org) | Piece-wise option pricing model implementation and calibration | 
| [QuantLib (Python)](https://github.com/lballabio) | Calculate option-implied forwards and volatilities |
| [dolt](https://www.dolthub.com) | Version-controlled database and database server |
| [docker](https://hub.docker.com) | Containerisation and deployment |
