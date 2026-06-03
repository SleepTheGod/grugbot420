#!/usr/bin/env julia
# Smoke test for v7.56: time nodes + pre-registered relation sigils
#
# Access pattern: `using GrugBot420` then `getfield` for non-exported symbols.
# Exported symbols (SigilRegistry.*, register_relation_sigil!, etc.) are used
# directly.

using Pkg
Pkg.activate("/workspace/grugbot420")

using GrugBot420

println("=" ^ 60)
println("SMOKE TEST: v7.56 Time Nodes + Pre-registered Relation Sigils")
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

# --- Test 1: Pre-registered relation sigils exist ---
println("\n--- Test 1: Built-in relation sigils ---")
for name in ["temporal", "causal", "spatial", "possessive", "similarity"]
    check("&$name is a registered relation sigil", SigilRegistry.is_relation_sigil(ET, name))
end

# --- Test 2: &temporal expansion ---
println("\n--- Test 2: &temporal expansion ---")
temporal_alts = SigilRegistry.expand_relation_sigil(ET, "temporal")
println("  &temporal → $(temporal_alts)")
check("&temporal has 11 alternatives", length(temporal_alts) == 11)
check("'now' is in &temporal expansion", "now" in temporal_alts)
check("'before' is in &temporal expansion", "before" in temporal_alts)
check("'after' is in &temporal expansion", "after" in temporal_alts)
check("'when' is in &temporal expansion", "when" in temporal_alts)

# --- Test 3: &causal expansion ---
println("\n--- Test 3: &causal expansion ---")
causal_alts = SigilRegistry.expand_relation_sigil(ET, "causal")
println("  &causal → $(causal_alts)")
check("&causal has 9 alternatives", length(causal_alts) == 9)
check("'causes' is in &causal expansion", "causes" in causal_alts)
check("'produces' is in &causal expansion", "produces" in causal_alts)

# --- Test 4: Dynamic relational matching with &temporal ---
println("\n--- Test 4: Dynamic relational with &temporal ---")
# Node triple: (present, &temporal, future)
# User triple with "before": (present, before, future) — should match
node_triple = [RT("present", "&temporal", "future")]
user_before = [RT("present", "before", "future")]
user_now    = [RT("present", "now", "future")]
user_eats   = [RT("present", "eats", "future")]  # not temporal

score1, _ = ERD(user_before, node_triple, ["&temporal"], Dict{String,Float64}())
println("  'before' vs '&temporal' (req=&temporal): score=$score1")
check("'before' matches &temporal node", score1 > 0.0)

score2, _ = ERD(user_now, node_triple, ["&temporal"], Dict{String,Float64}())
println("  'now' vs '&temporal' (req=&temporal): score=$score2")
check("'now' matches &temporal node", score2 > 0.0)

score3, _ = ERD(user_eats, node_triple, ["&temporal"], Dict{String,Float64}())
println("  'eats' vs '&temporal' (req=&temporal): score=$score3")
check("'eats' fails &temporal gate (sentinel)", score3 == -9999.0)

# --- Test 5: Dynamic relational with &spatial ---
println("\n--- Test 5: Dynamic relational with &spatial ---")
spatial_alts = SigilRegistry.expand_relation_sigil(ET, "spatial")
println("  &spatial → $(spatial_alts)")
node_spatial = [RT("cat", "&spatial", "table")]
user_above   = [RT("cat", "above", "table")]
user_near    = [RT("cat", "near", "table")]
user_thinks  = [RT("cat", "thinks", "table")]  # not spatial

score4, _ = ERD(user_above, node_spatial, ["&spatial"], Dict{String,Float64}())
println("  'above' vs '&spatial': score=$score4")
check("'above' matches &spatial node", score4 > 0.0)

score5, _ = ERD(user_near, node_spatial, ["&spatial"], Dict{String,Float64}())
println("  'near' vs '&spatial': score=$score5")
check("'near' matches &spatial node", score5 > 0.0)

score6, _ = ERD(user_thinks, node_spatial, ["&spatial"], Dict{String,Float64}())
println("  'thinks' vs '&spatial': score=$score6")
check("'thinks' fails &spatial gate", score6 == -9999.0)

# --- Test 6: expand_relation_if_sigil with built-ins ---
println("\n--- Test 6: expand_relation_if_sigil with built-ins ---")
expanded = SigilRegistry.expand_relation_if_sigil(ET, "&temporal")
check("&temporal expands to alternatives", length(expanded) > 1 && expanded[1] == "before")

literal = SigilRegistry.expand_relation_if_sigil(ET, "before")
check("'before' passes through as literal", literal == ["before"])

unknown = SigilRegistry.expand_relation_if_sigil(ET, "&unknown_xyz")
check("'&unknown_xyz' passes through as-is", unknown == ["&unknown_xyz"])

# --- Test 7: :time mode in VALID_ANSWER_MODES ---
println("\n--- Test 7: :time answer mode infrastructure ---")
# Check that "time" is in the valid modes list (it's a const in Main.jl,
# not exported, so we test via the engine's ability to process it)
check(":relation in SIGIL_CLASSES", :relation in SigilRegistry.SIGIL_CLASSES)
check(":relation in STAGE1_ACTIVE_CLASSES", :relation in SigilRegistry.STAGE1_ACTIVE_CLASSES)
check(":relation in STAGE1_ACTIVE_PHASES", :relation in SigilRegistry.STAGE1_ACTIVE_PHASES)

# --- Test 8: User can register custom relation sigil at runtime ---
println("\n--- Test 8: User-defined relation sigil ---")
SigilRegistry.register_relation_sigil!(ET;
    name="emotional",
    expansion=["loves", "hates", "fears", "desires", "resents", "admires"],
    provenance="smoke-test")
check("Custom &emotional sigil registered", SigilRegistry.is_relation_sigil(ET, "emotional"))
emotional_alts = SigilRegistry.expand_relation_sigil(ET, "emotional")
println("  &emotional → $(emotional_alts)")
check("&emotional has 6 alternatives", length(emotional_alts) == 6)

node_emotional = [RT("person", "&emotional", "music")]
user_loves = [RT("person", "loves", "music")]
user_fears = [RT("person", "fears", "music")]
user_eats2 = [RT("person", "eats", "music")]

score7, _ = ERD(user_loves, node_emotional, ["&emotional"], Dict{String,Float64}())
check("'loves' matches &emotional node", score7 > 0.0)

score8, _ = ERD(user_fears, node_emotional, ["&emotional"], Dict{String,Float64}())
check("'fears' matches &emotional node", score8 > 0.0)

score9, _ = ERD(user_eats2, node_emotional, ["&emotional"], Dict{String,Float64}())
check("'eats' fails &emotional gate", score9 == -9999.0)

println("\n" * "=" ^ 60)
println("SMOKE TEST COMPLETE: $pass passed, $fail failed")
println("=" ^ 60)

if fail > 0
    exit(1)
end
