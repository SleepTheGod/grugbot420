#!/usr/bin/env julia --project=.
# Quick test: what does InputDecomposer do with "what is 2+2"?
using Pkg; Pkg.instantiate()

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420.InputDecomposer: decompose_input, DecomposedSubSubject

const SPEC_PATH = joinpath(@__DIR__, "comprehensive_specimen_v81.json")

# Load specimen to get its decomposer config
import .GrugBot420: load_specimen_from_file!
load_specimen_from_file!(SPEC_PATH)

test_inputs = [
    "what is 2+2",
    "what is a cat",
    "what is 2+2 also what is a cat",
    "I feel happy and what is 5 plus 3",
    "what is 5 plus 3",
    "calculate 3+4",
    "compute 5*7",
]

for inp in test_inputs
    println("\n=== Input: \"$inp\" ===")
    try
        subs = decompose_input(inp)
        println("  Sub-subjects: $(length(subs))")
        for (i, sub) in enumerate(subs)
            println("    $i: text=\"$(sub.text)\" group=\"$(sub.multipart_group)\" role=$(sub.role)")
        end
    catch e
        println("  ERROR: $e")
    end
end
