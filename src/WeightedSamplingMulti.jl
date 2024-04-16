
mutable struct SampleMultiAlgARes{BH,R} <: AbstractWeightedWorReservoirSampleMulti
    seen_k::Int
    n::Int
    rng::R
    value::BH
end

mutable struct SampleMultiAlgAExpJ{BH,R} <: AbstractWeightedWorReservoirSampleMulti
    state::Float64
    min_priority::Float64
    seen_k::Int
    n::Int
    rng::R
    value::BH
end

mutable struct SampleMultiAlgWRSWRSKIP{T,R} <: AbstractWeightedWrReservoirSampleMulti
    state::Float64
    skip_w::Float64
    seen_k::Int
    rng::R
    weights::Vector{Float64}
    value::Vector{T}
end

function ReservoirSample(rng::AbstractRNG, T, n::Integer, method::AlgAExpJ; ordered = false)
    value = BinaryHeap(Base.By(last), Pair{T, Float64}[])
    sizehint!(value, n)
    if ordered
        error("Not implemented yet")
    else
        return SampleMultiAlgAExpJ(0.0, 0.0, 0, n, rng, value)
    end
end
function ReservoirSample(rng::AbstractRNG, T, n::Integer, method::AlgARes; ordered = false)
    value = BinaryHeap(Base.By(last), Pair{T, Float64}[])
    sizehint!(value, n)
    if ordered
        error("Not implemented yet")
    else
        return SampleMultiAlgARes(0, n, rng, value)
    end
end
function ReservoirSample(rng::AbstractRNG, T, n::Integer, method::AlgWRSWRSKIP; ordered = false)
    value = Vector{T}(undef, n)
    weights = Vector{Float64}(undef, n)
    if ordered
        error("Not implemented yet")
    else
        return SampleMultiAlgWRSWRSKIP(0.0, 0.0, 0, rng, weights, value)
    end
end

function update!(s::SampleMultiAlgARes, el, w)
    n = s.n
    s.seen_k += 1
    priority = -randexp(s.rng)/w
    if s.seen_k <= n
        push!(s.value, el => priority)
    else
        min_priority = last(first(s.value))
        if priority > min_priority
            pop!(s.value)
            push!(s.value, el => priority)
        end
    end
    return s
end
function update!(s::SampleMultiAlgAExpJ, el, w)
    n = s.n
    s.seen_k += 1
    s.state -= w
    if s.seen_k <= n
        priority = exp(-randexp(s.rng)/w)
        push!(s.value, el => priority)
        s.seen_k == n && @inline recompute_skip!(s)
    elseif s.state <= 0.0
        priority = @inline compute_skip_priority(s, w)
        pop!(s.value)
        push!(s.value, el => priority)
        @inline recompute_skip!(s)
    end
    return s
end
function update!(s::SampleMultiAlgWRSWRSKIP, el, w)
    n = length(s.value)
    s.seen_k += 1
    s.state += w
    if s.seen_k <= n
        s.value[s.seen_k] = el
        s.weights[s.seen_k] = w
        if s.seen_k == n 
            @inline recompute_skip!(s, n)
            empty!(s.weights)
        end
    elseif s.skip_w < s.state
        p = w/s.state
        z = (1-p)^(n-3)
        q = rand(s.rng, Uniform(z*(1-p)*(1-p)*(1-p),1.0))
        k = choose(n, p, q, z)
        @inbounds begin
            if k == 1
                r = rand(s.rng, 1:n)
                s.value[r] = el
            else
                for j in 1:k
                    r = rand(s.rng, j:n)
                    s.value[r] = el
                    s.value[r], s.value[j] = s.value[j], s.value[r]
                end
            end 
        end
        @inline recompute_skip!(s, n)
    end
    return s
end

function compute_skip_priority(s, w)
    t = exp(log(s.min_priority)*w)
    return exp(log(rand(s.rng, Uniform(t,1)))/w)
end

function recompute_skip!(s::SampleMultiAlgAExpJ)
    s.min_priority = last(first(s.value))
    s.state = -randexp(s.rng)/log(s.min_priority)
end
function recompute_skip!(s::SampleMultiAlgWRSWRSKIP, n)
    q = rand(s.rng)^(1/n)
    s.skip_w = s.state/q
end

function value(s::AbstractWeightedWorReservoirSampleMulti)
    if n_seen(s) < s.n
        return first.(s.value.valtree)[1:n_seen(s)]
    else
        return first.(s.value.valtree)
    end
end
function value(s::AbstractWeightedWrReservoirSampleMulti)
    if n_seen(s) < length(s.value)
        return sample(s.rng, s.value[1:n_seen(s)], weights(s.weights[1:n_seen(s)]), length(s.value))
    else
        return s.value
    end
end

function ordered_value(s::AbstractWeightedReservoirSampleMulti)
    error("Not implemented yet")
end

n_seen(s::SampleMultiAlgARes) = s.seen_k
n_seen(s::SampleMultiAlgAExpJ) = s.seen_k
n_seen(s::SampleMultiAlgWRSWRSKIP) = s.seen_k

function itsample(iter, wv::Function, n::Int, 
        method::ReservoirAlgorithm=algAExpJ; ordered = false)
    return itsample(Random.default_rng(), iter, wv, n, method; ordered = ordered)
end

function itsample(rng::AbstractRNG, iter, wv::Function, n::Int, 
        method::ReservoirAlgorithm=algAExpJ; ordered = false)
    return reservoir_sample(rng, iter, wv, n, method; ordered = ordered)
end

function reservoir_sample(rng, iter, wv::Function, n::Int, 
        method::ReservoirAlgorithm=algAExpJ; ordered = false)
    iter_type = calculate_eltype(iter)
    s = ReservoirSample(rng, iter_type, n, method; ordered = ordered)
    return update_all!(s, iter, wv, ordered)
end

function update_all!(s, iter, wv, ordered)
    for x in iter
        @inline update!(s, x, wv(x))
    end
    return ordered ? ordered_value(s) : shuffle!(s.rng, value(s))
end