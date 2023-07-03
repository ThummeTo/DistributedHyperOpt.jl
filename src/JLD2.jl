#
# Copyright (c) 2023 Tobias Thummerer, Lars Mikelsons
# Licensed under the MIT license. See LICENSE file in the project root for details.
#

function saveOptimization(optimization::Optimization, filepath::String)
    dict = Dict{String, Any}()
    dict["minimizers"]  = optimization.minimizers
    dict["minimums"]    = optimization.minimums
    dict["ressources"]  = optimization.ressources
    dict["minimizer"]   = optimization.minimizer
    dict["minimum"]     = optimization.minimum
    dict["ressource"]   = optimization.ressource
    JLD2.save(filepath, dict)
end

function loadOptimization!(optimization::Optimization, filepath::String)
    dict = JLD2.load(filepath)
    optimization.minimizers = dict["minimizers"]
    optimization.minimums   = dict["minimums"]
    optimization.ressources = dict["ressources"]
    optimization.minimizer  = dict["minimizer"]
    optimization.minimum    = dict["minimum"]
    optimization.ressource  = dict["ressource"]
    return nothing
end