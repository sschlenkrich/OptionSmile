
module OptionSmile
    include("../julia/option_smile.jl")
end

module App

#setup of the Genie Framework environment
using GenieFramework
using StippleMarkdown

@genietools  # should come after above using GenieFramework

import PlotlyBase
import ..OptionSmile   # re-use data and model calibration

include("src/plots.jl")
include("src/model.jl")

# initialise input variables

const initial_values = (
    act_symbol = "AAPL, Apple Inc.",
    start_date = Dates.today() - Dates.Month(2),
    end_date   = Dates.today(),
    smoothing  = 6,
    rexl = "LOGNORMAL",
    rexu = "LOGNORMAL",
    extrapolations = [
        "LOGNORMAL",
        "LINEAR",
        "FLAT",
    ],
)

# volatility dates for simulation

short(s::String) = split(s, ",")[begin]

as_text(v::Vector{Date}) = [ Dates.format(d, dateformat"yyyy/mm/dd") for d in v ]

const symbols_df = OptionSmile.sp500()
const symbol_labels = sort([ a * ", " * b for (a, b) in zip(symbols_df.Symbol, symbols_df.Security) ])

const vol_dates_df = OptionSmile.volatility_dates(
    OptionSmile.conn,
    short(initial_values.act_symbol),
    initial_values.start_date,
    initial_values.end_date
)

# stock prices

const stock_trace_tuple = stock_traces(
    OptionSmile.conn_stocks,
    short(initial_values.act_symbol),
    initial_values.start_date,
    initial_values.end_date
)
const traces3 = stock_trace_tuple.traces
const p_ranges = plot_ranges(
    stock_trace_tuple.min_price,
    stock_trace_tuple.max_price
)

const layout3 = stock_layout(initial_values.act_symbol)

# initial volatilities

const model_param = model_parameter(
    initial_values.smoothing,
    initial_values.rexl,
    initial_values.rexu,
)

const (traces1, traces2) = smile_traces(
    OptionSmile.conn,
    short(initial_values.act_symbol),
    vol_dates_df.date[begin],
    model_param,
)

const layout1 = implied_vol_layout(
    short(initial_values.act_symbol),
    initial_values.start_date,
    p_ranges.x_min_text,
    p_ranges.x_max_text,
    p_ranges.y1_min_text,
    p_ranges.y1_max_text,
)

const layout2 = vol_parameter_layout(
    short(initial_values.act_symbol),
    initial_values.start_date,
    model_param,
    p_ranges.x_min_text,
    p_ranges.x_max_text,
    p_ranges.y2_min_text,
    p_ranges.y2_max_text,
)

const home_markdown = read(open("markdown/home.md", "r"), String)
const docs_markdown = read(open("markdown/docs.md", "r"), String)

