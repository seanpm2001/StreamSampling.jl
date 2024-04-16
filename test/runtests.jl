
using StreamSampling

using Distributions
using HypothesisTests
using Random
using StableRNGs
using Test

@testset "StreamSampling.jl Tests" begin
    #include("package_sanity_tests.jl")
    #include("unweighted_sampling_single_tests.jl")
    #include("unweighted_sampling_multi_tests.jl")
    include("weighted_sampling_single_tests.jl")
    include("weighted_sampling_multi_tests.jl")
end
