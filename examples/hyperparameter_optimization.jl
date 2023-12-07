#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

using Plots
using JLD2
using DistributedHyperOpt
using DistributedHyperOpt.Distributed

# if you need debugging messages enabled, uncomment:
# ENV["JULIA_DEBUG"] = "DistributedHyperOpt"

# you could use up to 5 processes (=number of hyperband brackets) for this demo application if you have enough cores and RAM
workers = addprocs(3) 
@everywhere include(joinpath(@__DIR__, "hyperparameter_module.jl"))

η  = DistributedHyperOpt.Parameter("η", (1e-6, 1e-3); type=:Log, samples=4, round_digits=6)   # sample space from 1e-6 to 1e-3 with logarithmic scale and 4 samples (round samples to 6 digits)
β1 = DistributedHyperOpt.Parameter("β1", 1.0 .- exp10.(LinRange(-4,-1,4)))
β2 = DistributedHyperOpt.Parameter("β2", 1.0 .- exp10.(LinRange(-6,-1,6)))

# allow up to 100 training steps (resource=100.0)
sampler = DistributedHyperOpt.Hyperband(;R=81, η=3, ressourceScale=100.0/81.0)
optimization = DistributedHyperOpt.Optimization(MyModule.train!, η, β1, β2)
DistributedHyperOpt.optimize(optimization; 
                             sampler=sampler, 
                             plot=true,                                            # plot current hyperparameters after every step 
                             plot_ressources=true,                                 # also plot allocated ressources as hyperparameter
                             redirect_worker_io_dir=joinpath(@__DIR__, "logs"))    # redirect the processes i/o into a seperate directory, don't do this if you are still debugging!!!

# save optimization results
DistributedHyperOpt.saveOptimization(optimization, joinpath(@__DIR__, "logs", "myOptimizationResults.jld2"))

# plot the results, a bit larger
Plots.plot(optimization; size=(720,560), ressources=true)

# get the best run
minimum, minimizer, ressource = DistributedHyperOpt.results(optimization)