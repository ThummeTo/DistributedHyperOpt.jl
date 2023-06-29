#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module DistributedHyperOpt

using Distributed
using Requires

# redirects all process i/o to file (so the REPL is not spamed)
function redirect_printing(logfile, fun, args...; kwargs...)
    ret = nothing
    pid = myid()

    @debug "Opening log file @ `$(logfile)` for process #$(pid)"
    
        open(logfile, "w") do io
        redirect_stdout(io) do
            redirect_stderr(io) do

                try
                    ret = fun(args...; kwargs...)
                catch e 
                    @error e 
                end
    
            end
        end
    end

    return ret
end

# a Hyperparameter definition
mutable struct Parameter 
    name::String 
    type::Symbol 

    values::Union{Tuple{Any, Any}, AbstractArray{<:Any, 1}}
    samples::Int
    grid::AbstractArray{<:Any, 1}

    function Parameter(name::String, type::Symbol, values::Union{Tuple{Any, Any}, AbstractArray{<:Any, 1}}; samples::Int=100)
        @assert type ∈ [:Linear, :Log, :Discrete] "Type must be one of [:Linear, :Log, :Discrete]."
        inst = new()
        inst.name = name
        inst.type = type 
        inst.values = values 
        inst.samples = samples
        return inst
    end
end

# extend `rand` for type `Parameter`
import Base.rand 
function Base.rand(p::Parameter)
    if p.type == :Linear 
        return rand(LinRange(p.values[1], p.values[2], p.samples))
    elseif p.type == :Log 
        return rand(exp10.(LinRange(log10(p.values[1]), log10(p.values[2]), p.samples)))
    elseif p.type == :Discrete 
        return rand(p.values)
    else 
        @assert false, "Unknown type ..."
    end
end

# an Optimization + results object
mutable struct Optimization 
    minimizers::AbstractArray{<:AbstractArray{Any, 1}, 1}
    minimums::AbstractArray{<:Real, 1}
    ressources::AbstractArray{<:Real, 1}

    fun    
    parameters::AbstractArray{<:Parameter, 1}

    minimizer
    minimum::Real
    ressource::Real

    function Optimization(fun, parameters::Parameter...)
        inst = new()
        inst.minimizers = Array{Array{Any, 1}, 1}()
        inst.minimums = Array{Real, 1}()
        inst.ressources = Array{Real, 1}()

        inst.minimizer = nothing 
        inst.minimum = Inf
        inst.ressource = Inf

        inst.fun = fun 
        inst.parameters = [parameters...]

        return inst
    end
end

abstract type AbstractOptimizationAlgorithm end 

# function being called, if algorithm wants a new sample
function sample!(sampler::AbstractOptimizationAlgorithm, optimization::Optimization, wid::Int)
    @assert false, "`sample!(sampler, optimization)` is not defined for this AbstractOptimizationAlgorithm, please define a dispatch."
end

# function being called, if algorithm evaluated a new sample (new loss)
function evaluated!(sampler::AbstractOptimizationAlgorithm, minimizer, minimum, wid::Int)
    # function optional, it's ok to not overwrite it!
end

function max_iters_reached(i, max_iters)
    if max_iters == 0
        return false
    else
        return i >= max_iters
    end
end

function max_duration_reached(start_time::Real, max_duration::Real)
    if max_duration == 0.0
        return false
    else
        return (time()-start_time) > max_duration
    end
end

