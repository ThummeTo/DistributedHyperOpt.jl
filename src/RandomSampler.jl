#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

mutable struct RandomSampler <: AbstractOptimizationAlgorithm 
    ressource::Real 
    
    function RandomSampler(; ressource::Real=0.0)
        inst = new()
        inst.ressource = ressource
        return inst
    end
end

function sample!(sampler::RandomSampler, optimization::Optimization, wid::Int)
    return collect(rand(p) for p in optimization.parameters), sampler.ressource
end