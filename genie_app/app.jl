
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
    act_symbol = "AAPL",
    start_date = Date("2022-04-01"),
    end_date   = Date("2022-07-01"),

)

# initial volatilities

vol_dates_df = OptionSmile.volatility_dates(
    OptionSmile.conn,
    initial_values.act_symbol,
    initial_values.start_date,
    initial_values.end_date
)

(traces1, traces2) = smile_traces(
    OptionSmile.conn,
    initial_values.act_symbol,
    vol_dates_df.date[begin],
    OptionSmile.p2,
)

layout1 = implied_vol_layout(
    initial_values.act_symbol,
    initial_values.start_date,
    "", # x_min_text
    "", # x_max_text
    "", # y_min_text
    "", # y_max_text
)

layout2 = vol_parameter_layout(
    initial_values.act_symbol,
    initial_values.start_date,
    "", # x_min_text
    "", # x_max_text
    "", # y_min_text
    "", # y_max_text
)

# stock prices

traces3 = stock_traces(
    OptionSmile.conn_stocks,
    initial_values.act_symbol,
    initial_values.start_date,
    initial_values.end_date
)

layout3 = stock_layout(initial_values.act_symbol)


# reactive code
@app begin
    @in act_symbol = initial_values.act_symbol
    @in start_date = initial_values.start_date
    @in end_date = initial_values.end_date
    @in vol_date = vol_dates_df.date[begin]
    @in btn_update_range = false
    @in btn_plot_vols = false
    #
    @out volatility_dates = vol_dates_df.date
    #
    @out p1_traces = traces1
    @out p1_layout = layout1
    #
    @out p2_traces = traces2
    @out p2_layout = layout2
    #
    @out p3_traces = traces3
    @out p3_layout = layout3

    #
    @in smoothing = 8
    @in left_extrapolation = "LOGNORMAL"
    @in right_extrapolation = "LINEAR"
    @in extrapolations = [
        "LOGNORMAL",
        "LINEAR",
        "FLAT",
    ]
    #
    @in x_min_text = ""
    @in x_max_text = ""
    @in y1_min_text = ""
    @in y1_max_text = ""
    @in y2_min_text = ""
    @in y2_max_text = ""
    #
    @in btn_x_min_reset = false
    @in btn_x_max_reset = false
    @in btn_y1_min_reset = false
    @in btn_y1_max_reset = false
    @in btn_y2_min_reset = false
    @in btn_y2_max_reset = false
    #
    @out msg = ""
    #
    @onbutton btn_update_range begin
        #
        vol_dates_df = OptionSmile.volatility_dates(
            OptionSmile.conn,
            act_symbol,
            start_date,
            end_date,
        )
        vol_date = vol_dates_df.date[begin]
        #
        (traces1, traces2) = smile_traces(
            OptionSmile.conn,
            act_symbol,
            vol_date,
            OptionSmile.p2,
        )
        layout1 = implied_vol_layout(
            act_symbol,
            vol_date,
            x_min_text,
            x_max_text,
            y1_min_text,
            y1_max_text,
        )
        layout2 = vol_parameter_layout(
            act_symbol,
            vol_date,
            x_min_text,
            x_max_text,
            y2_min_text,
            y2_max_text,
        )
        # #
        traces3 = stock_traces(
            OptionSmile.conn_stocks,
            act_symbol,
            start_date,
            end_date,
        )
        layout3 = stock_layout(act_symbol)
        # update model
        volatility_dates = vol_dates_df.date
        p1_traces = traces1
        p2_traces = traces2
        p3_traces = traces3
        p1_layout = layout1
        p2_layout = layout2
        p3_layout = layout3
        #
        msg = "$act_symbol, $(string(start_date)), $(string(end_date)), $(string(vol_date))"
    end
    #
    @onbutton btn_plot_vols begin
        #
        (traces1, traces2) = smile_traces(
            OptionSmile.conn,
            act_symbol,
            vol_date,
            OptionSmile.p2,
        )
        layout1 = implied_vol_layout(
            act_symbol,
            vol_date,
            x_min_text,
            x_max_text,
            y1_min_text,
            y1_max_text,
        )
        layout2 = vol_parameter_layout(
            act_symbol,
            vol_date,
            x_min_text,
            x_max_text,
            y2_min_text,
            y2_max_text,
        )
        # update model
        p1_traces = traces1
        p2_traces = traces2
        p1_layout = layout1
        p2_layout = layout2
        #
        msg = "$act_symbol, $(string(start_date)), $(string(end_date)), $(string(vol_date))"
    end
    #
    @onbutton btn_x_min_reset begin
        x_min_text = ""
    end
    @onbutton btn_x_max_reset begin
        x_max_text = ""
    end
    @onbutton btn_y1_min_reset begin
        y1_min_text = ""
    end
    @onbutton btn_y1_max_reset begin
        y1_max_text = ""
    end
    @onbutton btn_y2_min_reset begin
        y2_min_text = ""
    end
    @onbutton btn_y2_max_reset begin
        y2_max_text = ""
    end
