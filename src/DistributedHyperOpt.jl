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
    exception = nothing
    pid = myid()

    @debug "Opening log file @ `$(logfile)` for process #$(pid)"
    
    open(logfile, "w") do io
        redirect_stdout(io) do
            redirect_stderr(io) do

                println("----- redirecting worker stdout/stderr to file -----")

                try
                    ret = fun(args...; kwargs...)
                catch e 
                    exception = e
                    println(exception)
                end
    
            end
        end
    end

    if !isnothing(exception)
        @error "Logging for file `$(logfile)` failed with exception: $(exception)"
    end

    return ret
end

# a Hyperparameter definition
struct Parameter 
    name::String 
    type::Symbol 

    values::Union{Tuple{Any, Any}, AbstractArray{<:Any, 1}}
    samples::Int
    round_digits::Union{Nothing, Int}

    function Parameter(name::String, values::Union{Tuple{Any, Any}, AbstractArray{<:Any, 1}}; type::Symbol=:Auto, samples::Int=100, round_digits::Union{Nothing, Int}=nothing)
        if type == :Auto 
            if isa(values, Tuple{Any, Any})
                type = :Linear 
            elseif isa(values, AbstractArray{<:Any, 1})
                type = :Discrete 
            end
        end
        @assert !isa(values, AbstractArray{<:Any, 1}) || type == :Discrete "Field `values` is given a array of values, but type is not `:Discrete`. Please change type to `:Discrete` when using arrays of parameter values."
        @assert type ∈ [:Linear, :Log, :Discrete] "Type must be one of [:Linear, :Log, :Discrete]."
        @assert isnothing(round_digits) || type != :Discrete "Keyword `round_digits` not supported for parameters of type `:Discrete`. Please remove  keyword or change type."
        return new(name, type, values, samples, round_digits)
    end
end

# extend `rand` for type `Parameter`
import Base.rand 
function Base.rand(p::Parameter)
    val = nothing

    if p.type == :Linear 
        val = rand(LinRange(p.values[1], p.values[2], p.samples))
    elseif p.type == :Log 
        val = rand(exp10.(LinRange(log10(p.values[1]), log10(p.values[2]), p.samples)))
    elseif p.type == :Discrete 
        val = rand(p.values)
    else 
        @assert false, "Unknown type `$(p.type)`."
    end

    if !isnothing(p.round_digits)
        val = round(val; digits=p.round_digits)
    end
    
    return val
end

