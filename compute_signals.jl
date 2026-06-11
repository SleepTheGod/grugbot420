# Compute correct signal vectors for all node patterns
using Pkg
Pkg.activate(".")

# Only need the hash function, not the whole engine
function words_to_signal(text::String)::Vector{Float64}
    tokens = split(lowercase(strip(text)))
    if isempty(tokens)
        error("empty text")
    end
    signal = Float64[]
    for tok in tokens
        val = Float64(hash(tok)) / Float64(typemax(UInt64))
        push!(signal, val)
    end
    return signal
end

patterns = [
    "derivative",
    "integral",
    "pythagorean theorem",
    "what is consciousness",
    "meaning of life",
    "free will",
    "danger",
    "hide and seek",
    "fight back",
    "i feel sad",
    "i feel anxious",
    "validate my feelings",
    "write a poem",
    "tell me a story",
    "imagine",
    "hello",
    "what time is it",
    "what happened before",
    "ignore mathematics",
    "stop empathy",
    "sunset image",
    "watch out",
    "why does",
    "obsolete test pattern",
    "sacred knowledge",
]

using JSON

results = Dict{String, Vector{Float64}}()
for p in patterns
    sig = words_to_signal(p)
    results[p] = sig
    println("$(repr(p)): $(length(sig)) tokens → $(sig)")
end

# Also compute signals for the action packets
action_packets = [
    "reason", "greet", "flee", "explain", "comfort", "alert", "inquire"
]
for a in action_packets
    sig = words_to_signal(a)
    results[a] = sig
    println("action:$(repr(a)): $(length(sig)) tokens → $(sig)")
end

# Save to JSON
open("specimens/signal_map.json", "w") do f
    JSON.print(f, results, 2)
end
println("\nSaved signal_map.json")