# reactive code
@app begin
    @in tab_selected = "home"
    @in btn_go_to_analytics = false
    #
    @in act_symbol = initial_values.act_symbol
    @in start_date = initial_values.start_date
    @in end_date = initial_values.end_date
    @in vol_date = vol_dates_df.date[begin]
    @in btn_update_range = false
    @in btn_plot_vols = false
    @in btn_simulate = false
    @in btn_simulate_stop = false
    #
    @in btn_simulate_stop_disabled = false
    @in is_simulating = false
    @in stop_simulating = false
    #
    @out volatility_dates = vol_dates_df.date
    @out volatility_dates_fmt = as_text(vol_dates_df.date)
    @out min_stock_price = stock_trace_tuple.min_price
    @out max_stock_price = stock_trace_tuple.max_price
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
    @in smoothing = initial_values.smoothing
    @in left_extrapolation = initial_values.rexl
    @in right_extrapolation = initial_values.rexu
    @in extrapolations = initial_values.extrapolations
    #
    @in x_min_text = p_ranges.x_min_text
    @in x_max_text = p_ranges.x_max_text
    @in y1_min_text = p_ranges.y1_min_text
    @in y1_max_text = p_ranges.y1_max_text
    @in y2_min_text = p_ranges.y2_min_text
    @in y2_max_text = p_ranges.y2_max_text
    #
    @in btn_x_min_reset = false
    @in btn_x_max_reset = false
    @in btn_y1_min_reset = false
    @in btn_y1_max_reset = false
    @in btn_y2_min_reset = false
    @in btn_y2_max_reset = false
    #
    @out msg = "Started."
    #
    @onbutton btn_go_to_analytics begin
        tab_selected = "analytics"
    end
    #
    @onchange start_date begin
        if start_date > end_date
            end_date = start_date
            msg = "Adjust end date to $(string(end_date))."
        end
    end
    @onchange end_date begin
        if end_date < start_date
            start_date = end_date
            msg = "Adjust start date to $(string(start_date))."
        end
    end
    #
    @onbutton btn_update_range begin
        local status = ""
        try
            vol_dates_df = OptionSmile.volatility_dates(
                OptionSmile.conn,
                short(act_symbol),
                start_date,
                end_date,
            )
            vol_date = vol_dates_df.date[begin]
            #
            trace_tuple = stock_traces(
                OptionSmile.conn_stocks,
                short(act_symbol),
                start_date,
                end_date,
            )
            layout3 = stock_layout(act_symbol)
            p_ranges = plot_ranges(
                trace_tuple.min_price,
                trace_tuple.max_price,
            )
            x_min_text = p_ranges.x_min_text
            x_max_text = p_ranges.x_max_text
            y1_min_text = p_ranges.y1_min_text
            y1_max_text = p_ranges.y1_max_text
            y2_min_text = p_ranges.y2_min_text
            y2_max_text = p_ranges.y2_max_text
            #
            model_param = model_parameter(
                smoothing,
                left_extrapolation,
                right_extrapolation,
            )
            #
            (traces1, traces2) = smile_traces(
                OptionSmile.conn,
                short(act_symbol),
                vol_date,
                model_param,
            )
            layout1 = implied_vol_layout(
                short(act_symbol),
                vol_date,
                x_min_text,
                x_max_text,
                y1_min_text,
                y1_max_text,
            )
            layout2 = vol_parameter_layout(
                short(act_symbol),
                vol_date,
                model_param,
                x_min_text,
                x_max_text,
                y2_min_text,
                y2_max_text,
            )
            # update model
            volatility_dates = vol_dates_df.date
            volatility_dates_fmt = as_text(vol_dates_df.date)
            p1_traces = traces1
            p2_traces = traces2
            p3_traces = trace_tuple.traces
            p1_layout = layout1
            p2_layout = layout2
            p3_layout = layout3
            #
            min_stock_price = trace_tuple.min_price
            max_stock_price = trace_tuple.max_price
            #
            status = "Update range: "
            status = status * "$act_symbol, $(string(start_date)), $(string(end_date)), $(string(vol_date)), "
            status = status * "$(string(min_stock_price)), $(string(max_stock_price)), "
            status = status * "$(string(length(volatility_dates)))."
        catch
            status = "Error. Cannot update range for $act_symbol, $(string(start_date)), $(string(end_date))."
        end
        msg = status
    end
    #
    @onbutton btn_plot_vols begin
        local status = ""
        try
            model_param = model_parameter(
                smoothing,
                left_extrapolation,
                right_extrapolation,
            )
            #
            (traces1, traces2) = smile_traces(
                OptionSmile.conn,
                short(act_symbol),
                vol_date,
                model_param,
            )
            layout1 = implied_vol_layout(
                short(act_symbol),
                vol_date,
                x_min_text,
                x_max_text,
                y1_min_text,
                y1_max_text,
            )
            layout2 = vol_parameter_layout(
                short(act_symbol),
                vol_date,
                model_param,
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
            status = "Update volatility: "
            status = status * "$act_symbol, $(string(vol_date))."
        catch
            status = "Error. Cannot update volatility for $act_symbol, $(string(vol_date))."
        end
        msg = status
    end
    #
    @onbutton btn_simulate begin
        msg = "Simulate..."
        btn_simulate_stop_disabled = false
        is_simulating = true
        Threads.@spawn begin
            model_param = model_parameter(
                smoothing,
                left_extrapolation,
                right_extrapolation,
            )
            for date in volatility_dates
                if stop_simulating
                    break
                end
                local status = ""
                try
                    t1 = Threads.@spawn smile_traces(
                        OptionSmile.conn,
                        short(act_symbol),
                        date,
                        model_param,
                    )
                    t2 = Threads.@spawn implied_vol_layout(
                        short(act_symbol),
                        date,
                        x_min_text,
                        x_max_text,
                        y1_min_text,
                        y1_max_text,
                    )
                    t3 = Threads.@spawn vol_parameter_layout(
                        short(act_symbol),
                        date,
                        model_param,
                        x_min_text,
                        x_max_text,
                        y2_min_text,
                        y2_max_text,
                    )
                    t4 = Threads.@spawn obs_date_trace(date, min_stock_price, max_stock_price)
                    sleep(1.0)
                    (traces1, traces2) = fetch(t1)
                    layout1 = fetch(t2)
                    layout2 = fetch(t3)
                    trace3 = fetch(t4)
                    # update model
                    p1_traces = traces1
                    p2_traces = traces2
                    p1_layout = layout1
                    p2_layout = layout2
                    p3_traces = [ p3_traces[1], trace3 ]
                    #
                    status = "Simulate volatilities: $act_symbol, $(string(date))."
                catch
                    status = "Error. Cannot simulate volatilities for $act_symbol, $(string(date))."
                end
                msg = status
            end
            stop_simulating = false
            btn_simulate_stop_disabled = true
            is_simulating = false
        end
        #
    end
    #
    @onbutton btn_simulate_stop begin
        stop_simulating = true
        btn_simulate_stop_disabled = true
        is_simulating = false
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

# Stipple.render(d::Date) = Dates.format(d, dateformat"YYYY/mm/dd")

function ui()
    [
        h1("Option Smile Modelling"),
        tabgroup(
            :tab_selected,
            [
                tab(name = "home", icon = "home", label = "Home"),
                tab(name = "analytics", icon = "analytics", label = "Analytics"),
                tab(name = "documentation", icon = "read_more", label = "Docs"),
            ],
            # inlinelabel = true,
            # class = "bg-primary text-white shadow-2",
        ),
        tabpanels(
            :tab_selected,
            [
                tabpanel(home(), name = "home",),
                tabpanel(analytics(), name = "analytics", ),
                tabpanel(documentation(), name = "documentation", ),
            ],
            # animated = true,
            # var"transition-prev" = "scale",
            # var"transition-next" = "scale",
        ),
        separator(),
        cell([
            p(center([
                "Powered by ",
                a("FRAME Consulting", href="https://www.frame-consult.de"),
                ", Berlin   |   ",
                a("Imprint", href="https://en.frame-consult.de/Imprint.html"),
                "   |   ",
                a("Data privacy policy", href="https://en.frame-consult.de/Data_privacy_policy.html"),
            ]))
        ]),
    ]
end


function analytics()
    [
        row([
            select(:act_symbol,
                options = symbol_labels,
                label = "Symbol",
                useinput = false,
                multiple = false,
                clearable = false,
                filled = true,
                counter = false,
                usechips = false,
                bgcolor = "green-1",
            ),
            separator(vertical = true),
            datefield("Start date", :start_date,
                datepicker_props = Dict(:todaybtn => false, :nounset => true,),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            separator(vertical = true),
            datefield("End date", :end_date,
                datepicker_props = Dict(:todaybtn => true, :nounset => true,),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            separator(vertical = true),
            btn("Update range",
                @click(:btn_update_range),
                loading = :btn_update_range,
                disable = :is_simulating,
                color = "primary",
                class = "q-mr-sm",
            ),
            separator(vertical = true),
            datefield("Volatility date", :vol_date,
                datepicker_props = Dict(
                    :todaybtn => false,
                    :nounset => true,
                    :options => :volatility_dates_fmt,
                ),
                textfield_props = Dict(:bgcolor => "green-1"),
            ),
            separator(vertical = true),
            btn("Update volatility",
                @click(:btn_plot_vols),
                loading = :btn_plot_vols,
                disable = :is_simulating,
                color = "primary",
                class = "q-mr-sm",
            ),
            separator(vertical = true),
            btn("Simulate volatility",
                @click(:btn_simulate),
                loading = :is_simulating,
                color = "primary",
                class = "q-mr-sm",
            ),
            separator(vertical = true),
            btn("Stop",
                @click(:btn_simulate_stop),
                disable = :btn_simulate_stop_disabled,
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
                    textfield("x_min", :x_min_text, type = "number", step = 10),
                    btn("Clear", @click(:btn_x_min_reset)),
                ]),
                separator(),
                row([
                    textfield("x_max", :x_max_text, type = "number", step = 10),
                    btn("Clear", @click(:btn_x_max_reset)),
                ]),
                separator(),
                row([
                    textfield("y_min (left)", :y1_min_text, type = "number", step = 10),
                    btn("Clear", @click(:btn_y1_min_reset)),
                ]),
                separator(),
                row([
                    textfield("y_max (left)", :y1_max_text, type = "number", step = 10),
                    btn("Clear", @click(:btn_y1_max_reset)),
                ]),
                separator(),
                row([
                    textfield("y_min (right)", :y2_min_text, type = "number", step = 10),
                    btn("Clear", @click(:btn_y2_min_reset)),
                ]),
                separator(),
                row([
                    textfield("y_max (right)", :y2_max_text, type = "number", step = 10),
                    btn("Clear", @click(:btn_y2_max_reset)),
                ]),
            ]),
        ]),
        cell([
            plot(:p3_traces, layout=:p3_layout)
        ]),
        cell([
            textfield("Status", :msg )
        ]),
    ]
end


function home()
    [
        markdowntext(home_markdown),
        cell(center([
            btn("Go to Analytics",
                @click(:btn_go_to_analytics),
                color = "primary",
                class = "q-mr-sm",
            ),
        ])),
    ]
end


function documentation()
    [
        markdowntext(docs_markdown),
    ]
end

meta = Dict(
    "og:title" => "Option Smile Modelling",
    "og:description" => "Interpolate implied volatilities for US stock options.",
    "og:image" => "/preview.jpg",
)
layout = DEFAULT_LAYOUT(
    meta = meta,
    title = "Option Smile Modelling",
)

# definition of root route
@page("/", ui, layout = layout)

end # module
