#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

mutable struct HyperbandBracket 
    n::Int 
    r::Real
    s::Int
    i::Int
    l::Int # not in the paper, iterator for L
    T::AbstractArray{<:Any, 1}
    L::AbstractArray{<:Any, 1}

    function HyperbandBracket(sampler) # ::Hyperband
        inst = new()
        inst.i = 0
        inst.l = 1
        inst.n = ceil(Int, sampler.B/sampler.R * (sampler.η^sampler.s)/(sampler.s+1) )
        inst.r = sampler.R * (Float64(sampler.η)^(-sampler.s))
        inst.s = sampler.s
        
        return inst
    end
end

mutable struct Hyperband <: AbstractOptimizationAlgorithm 
    R::Int 
    η::Int

    s_max::Int
    s::Int 
    B::Int

    sampler::AbstractOptimizationAlgorithm
    brackets::Dict{Int, Union{HyperbandBracket, Nothing}}
    ressourceScale

    function Hyperband(;R::Int=50, η::Int=3, sampler::AbstractOptimizationAlgorithm=RandomSampler(), ressourceScale::Real=1.0)
        inst = new()
        inst.R = R
        inst.η = η
        inst.s_max = floor(Int, log(η, R))
        inst.s = inst.s_max
        inst.B = (inst.s_max+1)*R

        @info "Hyperband with R=$(inst.R), η=$(inst.η), s_max=$(inst.s_max), B=$(inst.B) will allocate ressources up to $(ressourceScale*R)"

        inst.sampler = sampler 
        inst.ressourceScale = ressourceScale
        inst.brackets = Dict{Int, Union{HyperbandBracket, Nothing}}()

        return inst
    end
end

function top_k!(T, L, k)
    rm_bad_k!(T, L, length(L)-k)
end

function rm_bad_k!(T, L, k)
    @debug "Successive Halving:"
    
    for _ in 1:k
        worstIndex = 1 
        for i in 2:length(L)
            if L[i] > L[worstIndex] 
                worstIndex = i
            end
        end

        @debug "\tRemoving minimizer $(T[worstIndex]) with minimum $(L[worstIndex])"

        deleteat!(T, worstIndex)
        deleteat!(L, worstIndex)
    end
    return nothing
end

function all_brackets_finished(sampler::Hyperband)
    for k in keys(sampler.brackets)
        if !isnothing(sampler.brackets[k])
            return false
        end
    end
    return true
end

function all_brackets_started(sampler::Hyperband)
    return sampler.s < 0
end

function worker_has_bracket(sampler::Hyperband, wid::Int)
    return haskey(sampler.brackets, wid) && !isnothing(sampler.brackets[wid])
end

function sample!(sampler::Hyperband, optimization::Optimization, wid::Int)

    if all_brackets_started(sampler) && all_brackets_finished(sampler)
        @debug "Hyperband: Finished!"
        return nothing, 0.0 # we are done!
    end

    bracket = nothing 
    if !worker_has_bracket(sampler, wid)

        if all_brackets_started(sampler)
            @debug "Hyperband: No jobs left, worker #$(wid) waiting!"
            return nothing, 0.0 # we are done!
        end

        bracket = HyperbandBracket(sampler)

        @debug "Hyperband: Entering new bracket $(sampler.s)/$(sampler.s_max) with n=$(bracket.n) and worker #$(wid)"
        
        bracket.T = collect(sample!(sampler.sampler, optimization, wid)[1] for _ in 1:bracket.n) # take only the only the minimizer `[1]` 
        bracket.L = collect(Inf for _ in 1:bracket.n)
        sampler.s -= 1

        sampler.brackets[wid] = bracket
    else
        bracket = sampler.brackets[wid]
    end

    n = bracket.n 
    i = bracket.i
    l = bracket.l
    η = sampler.η
    r = bracket.r

    r_i = r * (η^i)

    @debug "Hyperband: Visiting new sample (s=$(bracket.s), i=$(i)/$(bracket.s), l=$(l)/$(length(bracket.L))) with worker #$(wid) and ressource $(r_i) (scaled: $(r_i*sampler.ressourceScale))"

    return bracket.T[l], r_i*sampler.ressourceScale
end

function evaluated!(sampler::Hyperband, minimizer, minimum, wid::Int)
    
    bracket = sampler.brackets[wid]
    bracket.L[bracket.l] = minimum

    # fetch vars
    n = bracket.n 
    i = bracket.i
    l = bracket.l
    η = sampler.η
    n_i = floor(Int, n * (Float64(η)^(-i)))

    # close loops
    bracket.l += 1
    if bracket.l > length(bracket.L) # L loop finished
        bracket.l = 1 

        top_k!(bracket.T, bracket.L, floor(Int, n_i/η))

        bracket.i += 1
        if bracket.i > bracket.s # bracket finished
            @debug "Hyperband: Bracket s=$(bracket.s) finished by worker #$(wid)"
            sampler.brackets[wid] = nothing
        end
    end
end