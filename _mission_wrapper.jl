#!/usr/bin/env julia
# _mission_wrapper.jl — Thin wrapper that runs process_mission() for multiple inputs.
# Called as: julia _mission_wrapper.jl "input1" "input2" ...
# All output goes to stdout for capture. Each mission's AIML scaffold is
# separated by unique delimiter lines ===MISSION_START:X=== / ===MISSION_END:X===
# Each mission is wrapped in try/catch so one crash doesn't kill the whole run.

using Pkg
Pkg.activate(".")

# Suppress startup noise from include
orig_stdout = stdout
devnull_file = open("/dev/null", "w")
redirect_stdout(devnull_file)
include("src/Main.jl")
flush(stdout)
redirect_stdout(orig_stdout)
close(devnull_file)

# Load specimen (load messages go to stdout, but parent script will filter)
load_specimen_from_file!(joinpath(@__DIR__, "specimens", "comprehensive_specimen.json"))

# Flush any specimen load output
flush(stdout)

# Print the boundary marker so the parent script knows loading is done
println("===SPECIMEN_LOADED===")
flush(stdout)

# Process each mission with try/catch so one crash doesn't kill the whole run
for mission_text in ARGS
    # Print a boundary marker with the mission text for parsing
    println("===MISSION_START:$(mission_text)===")
    flush(stdout)
    try
        process_mission(mission_text)
    catch e
        println("!!!MISSION_ERROR: $(e)")
    end
    flush(stdout)
    println("===MISSION_END:$(mission_text)===")
    flush(stdout)
end
