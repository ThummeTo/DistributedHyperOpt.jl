#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function Plots.plot(optimization::Optimization, args...; kwargs...)
    fig = Plots.plot(args...; size=(720,560), layout=length(optimization.parameters), kwargs...)

    pl = 1
    for p in optimization.parameters

        vals = collect(h[pl] for h in optimization.minimizers)

        plot_kwargs = Dict{Symbol, Any}()
        if p.type == :Log     
            # if :Log, activate log-axis
            plot_kwargs[:xaxis] = :log
        elseif p.type == :Discrete 
            # if :Discrete, convert numbers (if any) to strings for equidistant plotting
            vals = collect("$(val)" for val in vals)
        end
        Plots.scatter!(fig[pl], vals, optimization.minimums; xlabel=p.name, legend=:none, yaxis=:log, plot_kwargs...)
        pl += 1
    end

    return fig
end

function plot(optimization::Optimization, args...; kwargs...)
    Plots.plot(optimization::Optimization, args...; kwargs...)
end

function savefig(args...; kwargs...)
    Plots.savefig(args...; kwargs...)
end