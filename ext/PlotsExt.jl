#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module PlotsExt

import DistributedHyperOpt
import Plots

function Plots.plot(optimization::DistributedHyperOpt.Optimization, args...; 
    ressources::Bool=false, yaxis::Symbol=:log, label_length::Int=12, kwargs...)

    numParams = length(optimization.parameters)
    if ressources
        numParams += 1
    end

    valid_inds = Vector{Int32}()
    for i in 1:length(optimization.minimums)
        minimum = optimization.minimums[i]
        if !isnothing(minimum) && !isnan(minimum) && !isinf(minimum)
            push!(valid_inds, i)
        end
    end

    titleStr = "Min: $(optimization.minimum) | Index: $(optimization.iteration)\n$(optimization.minimizer) | Invalid: $(length(optimization.minimums)-length(valid_inds))"
    fig = Plots.plot(args...; 
        size=(720,480), plot_title=titleStr, plot_titlevspan=0.1, 
        plot_titlefontsize=12, xrotation=90, legend=:none, kwargs...)

    minimums = optimization.minimums[valid_inds]
    minimizers = optimization.minimizers[valid_inds]

    if length(minimums) <= 0
        return fig
    end

    hps = Vector{String}()
    for p in optimization.parameters
        push!(hps, p.name)
    end

    pl = 1
    for m in minimizers
        #vals = collect(h[pl] for h in minimizers)

        plot_kwargs = Dict{Symbol, Union{Symbol, Integer}}()
       
        # if p.type == :Log
        #     # if :Log, activate log-axis
        #     plot_kwargs[:xaxis] = :log
        # elseif p.type == :Discrete
        #     # if :Discrete, convert numbers (if any) to strings for equidistant plotting
        #     vals = collect(length("$(val)") <= label_length ? "$(val)" : "$(val)"[1:label_length] * "..." for val in vals)
        # end

        Plots.plot!(fig, hps, m; 
            yaxis=:none,
            color=:red, linealpha=0.25)
        pl += 1
    end

    # also plot ressources
    if ressources
        ress = optimization.ressources[valid_inds]

        # plot_kwargs = Dict{Symbol, Symbol}()
        # plot_kwargs[:xaxis] = :log
        # plot_kwargs[:yaxis] = yaxis
        # Plots.scatter!(fig[pl], ress, minimums; 
        #     xlabel="Ressource", legend=:none, plot_kwargs...)
        pl += 1
    end

    return fig
end

function Plots.scatter(optimization::DistributedHyperOpt.Optimization, args...; 
    ressources::Bool=false, yaxis::Symbol=:log, label_length::Int=12, kwargs...)

    numPlots = length(optimization.parameters)
    if ressources
        numPlots += 1
    end

    # minIndex = 0
    # for i in 1:length(optimization.minimums)
    #     if optimization.minimums[i] == optimization.minimum 
    #         minIndex = i 
    #         break
    #     end
    # end

    valid_inds = Vector{Int32}()
    for i in 1:length(optimization.minimums)
        minimum = optimization.minimums[i]
        if !isnothing(minimum) && !isnan(minimum) && !isinf(minimum)
            push!(valid_inds, i)
        end
    end

    titleStr = "Min: $(optimization.minimum) | Index: $(optimization.iteration)\n$(optimization.minimizer) | Invalid: $(length(optimization.minimums)-length(valid_inds))"
    fig = Plots.plot(args...; 
        size=(720,720), layout=numPlots, plot_title=titleStr, plot_titlevspan=0.1, plot_titlefontsize=12, kwargs...)

    minimums = optimization.minimums[valid_inds]
    minimizers = optimization.minimizers[valid_inds]

    if length(minimums) <= 0
        return fig
    end

    # @info "minimums:\n$(minimums)"
    # @info "minimizers:\n$(minimizers)"
    # @info "valid_inds:\n$(valid_inds)"

    pl = 1
    for p in optimization.parameters
        vals = collect(h[pl] for h in minimizers)

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
        Plots.scatter!(fig[pl], vals, minimums; 
            xlabel=p.name, legend=:none, plot_kwargs...)
        pl += 1
    end

    # also plot ressources
    if ressources
        ress = optimization.ressources[valid_inds]

        plot_kwargs = Dict{Symbol, Symbol}()
        plot_kwargs[:xaxis] = :log
        plot_kwargs[:yaxis] = yaxis
        Plots.scatter!(fig[pl], ress, minimums; 
            xlabel="Ressource", legend=:none, plot_kwargs...)
        pl += 1
    end

    return fig
end

end # PlotsExt