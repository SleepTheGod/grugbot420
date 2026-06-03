#!/usr/bin/env julia
# Smoke test for v7.55 relational triples + dynamic relationals
#
# Access pattern: `using GrugBot420` then `getfield` for non-exported symbols
# (RelationalTriple, evaluate_relational_dialectics, _ENGINE_SIGIL_TABLE).
# Exported symbols (SigilRegistry.*, register_relation_sigil!, etc.) are used
# directly.

using Pkg
Pkg.activate("/workspace/grugbot420")

using GrugBot420

println("=" ^ 60)
println("SMOKE TEST: Relational Triples + Dynamic Relationals")
println("=" ^ 60)

# Access non-exported engine internals
const RT  = getfield(GrugBot420, :RelationalTriple)
const ERD = getfield(GrugBot420, :evaluate_relational_dialectics)
const ET  = getfield(GrugBot420, :_ENGINE_SIGIL_TABLE)

pass = 0
fail = 0

function check(label, condition)
    global pass, fail
    if condition
        println("  ✅ $label")
        pass += 1
    else
        println("  ❌ $label")
        fail += 1
    end
end

# --- Test 1: Register a relation sigil ---
println("\n--- Test 1: Register relation sigil ---")
try
    SigilRegistry.register_relation_sigil!(ET;
        name = "causes",
        expansion = ["causes", "produces", "creates", "generates"],
        provenance = "smoke-test")
    check("Relation sigil '&causes' registered", true)
catch e
    check("Relation sigil '&causes' registered (threw: $e)", false)
end

# --- Test 2: Verify is_relation_sigil ---
println("\n--- Test 2: is_relation_sigil check ---")
check("'causes' is a relation sigil", SigilRegistry.is_relation_sigil(ET, "causes"))
check("'n' is NOT a relation sigil (it's a lambda)", !SigilRegistry.is_relation_sigil(ET, "n"))

# --- Test 3: Expand relation sigil ---
println("\n--- Test 3: expand_relation_sigil ---")
alts = SigilRegistry.expand_relation_sigil(ET, "causes")
println("  Alternatives: $(alts)")
check("Expansion == [causes,produces,creates,generates]", alts == ["causes", "produces", "creates", "generates"])

# --- Test 4: expand_relation_if_sigil (the main helper) ---
println("\n--- Test 4: expand_relation_if_sigil ---")
expanded = SigilRegistry.expand_relation_if_sigil(ET, "&causes")
println("  &causes → $(expanded)")
check("Sigil expansion works", expanded == ["causes", "produces", "creates", "generates"])

literal = SigilRegistry.expand_relation_if_sigil(ET, "burns")
println("  burns → $(literal)")
check("Literal passthrough works", literal == ["burns"])

# --- Test 5: Static relational triple matching ---
println("\n--- Test 5: Static triple matching (existing behavior) ---")
user_triples = [RT("fire", "burns", "wood")]
node_triples = [RT("fire", "burns", "wood")]
score, is_anti = ERD(user_triples, node_triples, String[], Dict{String,Float64}())
println("  Score: $score, Antimatch: $is_anti")
check("Static triple match works (score > 0, not anti)", score > 0.0 && !is_anti)

# --- Test 6: Dynamic relational — sigil in node triple ---
println("\n--- Test 6: Dynamic relational matching ---")
node_triples_dyn = [RT("fire", "&causes", "heat")]
user_triples_1 = [RT("fire", "produces", "heat")]  # alt match
user_triples_2 = [RT("fire", "causes", "heat")]    # primary match
user_triples_3 = [RT("fire", "destroys", "heat")]  # no match

score1, _ = ERD(user_triples_1, node_triples_dyn, ["&causes"], Dict{String,Float64}())
println("  'produces' vs '&causes' (req=&causes): score=$score1")
check("Dynamic: 'produces' matches '&causes'", score1 > 0.0)

score2, _ = ERD(user_triples_2, node_triples_dyn, ["&causes"], Dict{String,Float64}())
println("  'causes' vs '&causes' (req=&causes): score=$score2")
check("Dynamic: 'causes' matches '&causes'", score2 > 0.0)

score3, _ = ERD(user_triples_3, node_triples_dyn, ["&causes"], Dict{String,Float64}())
println("  'destroys' vs '&causes' (req=&causes): score=$score3")
check("Dynamic: 'destroys' correctly fails required_relations gate (sentinel)", score3 == -9999.0)

# --- Test 7: Dynamic relational WITHOUT required_relations gate ---
println("\n--- Test 7: Dynamic relational without required gate ---")
score4, _ = ERD(user_triples_3, node_triples_dyn, String[], Dict{String,Float64}())
println("  'destroys' vs '&causes' (no gate): score=$score4")
check("No crash, no false positive, no sentinel (score ≤ 0 and ≠ -9999)", score4 <= 0.0 && score4 != -9999.0)

# --- Test 8: Verify :relation class in SIGIL_CLASSES ---
println("\n--- Test 8: Sigil class/phase enums ---")
check(":relation in SIGIL_CLASSES", :relation in SigilRegistry.SIGIL_CLASSES)
check(":relation in STAGE1_ACTIVE_CLASSES", :relation in SigilRegistry.STAGE1_ACTIVE_CLASSES)
check(":relation in STAGE1_ACTIVE_PHASES", :relation in SigilRegistry.STAGE1_ACTIVE_PHASES)

println("\n" * "=" ^ 60)
println("SMOKE TEST COMPLETE: $pass passed, $fail failed")
println("=" ^ 60)

if fail > 0
    exit(1)
end
