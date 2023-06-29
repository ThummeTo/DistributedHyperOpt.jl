## What is DistributedHyperOpt.jl?
*DistributedHyperOpt.jl* is a package similar to [*HyperOpt.jl*](https://github.com/baggepinnen/Hyperopt.jl), but explicitly focusing on distributed (multi-processing) hyperparameter optimization by design.

## How can I use DistributedHyperOpt.jl?
1\. Open a Julia-REPL, switch to package mode using `]`, activate your preferred environment.

2\. Install [*DistributedHyperOpt.jl?*](https://github.com/ThummeTo/DistributedHyperOpt.jl?):
```julia-repl
(@v1.X) pkg> add "https://github.com/ThummeTo/DistributedHyperOpt.jl"
```

3\. If you want to check that everything works correctly, you can run the tests bundled with [*DistributedHyperOpt.jl?*](https://github.com/ThummeTo/DistributedHyperOpt.jl?):
```julia-repl
(@v1.X) pkg> test DistributedHyperOpt
```

4\. See the testing scripts for examples.

## What is currently supported in DistributedHyperOpt.jl?

|                                   | Max. processes |
|-----------------------------------|----------------|
| Random Sampler                    | unlimited      |
| Hyperband (using Random Sampler)  | num. brackets (`s_max+1`)  |
