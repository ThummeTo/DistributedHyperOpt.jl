#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.

save_path = joinpath(@__DIR__, "auto_save.jld2")

sampler = DistributedHyperOpt.Hyperband(;R=30, η=3, ressourceScale=1.0/30.0, auto_save_path=save_path)
optimization = DistributedHyperOpt.Optimization(DistributedHyperOpt.Parameter("a", (1.0,3.0)), 
                                             DistributedHyperOpt.Parameter("b", [0.9, 0.99, 0.999]), 
                                             DistributedHyperOpt.Parameter("c", (1.0, 100.0); type=:Log, samples=3, round_digits=1))
DistributedHyperOpt.save!(sampler, optimization, joinpath(@__DIR__, "initial.jld2"))
DistributedHyperOpt.optimize(optimization, f; sampler=sampler)
@info "Found minimum $(optimization.minimum) for minimizer $(optimization.minimizer)."
@test optimization.minimum < 5.0

# check ressources < 1.0
eps = 1e-12
for ressource in optimization.ressources 
    @test ressource > eps
    @test ressource < 1.0+eps
end

sampler_load, optimization_load = DistributedHyperOpt.load(save_path)
@test sampler.R == sampler_load.R 
@test sampler.iteration == sampler_load.iteration

# do optimization in two parts
max_iters = 30
sampler = DistributedHyperOpt.Hyperband(;R=30, η=3, ressourceScale=1.0/30.0)
optimization = DistributedHyperOpt.Optimization(DistributedHyperOpt.Parameter("a", (1.0,3.0)), 
                                             DistributedHyperOpt.Parameter("b", [0.9, 0.99, 0.999]), 
                                             DistributedHyperOpt.Parameter("c", (1.0, 100.0); type=:Log, samples=3, round_digits=1))
DistributedHyperOpt.optimize(optimization, f; sampler=sampler, max_iters=max_iters)
@test sampler.iteration == max_iters
DistributedHyperOpt.save!(sampler, optimization, save_path)

sampler, optimization = DistributedHyperOpt.load(save_path)
@test sampler.iteration == max_iters
DistributedHyperOpt.optimize(optimization, f; sampler=sampler)
@test sampler.iteration == 69