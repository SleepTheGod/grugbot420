# Debug test 2: direct scan_specimens call with debug output
using Pkg
Pkg.activate(".")
include("src/Main.jl")

println("\n" * "="^70)
println("  DEBUG TEST 2 — Direct scan_specimens trace")
println("="^70)

# Load specimen
spec_path = "specimens/comprehensive_specimen.json"
result = load_specimen_from_file!(spec_path)
println("Load result: $(result[1:50])...")

# Test: directly call scan_specimens
println("\n\n===== DIRECT SCAN: 'derivative' =====")
try
    specimens = scan_specimens("derivative")
    println("Scan returned $(length(specimens)) specimens")
    for s in specimens
        println("  id=$(s[1]) conf=$(s[2]) antimatch=$(s[3])")
    end
catch e
    println("ERROR: $e")
    for (exc, bt) in current_exceptions()
        showerror(stdout, exc, bt)
        println()
    end
end

println("\n\n===== DIRECT SCAN: 'danger' =====")
try
    specimens = scan_specimens("danger")
    println("Scan returned $(length(specimens) specimens")
    for s in specimens
        println("  id=$(s[1]) conf=$(s[2]) antimatch=$(s[3])")
    end
catch e
    println("ERROR: $e")
end

println("\n\n===== DIRECT SCAN: 'i feel sad' =====")
try
    specimens = scan_specimens("i feel sad")
    println("Scan returned $(length(specimens)) specimens")
    for s in specimens
        println("  id=$(s[1]) conf=$(s[2]) antimatch=$(s[3])")
    end
catch e
    println("ERROR: $e")
end

println("\n\n===== DIRECT SCAN: 'hello' =====")
try
    specimens = scan_specimens("hello")
    println("Scan returned $(length(specimens)) specimens")
    for s in specimens
        println("  id=$(s[1]) conf=$(s[2]) antimatch=$(s[3])")
    end
catch e
    println("ERROR: $e")
end

println("\n\n===== DIRECT SCAN: 'what time is it' =====")
try
    specimens = scan_specimens("what time is it")
    println("Scan returned $(length(specimens)) specimens")
    for s in specimens
        println("  id=$(s[1]) conf=$(s[2]) antimatch=$(s[3])")
    end
catch e
    println("ERROR: $e")
end
