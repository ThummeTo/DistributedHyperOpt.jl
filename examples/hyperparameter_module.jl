#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

module MyModule

# Load in libraries
using Flux
using DistributedHyperOpt
using Distributed
import Random

# do things that only need to be done once, like data loading
# use some synthetic data 
data_input = cos.(LinRange(0.0f0, 10.0f0, 101))
data_output = sin.(data_input)

# a loss function for training
function loss(net)
    net_output = collect(net([inp])[1] for inp in data_input)
    return Flux.Losses.mse(net_output, data_output)
end

# provide the function that need to be minimized, here an ANN training result
function train!(hyper_params, ressource, ind)

    # fixing the random seed is optional
    Random.seed!(1234)

    # we interpret `ressource` as number of training steps here
    trainSteps = max(round(Int, ressource), 1) 

    # unpack hyperparameters
    eta, beta1, beta2 = hyper_params

    @info "--------------\nStarting run $(ind) with parameters: $(hyper_params) and ressource $(ressource) doing $(trainSteps) step(s)."

    # this is just an example, not a good topology!
    net = Chain(Dense(1,16, tanh),
                Dense(16, 1, tanh))
    
    # get parameters from `net`
    params = Flux.params(net)

    # initialize Adam with our hyperparameter set
    optim = Adam(eta, (beta1, beta2))

    # train with steps, defined by the allocated ressource
    Flux.train!(() -> loss(net), params, Iterators.repeated((), trainSteps), optim) 
    
    # return the final loss after training
    # better would be a testing loss here ;-)
    return loss(net)
end

end # MyModule