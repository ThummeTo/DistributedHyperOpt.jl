#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using Test
using Plots
using DistributedHyperOpt
using DistributedHyperOpt.Distributed

import Random
Random.seed!(1234)

#ENV["JULIA_DEBUG"] = "DistributedHyperOpt"

# spawn processes
addprocs(3)
@everywhere using DistributedHyperOpt

@everywhere function f(minimizer, ressource, ind)
    a, b, c = minimizer
    sleep((rand() + myid()) * 0.1)
    return a*a + sqrt(abs(b)) - c/10.0
end

@testset "RandomSampler" begin
    include(joinpath(@__DIR__, "RandomSampler.jl"))
end

@testset "HyperbandSampler" begin
    include(joinpath(@__DIR__, "Hyperband.jl"))
end

