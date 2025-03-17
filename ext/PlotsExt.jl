#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module PlotsExt

import DistributedHyperOpt
import Plots

function Plots.plot(optimization::DistributedHyperOpt.Optimization, args...; ressources::Bool=false, yaxis::Symbol=:log, kwargs...)

    # ToDo

    return Plots.scatter(optimization, args...; ressources=ressources, yaxis=yaxis, kwargs...)
end

function Plots.scatter(optimization::DistributedHyperOpt.Optimization, args...; ressources::Bool=false, yaxis::Symbol=:log, label_length::Int=12, kwargs...)

    numPlots = length(optimization.parameters)
    if ressources
        numPlots += 1
    end

    minIndex = 0
    for i in 1:length(optimization.minimums)
        if optimization.minimums[i] == optimization.minimum 
            minIndex = i 
            break
        end
    end

    titleStr = "Min: $(optimization.minimum) | Index: $(minIndex)\n$(optimization.minimizer)"
    fig = Plots.plot(args...; size=(720,720), layout=numPlots, plot_title=titleStr, plot_titlevspan=0.1, plot_titlefontsize=12, kwargs...)

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

end # PlotsExt