# an Optimization + results object
mutable struct Optimization 
    minimizers::AbstractArray{<:AbstractArray{Any, 1}, 1}
    minimums::AbstractArray{<:Real, 1}
    
    tests::AbstractArray{<:Real, 1}
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
        inst.tests = Array{Real, 1}()
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
                  plot_ressources::Bool=false,
                  save_plot::Union{Nothing, String}=nothing,
                  redirect_worker_io_dir::Union{Nothing, String}=nothing,
                  loop_sleep::Real=0.1,
                  max_iters::Int=0,
                  max_duration::Real=0.0)

    nw = length(workers)
    i = 0

    terminate = collect(false for i in 1:nw) # to exit the loop

    # define a RemoteChannel and Minimizer for every worker
    process_channel = collect(RemoteChannel() for i in 1:nw)
    process_minimizer = Array{Union{Array{Any, 1}, Nothing}, 1}(nothing, nw)
    process_ressource = collect(Inf for i in 1:nw)
    process_iteration = zeros(Int, nw)

    # initial loss 
    # ret = optimization.fun(minimizer, 0.0, 0)
    # initialMinimum = nothing 
    # initialTest = nothing 
    # if isnothing(ret)
    #     minimum = ret
    # elseif length(ret) == 1
    #     minimum = ret[1] # or `minimum = ret` 
    # elseif length(ret) == 2
    #     minimum, test = ret 
    # else
    #     @assert false "Optimization process returned $(length(ret)) elements, supported is 1 (minimum) or 2 (minimum+test), returned: `$(ret)` on first step."
    # end
    
    start_time = time()

    try

        all_terminate = false
        processes_running = true

        # as long there are runs left OR runs not finished yet ...
        while !all_terminate || processes_running
            
            if !all_terminate
                if max_iters_reached(i,max_iters)
                    terminate = collect(true for i in 1:nw)
                    @debug "Optimization: Termination requested by iteration count (max_iters=$(max_iters))"
                end

                if max_duration_reached(start_time, max_duration)
                    terminate = collect(true for i in 1:nw)
                    @debug "Optimization: Termination requested by running duration (max_duration=$(max_duration)s)"
                end
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

                    process_iteration[w] = i
                    process_minimizer[w] = minimizer
                    process_ressource[w] = ressource

                    if print
                        @info "Starting iteration $(process_iteration[w])/$(max_iters) @ worker #$(w) (PID $(workers[w])) with minimizer $(minimizer) and ressource $(ressource) ..."
                    end

                    if !isnothing(redirect_worker_io_dir)
                        logfile = joinpath(redirect_worker_io_dir, "process$(w).txt")
                        @async put!(process_channel[w], remotecall_fetch(redirect_printing, workers[w], logfile, optimization.fun, minimizer, ressource, i))  
                    else
                        @async put!(process_channel[w], remotecall_fetch(optimization.fun, workers[w], minimizer, ressource, i))  
                    end 
                    

                else # something running on that process ...
            
                    if isready(process_channel[w])
                        ret = take!(process_channel[w])

                        minimum = nothing 
                        test = nothing 

                        if isnothing(ret)
                            minimum = ret
                        elseif length(ret) == 1
                            minimum = ret[1] # or `minimum = ret` 
                        elseif length(ret) == 2
                            minimum, test = ret 
                        else
                            @assert false "Optimization process returned $(length(ret)) elements, supported is 1 (minimum) or 2 (minimum+test), returned: `$(ret)`"
                        end

                        minimizer = process_minimizer[w]
                        ressource = process_ressource[w]

                        if isnothing(minimum)
                            @error "Finished iteration $(process_iteration[w])/$(max_iters) @ worker #$(w) (PID $(workers[w])) with minimizer $(minimizer) but no minimum was detected (objective returned nothing)." 
                        else
                            push!(optimization.minimums, minimum)
                            push!(optimization.minimizers, minimizer)
                            push!(optimization.ressources, ressource)

                            if isnothing(test)
                                push!(optimization.tests, 0.0)
                            else
                                push!(optimization.tests, test)
                            end

                            evaluated!(sampler, minimizer, minimum, w)

                            if print
                                @info "Finished iteration $(process_iteration[w])/$(max_iters) @ worker #$(w) (PID $(workers[w])) with minimizer $(minimizer) and minimum $(minimum) ($(test) on testing)."
                            end

                            if minimum < optimization.minimum # we found a better solution!
                                optimization.minimum = minimum
                                optimization.minimizer = minimizer
                                optimization.ressource = ressource

                                if print
                                    @info "\tNew minimum $(minimum) ($(test) on testing) at iteration $(process_iteration[w])/$(max_iters) for minimizer $(minimizer) with ressource $(ressource)."
                                end
                            end

                            if plot
                                fig = DistributedHyperOpt.plot(optimization; ressources=plot_ressources)
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

            all_terminate = all(terminate)
            processes_running = !all(isnothing.(process_minimizer))

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
function results(optimization::Optimization; update::Bool=false)
    if update
        minIndex = 1 
        for i in 2:length(optimization.minimizers)
            if optimization.minimums[i] < optimization.minimums[minIndex] 
                minIndex = i 
            end
        end
        
        optimization.minimum   = optimization.minimums[minIndex]
        optimization.minimizer = optimization.minimizers[minIndex]
        optimization.ressource = optimization.ressources[minIndex]
    end

    return optimization.minimum, optimization.minimizer, optimization.ressource
end

function plot(optimization::Optimization, args...; kwargs...)
    @warn "No plot interface loaded. Do `using Plots` to allow for plots."
end

function scatter(optimization::Optimization, args...; kwargs...)
    @warn "No plot interface loaded. Do `using Plots` to allow for scatter plots."
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
