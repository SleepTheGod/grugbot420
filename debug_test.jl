# Debug test: trace why nodes aren't firing
ENV["GRUG_DEBUG_FIRE"] = "1"

using Pkg
Pkg.activate(".")
include("src/Main.jl")

println("\n" * "="^70)
println("  DEBUG TEST — Node Firing Trace")
println("="^70)

# Load specimen
spec_path = "specimens/comprehensive_specimen.json"
result = load_specimen_from_file!(spec_path)
println("Load result: $result")

# Check what's actually in NODE_MAP
println("\n--- NODE_MAP contents ---")
for (id, node) in NODE_MAP
    println("  $(node.id): pattern=\"$(node.pattern)\" strength=$(node.strength) is_grave=$(node.is_grave) is_antimatch=$(node.is_antimatch_node) is_image=$(node.is_image_node)")
end

# Test 1: exact single-token match
println("\n\n===== TEST 1: 'derivative' (exact match) =====")
try
    r = process_mission("derivative")
    println("RESPONSE: $r")
catch e
    println("ERROR: $e")
end

# Test 2: danger
println("\n\n===== TEST 2: 'danger' (exact match) =====")
try
    r = process_mission("danger")
    println("RESPONSE: $r")
catch e
    println("ERROR: $e")
end

# Test 3: embedded token
println("\n\n===== TEST 3: 'what is a derivative' (embedded) =====")
try
    r = process_mission("what is a derivative")
    println("RESPONSE: $r")
catch e
    println("ERROR: $e")
end

# Test 4: i feel sad
println("\n\n===== TEST 4: 'i feel sad' (exact multi-token) =====")
try
    r = process_mission("i feel sad")
    println("RESPONSE: $r")
catch e
    println("ERROR: $e")
end

# Test 5: free will
println("\n\n===== TEST 5: 'free will' (exact multi-token) =====")
try
    r = process_mission("free will")
    println("RESPONSE: $r")
catch e
    println("ERROR: $e")
end

# Test 6: imagine
println("\n\n===== TEST 6: 'imagine' (single token) =====")
try
    r = process_mission("imagine")
    println("RESPONSE: $r")
catch e
    println("ERROR: $e")
end