function optimize(optimization::Optimization;
                  sampler::AbstractOptimizationAlgorithm=RandomSampler(),
                  workers::AbstractArray{Int64, 1}=workers(), 
                  print::Bool=true, 
                  plot::Bool=false, 
                  save_plot::Union{Nothing, String}=nothing,
                  redirect_worker_io_dir::Union{Nothing, String}=nothing,
                  loop_sleep::Real=0.1,
                  max_iters::Int=0,
                  max_duration::Real=0.0)

    nw = length(workers)
    i = 0

    start = true # to enter the loop
    terminate = collect(false for i in 1:nw) # to exit the loop

    # define a RemoteChannel and Minimizer for every worker
    process_channel = collect(RemoteChannel() for i in 1:nw)
    process_minimizer = Array{Union{Array{Any, 1}, Nothing}, 1}(nothing, nw)
    process_ressource = collect(Inf for i in 1:nw)

    start_time = time()

    try
        # a slong there are runs left OR runs not finished yet ...
        while start || (!all(terminate) || !all(isnothing.(process_minimizer)))
            start = false

            if max_iters_reached(i,max_iters)
                terminate = collect(true for i in 1:nw)
                @debug "Optimization: Termination requested by iteration count (max_iters=$(max_iters))"
            end

            if max_duration_reached(start_time, max_duration)
                terminate = collect(true for i in 1:nw)
                @debug "Optimization: Termination requested by running duration (max_duration=$(max_duration)s)"
            end

            for w in 1:nw

                if !terminate[w] && isnothing(process_minimizer[w]) # process doesnt want to terminate AND nothing running on that process
   
                    minimizer, ressource = sample!(sampler, optimization, w)

                    if isnothing(minimizer) # we are done!
                        terminate[w] = true
                        @debug "Optimization: Termination requested by worker #$(w)"
                        continue
                    end 

                    i += 1

                    if print
                        @info "Starting iteration $(i)/$(max_iters) @ worker #$(w) (PID $(workers[w])) with minimizer $(minimizer) and ressource $(ressource) ..."
                    end

                    if !isnothing(redirect_worker_io_dir)
                        logfile = joinpath(redirect_worker_io_dir, "process$(w).txt")
                        @async put!(process_channel[w], remotecall_fetch(redirect_printing, workers[w], logfile, optimization.fun, minimizer, ressource, i))  
                    else
                        @async put!(process_channel[w], remotecall_fetch(optimization.fun, workers[w], minimizer, ressource, i))  
                    end 
                    process_minimizer[w] = minimizer
                    process_ressource[w] = ressource

                else # something running on that process ...
            
                    if isready(process_channel[w])
                        minimum = take!(process_channel[w])
                        minimizer = process_minimizer[w]
                        ressource = process_ressource[w]

                        if isnothing(minimum)
                            @error "Finished iteration $(length(optimization.minimums))/$(max_iters) @ worker #$(w) (PID $(workers[w])) with minimizer $(minimizer) but no minimum was detected (objective returned nothing)." 
                        else
                            push!(optimization.minimums, minimum)
                            push!(optimization.minimizers, minimizer)
                            push!(optimization.ressources, ressource)
                            evaluated!(sampler, minimizer, minimum, w)

                            if print
                                @info "Finished iteration $(length(optimization.minimums))/$(max_iters) @ worker #$(w) (PID $(workers[w])) with minimizer $(minimizer) and minimum $(minimum)"
                            end

                            if minimum < optimization.minimum # we found a better solution!
                                optimization.minimum = minimum
                                optimization.minimizer = minimizer
                                optimization.ressource = ressource

                                if print
                                    @info "\tNew minimum $(minimum) for minimizer $(minimizer) with ressource $(ressource)."
                                end
                            end

                            if plot
                                fig = DistributedHyperOpt.plot(optimization)
                                display(fig)

                                if !isnothing(save_plot)
                                    DistributedHyperOpt.savefig(fig, save_plot)
                                end
                            end
                        end

                        process_minimizer[w] = nothing
                    end # isready
                end
            end

            if loop_sleep > 0.0
                sleep(loop_sleep)
            end
        end

    catch e
        interrupt()
        rethrow(e)
    end
end

# fetch optimization results
function results(optimization::Optimization)
    minIndex = 1 
    for i in 1:length(optimization.minimizers)
        if optimization.minimums[i] < optimization.minimums[minIndex] 
            minIndex = i 
        end
    end
    return optimization.minimums[minIndex], optimization.minimizers[minIndex], optimization.ressources[minIndex]
end

function plot(optimization::Optimization, args...; kwargs...)
    @warn "No plot interface loaded. Do `using Plots` to allow for plotting."
end

function savefig(args...; kwargs...)
    @warn "No plot interface loaded. Do `using Plots` to allow for saving of plots."
end

function __init__()
    @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
        import .Plots
        include(joinpath(@__DIR__, "Plots.jl"))
    end
    @require JLD2="033835bb-8acc-5ee8-8aae-3f567f8a3819" begin
        import .JLD2
        include(joinpath(@__DIR__, "JLD2.jl"))
    end
end

include(joinpath(@__DIR__, "RandomSampler.jl"))
include(joinpath(@__DIR__, "Hyperband.jl"))

end # module DistributedHyperOpt
