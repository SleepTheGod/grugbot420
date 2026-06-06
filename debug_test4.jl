#!/usr/bin/env julia
# debug_test4.jl — Detailed step-by-step trace of fire_one for specific inputs
# Patches the scan_specimens function with verbose debug output

using Pkg
Pkg.activate(".")

# We need to add debug output to the scanning pipeline
# Strategy: call words_to_signal manually and cheap_scan manually for our test inputs

redirect_stdout(devnull) do
    include("src/Main.jl")
end

println("=" ^ 60)
println("DEBUG TEST 4: Manual signal + scan trace")
println("=" ^ 60)

# Load the specimen first
specimen_path = joinpath(@__DIR__, "specimens", "comprehensive_specimen.json")
println("\nLoading specimen from: $specimen_path")
try
    load_specimen_from_file!(specimen_path)
    println("Load result: OK")
catch e
    println("Load FAILED: $e")
    exit(1)
end

# Test inputs that should match but don't
test_cases = [
    ("derivative", "node_math_001", "derivative"),
    ("danger", "node_surv_001", "danger"),
    ("i feel sad", "node_emp_001", "i feel sad"),
    ("free will", "node_phil_003", "free will"),
    ("imagine", "node_crea_003", "imagine"),
    ("hello", "node_greet_001", "hello"),  # This one WORKS — control case
    ("write a poem", "node_crea_001", "write a poem"),
    ("pythagorean theorem", "node_math_003", "pythagorean theorem"),
    ("what is consciousness", "node_phil_001", "what is consciousness"),
    ("watch out", "node_warn_001", "watch out"),
]

for (input_text, expected_node_id, expected_pattern) in test_cases
    println("\n" * "=" ^ 60)
    println("INPUT: \"$input_text\" → expected node: $expected_node_id (pattern=\"$expected_pattern\")")
    println("=" ^ 60)
    
    # Step 1: Compute input signal
    input_signal = words_to_signal(input_text)
    println("  Input signal ($(length(input_signal)) elements): $input_signal")
    
    # Step 2: Get node from NODE_MAP
    node = lock(NODE_LOCK) do
        get(NODE_MAP, expected_node_id, nothing)
    end
    
    if isnothing(node)
        println("  NODE NOT FOUND: $expected_node_id")
        continue
    end
    
    println("  Node signal ($(length(node.signal)) elements): $(node.signal)")
    println("  Node pattern: \"$(node.pattern)\"")
    println("  Node is_grave: $(node.is_grave)")
    println("  Node is_image_node: $(node.is_image_node)")
    println("  Node is_antimatch_node: $(node.is_antimatch_node)")
    println("  Node is_unlinkable: $(node.is_unlinkable)")
    println("  Node strength: $(node.strength)")
    println("  Node relational_patterns: $(node.relational_patterns)")
    println("  Node required_relations: $(node.required_relations)")
    
    # Step 3: Literal token pre-gate check
    input_token_set = Set(split(lowercase(strip(input_text))))
    pattern_token_set = Set(split(lowercase(strip(node.pattern))))
    shared = intersect(pattern_token_set, input_token_set)
    shared_content = Set(t for t in shared if !(t in STOPWORDS))
    
    println("  Input tokens: $input_token_set")
    println("  Pattern tokens: $pattern_token_set")
    println("  Shared tokens: $shared")
    println("  Shared content tokens (no stopwords): $shared_content")
    
    if isempty(shared_content)
        println("  *** LITERAL PRE-GATE FAIL: No content tokens shared → node rejected! ***")
        # Continue to check if it would have matched via scanner
    else
        literal_hit = true
        pat_content = Set(t for t in pattern_token_set if !(t in STOPWORDS))
        inp_content = Set(t for t in input_token_set if !(t in STOPWORDS))
        union_content = union(pat_content, inp_content)
        union_size = isempty(union_content) ? length(union(pattern_token_set, input_token_set)) : length(union_content)
        literal_jaccard = length(shared_content) / max(1, union_size)
        println("  LITERAL HIT: true, Jaccard=$(round(literal_jaccard, digits=3))")
    end
    
    # Step 4: Direct scanner test
    println("\n  --- Direct scanner test ---")
    target_signal = input_signal
    node_signal = node.signal
    
    # Check BUG-004 condition
    if length(target_signal) < length(node_signal)
        println("  BUG-004: pattern ($(length(node_signal)) tokens) > input ($(length(target_signal)) tokens)")
        # Swap args for bidirectional scan
        try
            best_idx, token_conf = _bidirectional_cheap_scan(
                node_signal, target_signal;
                threshold=CHEAP_SCAN_THRESHOLD
            )
            println("  BUG-004 bidirectional scan: best_idx=$best_idx conf=$(round(token_conf, digits=6))")
            penalty = token_conf * BUG_004_PENALTY
            adjusted = max(0.0, token_conf - penalty)
            println("  After BUG-004 penalty: $(round(adjusted, digits=6))")
        catch e
            println("  BUG-004 scan ERROR: $e")
        end
    else
        # Normal bidirectional scan
        try
            best_idx, token_conf = _bidirectional_cheap_scan(
                target_signal, node_signal;
                threshold=CHEAP_SCAN_THRESHOLD
            )
            println("  Normal bidirectional scan: best_idx=$best_idx conf=$(round(token_conf, digits=6))")
        catch e
            println("  Normal scan ERROR: $e")
            # Check if it's PatternNotFoundError
            if e isa PatternNotFoundError
                println("  (PatternNotFoundError — scanner says no match)")
            end
        end
        
        # Also try medium and high-res
        try
            best_idx2, token_conf2 = medium_scan(target_signal, node_signal; threshold=MEDIUM_SCAN_THRESHOLD)
            println("  Medium scan: best_idx=$best_idx2 conf=$(round(token_conf2, digits=6))")
        catch e2
            if e2 isa PatternNotFoundError
                println("  Medium scan: PatternNotFoundError")
            else
                println("  Medium scan ERROR: $e2")
            end
        end
        
        try
            best_idx3, token_conf3 = high_res_scan(target_signal, node_signal; threshold=HIGH_SCAN_THRESHOLD)
            println("  High-res scan: best_idx=$best_idx3 conf=$(round(token_conf3, digits=6))")
        catch e3
            if e3 isa PatternNotFoundError
                println("  High-res scan: PatternNotFoundError")
            else
                println("  High-res scan ERROR: $e3")
            end
        end
    end
    
    # Step 5: Relational check
    println("\n  --- Relational dialectics ---")
    user_triples = try
        extract_relational_triples(input_text)
    catch e
        println("  Triple extraction error: $e")
        RelationalTriple[]
    end
    println("  User triples: $user_triples")
    
    rel_conf, is_antimatch = evaluate_relational_dialectics(
        user_triples, node.relational_patterns, node.required_relations, node.relation_weights
    )
    println("  rel_conf=$(round(rel_conf, digits=3)), is_antimatch=$is_antimatch")
    if rel_conf == -9999.0
        println("  *** REQUIRED RELATION MISSING → node rejected! ***")
    end
end

println("\n" * "=" ^ 60)
println("DONE")
println("=" ^ 60)
