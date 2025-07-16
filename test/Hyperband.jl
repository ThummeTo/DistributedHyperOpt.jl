#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.

save_path = joinpath(@__DIR__, "auto_save.jld2")
sampler = DistributedHyperOpt.Hyperband(;R=30, η=3, ressourceScale=1.0/30.0, auto_save_path=save_path)
DistributedHyperOpt.save!(sampler, joinpath(@__DIR__, "initial.jld2"))
optimization = DistributedHyperOpt.Optimization(f, 
                                             DistributedHyperOpt.Parameter("a", (1.0,3.0)), 
                                             DistributedHyperOpt.Parameter("b", [0.9, 0.99, 0.999]), 
                                             DistributedHyperOpt.Parameter("c", (1.0, 100.0); type=:Log, samples=3, round_digits=1))
DistributedHyperOpt.optimize(optimization; sampler=sampler)
@info "Found minimum $(optimization.minimum) for minimizer $(optimization.minimizer)."
@test optimization.minimum < 5.0

# check ressources < 1.0
eps = 1e-12
for ressource in optimization.ressources 
    @test ressource > eps
    @test ressource < 1.0+eps
end

sampler_load = DistributedHyperOpt.load(save_path)
@test sampler.R == sampler_load.R 

optimization = DistributedHyperOpt.Optimization(f, 
                                             DistributedHyperOpt.Parameter("a", (1.0,3.0)), 
                                             DistributedHyperOpt.Parameter("b", [0.9, 0.99, 0.999]), 
                                             DistributedHyperOpt.Parameter("c", (1.0, 100.0); type=:Log, samples=3, round_digits=1))
DistributedHyperOpt.optimize(optimization; sampler=sampler_load)
@test optimization.minimum == Inf