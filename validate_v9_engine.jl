#!/usr/bin/env julia
# Validate specimen v9 loads through the actual GrugBot420 engine
# Tests load_specimen_from_file! and basic post-load state

println("=== GrugBot420 Engine Specimen v9 Validation ===")
println()

# Activate and include the engine
using Pkg; Pkg.activate(".")
println("Including Main.jl...")
include("src/Main.jl")
println("Engine loaded OK.")
println()

# Load the specimen
filepath = "comprehensive_specimen_v9.json"
println("Loading specimen: $filepath")
try
    result = load_specimen_from_file!(filepath)
    println("Load result: $result")
catch e
    println("LOAD ERROR: $e")
    println("Backtrace:")
    for (i, frame) in enumerate(stacktrace(catch_backtrace()))
        println("  [$i] $frame")
        i > 15 && break
    end
    exit(1)
end

println()
println("=== Post-Load State Check ===")
println("Node count: $(length(NODES))")
println("Lobe count: $(length(LOBES))")
println("Bridge count: $(length(BRIDGES))")

# Check answer mode config
println("\nAnswer modes configured:")
for (k, v) in _ANSWER_MODE_CONFIG
    println("  $k")
end

# Check sigil table
println("\nSigil table entries: $(length(SIGIL_TABLE))")
for (k, v) in SIGIL_TABLE
    println("  $k => class=$(v.class), applies_at=$(v.applies_at)")
end

# Check autogrowth evidence
println("\nAutoGrowth evidence entries: $(length(AutoGrowth._evidence))")
for (k, v) in AutoGrowth._evidence
    println("  \"$k\" => score=$(v.score), freq=$(v.frequency)")
end

# Check autolink evidence
println("\nAutoLinker evidence entries: $(length(AutoLinker._link_evidence))")
for (k, v) in AutoLinker._link_evidence
    println("  \"$k\" => score=$(v.score), freq=$(v.frequency)")
end

# Test a simple mission
println("\n=== Test Mission ===")
println("Sending: \"hello grug\"")
try
    result = process_mission("hello grug")
    println("Response: $result")
catch e
    println("Mission error: $e")
end

println("\n=== ENGINE VALIDATION COMPLETE ===")
