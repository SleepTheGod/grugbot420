#!/usr/bin/env julia
# load_test.jl — Verify Main.jl loads and the v81 specimen loads without errors.
using Pkg
Pkg.activate(".")

println("=== LOADING Main.jl ===")
flush(stdout)
include("src/Main.jl")
println("=== Main.jl LOADED OK ===")
flush(stdout)

println("=== LOADING v81 specimen ===")
flush(stdout)
res = load_specimen_from_file!("comprehensive_specimen_v81.json")
println(res)
println("=== specimen LOADED ===")
flush(stdout)

# Snapshot state
_n = lock(() -> length(NODE_MAP), NODE_LOCK)
println("NODE_MAP count: $_n")
_alive = lock(() -> count(n -> !n.is_grave, values(NODE_MAP)), NODE_LOCK)
println("Alive nodes: $_alive")
println("Lobes: $(length(Lobe.LOBE_REGISTRY))")
println("=== ALL OK ===")
flush(stdout)
