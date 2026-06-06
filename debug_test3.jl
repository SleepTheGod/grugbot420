#!/usr/bin/env julia
# debug_test3.jl — Verify node signals after loading specimen
# This script loads the specimen and checks what signals the nodes actually have
# in memory vs. what's in the JSON file.

using Pkg
Pkg.activate(".")

# Suppress most output during include
redirect_stdout(devnull) do
    include("src/Main.jl")
end

println("=" ^ 60)
println("DEBUG TEST 3: Verify node signals after specimen load")
println("=" ^ 60)

# Load the specimen
specimen_path = joinpath(@__DIR__, "specimens", "comprehensive_specimen.json")
println("\nLoading specimen from: $specimen_path")

try
    result = load_specimen_from_file!(specimen_path)
    println("Load result: OK")
catch e
    println("Load FAILED: $e")
    exit(1)
end

# Now inspect all nodes in NODE_MAP
println("\n" * "=" ^ 60)
println("NODE SIGNAL INSPECTION")
println("=" ^ 60)

lock(NODE_LOCK) do
    for (id, node) in NODE_MAP
        pat = node.pattern
        sig = node.signal
        toks = split(pat)
        status = length(sig) == length(toks) ? "OK" : "MISMATCH! tokens=$(length(toks)) signal_len=$(length(sig))"
        println("  $id: pattern=\"$pat\" signal_len=$(length(sig)) tokens=$(length(toks)) $status")
        if length(sig) <= 5
            println("    signal=$sig")
        end
    end
end

println("\n" * "=" ^ 60)
println("SCANNER CONFIG: FullLobeScanner.MAX_ACTIVE_NODES = $(FullLobeScanner.MAX_ACTIVE_NODES)")
println("=" ^ 60)

println("\n" * "=" ^ 60)
println("DIRECT SCAN TEST")
println("=" ^ 60)

# Test scan_specimens directly for each input
test_inputs = [
    "derivative",
    "danger",
    "what is a derivative",
    "i feel sad",
    "free will",
    "imagine",
    "hello",
    "what time is it",
    "write a poem",
    "pythagorean theorem"
]

for input_text in test_inputs
    println("\n--- Testing input: \"$input_text\" ---")
    try
        results = scan_specimens(input_text)
        if isempty(results)
            println("  NO MATCHES")
        else
            for r in results
                println("  MATCH: id=$(r[1]) conf=$(round(r[2], digits=3)) antimatch=$(r[3]) best_idx=$(r[6])")
            end
        end
    catch e
        println("  ERROR: $e")
    end
end

println("\n" * "=" ^ 60)
println("DONE")
println("=" ^ 60)
