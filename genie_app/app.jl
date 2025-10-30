
module OptionSmile
    include("../julia/option_smile.jl")
end

module App

#setup of the Genie Framework environment
using GenieFramework
@genietools  # should come after above using GenieFramework

import PlotlyBase
import ..OptionSmile   # re-use data and model calibration

include("src/plots.jl")

# initialise input variables

initial_values = (
    symbol     = "AAPL",
    start_date = Date("2022-04-01"),
    end_date   = Date("2022-07-01"),
    vol_date   = Date("2022-04-01"),
)

trace1 = stock_trace(
    OptionSmile.conn_stocks,
    initial_values.symbol,
    initial_values.start_date,
    initial_values.end_date
)

layout1 = PlotlyBase.Layout(
    title="Stock price " * initial_values.symbol,
    xaxis=PlotlyBase.attr(
        title="date",
        showgrid=true
    ),
    yaxis=PlotlyBase.attr(
        title="price",
        showgrid=true,
    )
)

(traces2, traces3) = smile_traces(
    OptionSmile.conn,
    initial_values.symbol,
    initial_values.vol_date,
    OptionSmile.p2,
)

layout2 = PlotlyBase.Layout(
    title="Implied volatility $(initial_values.symbol), $(string(initial_values.start_date))",
    xaxis=PlotlyBase.attr(
        title="strike",
        showgrid=true
    ),
    yaxis=PlotlyBase.attr(
        title="volatility (%)",
        showgrid=true,
    )
)

layout3 = PlotlyBase.Layout(
    title="Volatility model parameters",
    xaxis=PlotlyBase.attr(
        title="strike",
        showgrid=true
    ),
    yaxis=PlotlyBase.attr(
        title="abs volatility (price)",
        showgrid=true,
    )
)

# reactive code
@app begin
    @in symbol = initial_values.symbol
    @in start_date = initial_values.start_date
    @in end_date = initial_values.end_date
    @in vol_date = initial_values.vol_date
    @in button_process = false
    #
    @out msg = ""
    @out p1_traces = [trace1, ]
    @out p1_layout = layout1
    #
    @out p2_traces = traces2
    @out p2_layout = layout2
    #
    @out p3_traces = traces3
    @out p3_layout = layout3
    #
    @onbutton button_process begin
        msg = "$symbol, $(string(start_date)), $(string(end_date)), $(string(vol_date))"
        #
        p1_traces = [stock_trace(
            OptionSmile.conn_stocks,
            symbol,
            start_date,
            end_date,
        ), ]
        p1_layout = PlotlyBase.Layout(
            title="Stock price " * symbol,
            xaxis=PlotlyBase.attr(
                title="date",
                showgrid=true
            ),
            yaxis=PlotlyBase.attr(
                title="price",
                showgrid=true,
            )
        )
        #
        (traces2, traces3) = smile_traces(
            OptionSmile.conn,
            symbol,
            vol_date,
            OptionSmile.p2,
        )
        p2_traces = traces2
        p3_traces = traces3
        #
        p2_layout = PlotlyBase.Layout(
            title="Implied volatility $(symbol), $(string(vol_date))",
            xaxis=PlotlyBase.attr(
                title="strike",
                showgrid=true,
            ),
            yaxis=PlotlyBase.attr(
                title="volatility (%)",
                showgrid=true,
            )
        )
    end
end

# UI components
function ui()
    [
        h1("Option Smile Modelling")
        row([
            textfield("Symbol", :symbol ),
            datefield("Start date", :start_date,
                datepicker_props = Dict(:todaybtn => false, :nounset => true),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            datefield("End date", :end_date,
                datepicker_props = Dict(:todaybtn => false, :nounset => true),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            btn("Process",
                @click(:button_process),
                color = "primary",
                class = "q-mr-sm",
            ),
            datefield("Volatility date", :vol_date,
                datepicker_props = Dict(:todaybtn => false, :nounset => true),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
        ])
        row([
            cell([
                plot(:p2_traces, layout=:p2_layout)
            ]),
            cell([
                plot(:p3_traces, layout=:p3_layout)
            ])
        ])
        cell([
            textfield("Debug", :msg )
        ])
        cell([
            plot(:p1_traces, layout=:p1_layout)
        ])
    ]
end

# definition of root route
@page("/", ui)

end # module