end

# UI components
function ui()
    [
        h1("Option Smile Modelling"),
        row([
            textfield("Symbol", :act_symbol,
                bgcolor = "green-1",
            ),
            separator(vertical = true),
            datefield("Start date", :start_date,
                datepicker_props = Dict(:todaybtn => false, :nounset => true),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            separator(vertical = true),
            datefield("End date", :end_date,
                datepicker_props = Dict(:todaybtn => false, :nounset => true),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            separator(vertical = true),
            btn("Update range",
                @click(:btn_update_range),
                color = "primary",
                class = "q-mr-sm",
            ),
            separator(vertical = true),
            datefield("Volatility date", :vol_date,
                datepicker_props = Dict(
                    :todaybtn => false,
                    :nounset => true,
                ),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            separator(vertical = true),
            btn("Update volatility",
                @click(:btn_plot_vols),
                color = "primary",
                class = "q-mr-sm",
            ),
        ]),
        row([
            cell([
                plot(:p1_traces, layout=:p1_layout)
            ]),
            cell([
                plot(:p2_traces, layout=:p2_layout)
            ]),
            column([
                b("Smoothing"),
                slider(1:1:10, :smoothing,
                    label = true,
                    markers = true,
                ),
                separator(),
                select(:left_extrapolation,
                    options = :extrapolations,
                    label = "Left extrapolation",
                    useinput = false,
                    multiple = false,
                    clearable = false,
                    filled = true,
                    counter = false,
                    usechips = false,
                ),
                separator(),
                select(:right_extrapolation,
                    options = :extrapolations,
                    label = "Right extrapolation",
                    useinput = false,
                    multiple = false,
                    clearable = false,
                    filled = true,
                    counter = false,
                    usechips = false,
                ),
                separator(),
                row([
                    textfield("x_min", :x_min_text, type = "number"),
                    btn("Reset", @click(:btn_x_min_reset)),
                ]),
                separator(),
                row([
                    textfield("x_max", :x_max_text, type = "number"),
                    btn("Reset", @click(:btn_x_max_reset)),
                ]),
                separator(),
                row([
                    textfield("y_min (left)", :y1_min_text, type = "number"),
                    btn("Reset", @click(:btn_y1_min_reset)),
                ]),
                separator(),
                row([
                    textfield("y_max (left)", :y1_max_text, type = "number"),
                    btn("Reset", @click(:btn_y1_max_reset)),
                ]),
                separator(),
                row([
                    textfield("y_min (right)", :y2_min_text, type = "number"),
                    btn("Reset", @click(:btn_y2_min_reset)),
                ]),
                separator(),
                row([
                    textfield("y_max (right)", :y2_max_text, type = "number"),
                    btn("Reset", @click(:btn_y2_max_reset)),
                ]),
            ]),
        ]),
        cell([
            plot(:p3_traces, layout=:p3_layout)
        ]),
        cell([
            textfield("Debug", :msg )
        ]),
    ]
end

# definition of root route
@page("/", ui)

end # module
