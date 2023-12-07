#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function Plots.plot(optimization::Optimization, args...; ressources::Bool=false, yaxis::Symbol=:log, kwargs...)

    # ToDo

    return Plots.scatter(optimization, args...; ressources=ressources, yaxis=yaxis, kwargs...)
end

function Plots.scatter(optimization::Optimization, args...; ressources::Bool=false, yaxis::Symbol=:log, label_length::Int=12, kwargs...)

    numPlots = length(optimization.parameters)
    if ressources
        numPlots += 1
    end

    fig = Plots.plot(args...; size=(720,560), layout=numPlots, kwargs...)

    pl = 1
    for p in optimization.parameters

        vals = collect(h[pl] for h in optimization.minimizers)

        plot_kwargs = Dict{Symbol, Union{Symbol, Integer}}()
        plot_kwargs[:yaxis] = yaxis
        if p.type == :Log     
            # if :Log, activate log-axis
            plot_kwargs[:xaxis] = :log
        elseif p.type == :Discrete 
            # if :Discrete, convert numbers (if any) to strings for equidistant plotting
            plot_kwargs[:xrotation] = 90
            vals = collect(length("$(val)") <= label_length ? "$(val)" : "$(val)"[1:label_length] * "..." for val in vals)
        end
        Plots.scatter!(fig[pl], vals, optimization.minimums; xlabel=p.name, legend=:none, plot_kwargs...)
        pl += 1
    end

    # also plot ressources
    if ressources
        vals = optimization.ressources

        plot_kwargs = Dict{Symbol, Symbol}()
        plot_kwargs[:xaxis] = :log
        plot_kwargs[:yaxis] = yaxis
        Plots.scatter!(fig[pl], vals, optimization.minimums; xlabel="Ressource", legend=:none, plot_kwargs...)
        pl += 1
    end

    return fig
end

function plot(optimization::Optimization, args...; kwargs...)
    Plots.plot(optimization::Optimization, args...; kwargs...)
end

function scatter(optimization::Optimization, args...; kwargs...)
    Plots.scatter(optimization::Optimization, args...; kwargs...)
end

function savefig(args...; kwargs...)
    Plots.savefig(args...; kwargs...)
end