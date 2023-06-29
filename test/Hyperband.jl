#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.

sampler = DistributedHyperOpt.Hyperband(;R=30, η=3, ressourceScale=1.0/30.0)
optimization = DistributedHyperOpt.Optimization(f, 
                                             DistributedHyperOpt.Parameter("a", (1.0,3.0)), 
                                             DistributedHyperOpt.Parameter("b", [4.0, 5.0, 6.0]), 
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
