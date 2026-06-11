#!/usr/bin/env julia --project=.
# Quick test: single input "what is 2+2"
using Pkg; Pkg.instantiate()

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420: process_mission, load_specimen_from_file!,
    _LAST_AIML_OUTPUT, _LAST_AIML_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v81.json")

function read_last_output()::String
    lock(_LAST_AIML_OUTPUT_LOCK) do; _LAST_AIML_OUTPUT[]; end
end

println("Loading specimen...")
load_specimen_from_file!(SPEC_PATH)

println("\n=== Test: 'what is 2+2' ===")
lock(_LAST_AIML_OUTPUT_LOCK) do; _LAST_AIML_OUTPUT[]=""; end
try; process_mission("what is 2+2"); catch e; @warn "process_mission error: $e"; end
resp = read_last_output()

# Strip debug telemetry
conv = resp
ti = findfirst("--- DEBUG TELEMETRY", resp)
if ti !== nothing; conv = strip(resp[1:first(ti)-1]); end

println("\nFIRED NODE: $(_LAST_FIRED_NODE[])")
println("CONFIDENCE: $(_LAST_CONFIDENCE[])")
println("RESPONSE:\n$conv")

# Check for arithmetic result
if occursin(r"4", conv) || occursin("four", lowercase(conv))
    println("\n✓ ARITHMETIC RESULT FOUND")
else
    println("\n✗ NO ARITHMETIC RESULT")
end

# Check debug telemetry for math info
if occursin("Arithmetic Computed", resp)
    println("✓ 'Arithmetic Computed' found in telemetry")
elseif occursin("no math bindings", resp)
    println("✗ 'no math bindings this cycle' found in telemetry")
elseif occursin("math bindings present", resp)
    println("✓ 'math bindings present' found in telemetry")
end
