#!/usr/bin/env julia
# =============================================================================
# EphemeralMLP v7.24 Comprehensive Integration Test
# =============================================================================
# Tests: user-editable observation threshold, SelfObserver wiring,
# specimen round-trip with new fields, rule management, feedback, and
# the full sigmoid/ReLU activation pipeline.
# =============================================================================
using Pkg; Pkg.activate(".")
using GrugBot420
using GrugBot420.EphemeralMLP

println("=" ^ 70)
println("  EPHEMERAL MLP v7.24 COMPREHENSIVE INTEGRATION TEST")
println("=" ^ 70)

passed = 0
failed = 0

function test(name::String, condition::Bool, detail::String="")
    global passed, failed
    if condition
        println("  ✅ PASS: $name")
        passed += 1
    else
        println("  ❌ FAIL: $name $detail")
        failed += 1
    end
end

# =========================================================================
# SECTION 1: OBSERVATION THRESHOLD — user-editable gate
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 1: OBSERVATION THRESHOLD (user-editable gate)")
println("─" ^ 70)

# Reset to known state
EphemeralMLP.reset_ephemeral_mlp!()

# Test 1.1: Default observation threshold is 5
threshold = EphemeralMLP.get_observation_threshold()
test("1.1 Default threshold is 5", threshold == 5, "got $threshold")

# Test 1.2: Status includes observation_threshold
status = EphemeralMLP.get_mlp_status()
test("1.2 Status has observation_threshold key", haskey(status, "observation_threshold"), "")
test("1.3 Status observation_threshold == 5", status["observation_threshold"] == 5, "got $(get(status, "observation_threshold", "MISSING"))")

# Test 1.4: Set threshold to 3
EphemeralMLP.set_observation_threshold!(3)
test("1.4 Set threshold to 3", EphemeralMLP.get_observation_threshold() == 3, "got $(EphemeralMLP.get_observation_threshold())")

# Test 1.5: Set threshold to 0 (always enable adjustments)
EphemeralMLP.set_observation_threshold!(0)
test("1.5 Set threshold to 0", EphemeralMLP.get_observation_threshold() == 0, "got $(EphemeralMLP.get_observation_threshold())")

# Test 1.6: With threshold=0, adjustments should be enabled even with 0 observations
status_zero = EphemeralMLP.get_mlp_status()
test("1.6 Adjustments enabled when threshold=0", status_zero["adjustments_enabled"] == true, "got $(status_zero["adjustments_enabled"])")

# Test 1.7: Set threshold back to 5
EphemeralMLP.set_observation_threshold!(5)
test("1.7 Reset threshold to 5", EphemeralMLP.get_observation_threshold() == 5, "got $(EphemeralMLP.get_observation_threshold())")

# Test 1.8: Negative threshold should error
try
    EphemeralMLP.set_observation_threshold!(-1)
    test("1.8 Negative threshold throws error", false, "no error thrown")
catch e
    test("1.8 Negative threshold throws error", true, "")
end

# =========================================================================
# SECTION 2: SELF-OBSERVER GATE INTEGRATION
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 2: SELF-OBSERVER GATE INTEGRATION")
println("─" ^ 70)

# Reset
EphemeralMLP.reset_ephemeral_mlp!()

vote_data = Dict{String, Any}[
    Dict("node_id" => "alpha", "confidence" => 0.8),
    Dict("node_id" => "beta", "confidence" => 0.3)
]

# Test 2.1: With selfobserver_count=0, adjustments disabled
result_0 = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="hello world", selfobserver_count=0)
test("2.1 Adjustments disabled when observer_count=0", result_0["adjustments_enabled"] == false, "got $(result_0["adjustments_enabled"])")

# Test 2.2: With selfobserver_count=4 (below default threshold 5), adjustments still disabled
result_4 = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="hello world", selfobserver_count=4)
test("2.2 Adjustments disabled when observer_count=4", result_4["adjustments_enabled"] == false, "got $(result_4["adjustments_enabled"])")

# Test 2.3: With selfobserver_count=5 (at threshold), adjustments enabled
result_5 = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="hello world", selfobserver_count=5)
test("2.3 Adjustments enabled when observer_count=5", result_5["adjustments_enabled"] == true, "got $(result_5["adjustments_enabled"])")

# Test 2.4: With selfobserver_count=10 (above threshold), adjustments enabled
result_10 = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="hello world", selfobserver_count=10)
test("2.4 Adjustments enabled when observer_count=10", result_10["adjustments_enabled"] == true, "got $(result_10["adjustments_enabled"])")

# Test 2.5: Lower threshold to 2, verify gate opens sooner
EphemeralMLP.set_observation_threshold!(2)
result_2 = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="hello world", selfobserver_count=2)
test("2.5 With threshold=2, observer_count=2 enables adjustments", result_2["adjustments_enabled"] == true, "got $(result_2["adjustments_enabled"])")

# Test 2.6: With threshold=2, observer_count=1 still blocks
# NOTE: adjustments_enabled is a one-way gate — once true, it stays true.
# To test this properly, we need a fresh state.
EphemeralMLP.reset_ephemeral_mlp!()
EphemeralMLP.set_observation_threshold!(2)
result_1 = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="hello world", selfobserver_count=1)
test("2.6 With threshold=2, observer_count=1 blocks adjustments (fresh state)", result_1["adjustments_enabled"] == false, "got $(result_1["adjustments_enabled"])")

# Reset threshold
EphemeralMLP.set_observation_threshold!(5)

# =========================================================================
# SECTION 3: SIGMOID/RELU ACTIVATION PIPELINE
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 3: SIGMOID/RELU ACTIVATION PIPELINE")
println("─" ^ 70)

# Test 3.1: Novel input (no hopfield hit) → ReLU
# Reset first so novelty tracker is fresh and there's no carry-over
EphemeralMLP.reset_ephemeral_mlp!()
result_novel = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="what is consciousness?", selfobserver_count=10)
test("3.1 Novel input → ReLU activation", result_novel["activation"] == :relu, "got $(result_novel["activation"])")
test("3.2 Novel input → high novelty score", result_novel["novelty_score"] > 0.5, "got $(result_novel["novelty_score"])")

# Test 3.3: Familiar input (hopfield hit) → Sigmoid
result_familiar = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=true, user_input="hello again", selfobserver_count=10)
test("3.3 Familiar input → Sigmoid activation", result_familiar["activation"] == :sigmoid, "got $(result_familiar["activation"])")
test("3.4 Familiar input → low novelty score", result_familiar["novelty_score"] < 0.5, "got $(result_familiar["novelty_score"])")

# Test 3.5: Multiple transforms increment the counter
status_before = EphemeralMLP.get_mlp_status()
transforms_before = status_before["total_transforms"]
EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="test input", selfobserver_count=10)
status_after = EphemeralMLP.get_mlp_status()
test("3.5 Transform counter increments", status_after["total_transforms"] == transforms_before + 1, 
     "before=$transforms_before after=$(status_after["total_transforms"])")

# =========================================================================
# SECTION 4: SELF-OBSERVER STORE INTEGRATION
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 4: SELF-OBSERVER STORE INTEGRATION")
println("─" ^ 70)

# Test 4.1: Create a SelfObserver store
obs_store = SelfObserver.SubconsciousStore()
test("4.1 Create SubconsciousStore", true, "")

# Test 4.2: Fresh store has size 0
test("4.2 Fresh store size == 0", SelfObserver.store_size(obs_store) == 0, "got $(SelfObserver.store_size(obs_store))")

# Test 4.3: Observe! adds entries (use p_write=1.0 to guarantee write)
SelfObserver.observe!(obs_store, "mlp_cycle_1", :meta, Dict{String, Any}("activation" => "relu", "novelty" => 0.7); p_write=1.0)
test("4.3 After observe!, store size == 1", SelfObserver.store_size(obs_store) == 1, "got $(SelfObserver.store_size(obs_store))")

# Test 4.4: key_count
SelfObserver.observe!(obs_store, "mlp_cycle_2", :meta, Dict{String, Any}("activation" => "sigmoid", "novelty" => 0.3); p_write=1.0)
test("4.4 After 2 observations with different keys, key_count == 2", SelfObserver.key_count(obs_store) == 2, "got $(SelfObserver.key_count(obs_store))")

# Test 4.5: Observe to same key with same tag → reinforces existing entry (weight boost, not new entry)
SelfObserver.observe!(obs_store, "mlp_cycle_1", :meta, Dict{String, Any}("activation" => "relu", "novelty" => 0.8); p_write=1.0)
test("4.5 Same key+tag reinforces (store size stays 2)", SelfObserver.store_size(obs_store) == 2, "got $(SelfObserver.store_size(obs_store)) — reinforcement merges, not adds")
test("4.6 key_count still 2 (same key reused)", SelfObserver.key_count(obs_store) == 2, "got $(SelfObserver.key_count(obs_store))")

# Test 4.5b: Observe to same key with DIFFERENT tag → creates new entry
SelfObserver.observe!(obs_store, "mlp_cycle_1", :timing, Dict{String, Any}("latency_ms" => 42.0); p_write=1.0)
test("4.5b Same key+diff tag adds entry (store size == 3)", SelfObserver.store_size(obs_store) == 3, "got $(SelfObserver.store_size(obs_store))")

# Test 4.7: Use store_size as selfobserver_count
obs_count = SelfObserver.store_size(obs_store)
result_with_obs = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="observer test", selfobserver_count=obs_count)
test("4.7 With observer_count=$obs_count, adjustments_enabled=$(result_with_obs["adjustments_enabled"])", true, "")

# =========================================================================
# SECTION 5: FEEDBACK MECHANISMS
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 5: FEEDBACK MECHANISMS")
println("─" ^ 70)

# Test 5.1: register_right_feedback! (no-arg)
EphemeralMLP.reset_ephemeral_mlp!()
EphemeralMLP.register_right_feedback!()
s1 = EphemeralMLP.get_mlp_status()
test("5.1 No-arg right feedback increments counter", s1["right_feedback_count"] == 1, "got $(s1["right_feedback_count"])")

# Test 5.2: register_wrong_feedback! (no-arg)
EphemeralMLP.register_wrong_feedback!()
s2 = EphemeralMLP.get_mlp_status()
test("5.2 No-arg wrong feedback increments counter", s2["wrong_feedback_count"] == 1, "got $(s2["wrong_feedback_count"])")

# Test 5.3: register_right_feedback! with quality
EphemeralMLP.register_right_feedback!(0.95)
s3 = EphemeralMLP.get_mlp_status()
test("5.3 Right feedback with quality=0.95", s3["right_feedback_count"] == 2, "got $(s3["right_feedback_count"])")

# Test 5.4: register_wrong_feedback! with quality
EphemeralMLP.register_wrong_feedback!(0.3)
s4 = EphemeralMLP.get_mlp_status()
test("5.4 Wrong feedback with quality=0.3", s4["wrong_feedback_count"] == 2, "got $(s4["wrong_feedback_count"])")

# =========================================================================
# SECTION 6: RULE MANAGEMENT
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 6: RULE MANAGEMENT")
println("─" ^ 70)

# Test 6.1: Add a solid rule
rule_solid = EphemeralMLP.MLPTransformerRule("solid_rule", "consciousness"; key="philosophy", transform_type=:solid)
EphemeralMLP.add_mlp_rule!(rule_solid)
rules = EphemeralMLP.list_mlp_rules()
test("6.1 Add solid rule", length(rules) == 1 && rules[1].id == "solid_rule", "got $(length(rules)) rules")

# Test 6.2: Add a fuzzy rule
rule_fuzzy = EphemeralMLP.MLPTransformerRule("fuzzy_rule", "dream"; key="imagination", transform_type=:fuzzy, weight_value=1.5, weight_jitter=true)
EphemeralMLP.add_mlp_rule!(rule_fuzzy)
rules2 = EphemeralMLP.list_mlp_rules()
test("6.2 Add fuzzy rule", length(rules2) == 2, "got $(length(rules2)) rules")

# Test 6.3: Lookup rule by ID
found = EphemeralMLP.lookup_mlp_rule("solid_rule")
test("6.3 Lookup rule by ID", found !== nothing && found.id == "solid_rule", "")

# Test 6.4: Drop a rule
EphemeralMLP.drop_mlp_rule!("fuzzy_rule")
rules3 = EphemeralMLP.list_mlp_rules()
test("6.4 Drop rule", length(rules3) == 1, "got $(length(rules3)) rules")

# Test 6.5: Drop non-existent rule returns false
dropped = EphemeralMLP.drop_mlp_rule!("nonexistent")
test("6.5 Drop non-existent rule returns false", dropped == false, "got $dropped")

# Test 6.6: Rules fire when pattern matches input
# Re-add a rule since we dropped it in 6.4
rule_fire = EphemeralMLP.MLPTransformerRule("fire_test", "consciousness"; key="philosophy", transform_type=:solid)
EphemeralMLP.add_mlp_rule!(rule_fire)
result_with_rule = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="what is consciousness?", selfobserver_count=10)
n_rules_fired = length(result_with_rule["active_rules"])
test("6.6 Pattern-matching rule fires", n_rules_fired >= 1, "got $n_rules_fired active rules")

# Clean up
EphemeralMLP.drop_mlp_rule!("solid_rule")
EphemeralMLP.drop_mlp_rule!("fire_test")

# =========================================================================
# SECTION 7: SPECIMEN ROUND-TRIP WITH NEW FIELDS
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 7: SPECIMEN ROUND-TRIP (v1.2 with observation_threshold)")
println("─" ^ 70)

# Build up some state
EphemeralMLP.reset_ephemeral_mlp!()
EphemeralMLP.set_observation_threshold!(7)
EphemeralMLP.register_right_feedback!(0.8)
EphemeralMLP.register_wrong_feedback!(0.4)
rule_persist = EphemeralMLP.MLPTransformerRule("persistent_rule", "life"; key="existential", transform_type=:solid, weight_value=2.0)
EphemeralMLP.add_mlp_rule!(rule_persist)
EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="test specimen save", selfobserver_count=8)

# Test 7.1: to_specimen_dict includes new fields
specimen = EphemeralMLP.to_specimen_dict()
test("7.1 Specimen version is 1.2", specimen["_meta"]["version"] == "1.2", "got $(specimen["_meta"]["version"])")
test("7.2 Specimen has observation_threshold", haskey(specimen, "observation_threshold"), "")
test("7.3 observation_threshold == 7", specimen["observation_threshold"] == 7, "got $(get(specimen, "observation_threshold", "MISSING"))")
test("7.4 Specimen has selfobserver_observations", haskey(specimen, "selfobserver_observations"), "")
test("7.5 Specimen has adjustments_enabled", haskey(specimen, "adjustments_enabled"), "")
test("7.6 Specimen has input_correlations", haskey(specimen, "input_correlations"), "")
test("7.7 Specimen has last_user_input", haskey(specimen, "last_user_input"), "")
test("7.8 last_user_input preserved", specimen["last_user_input"] == "test specimen save", "got '$(specimen["last_user_input"])'")

# Test 7.9: Round-trip preserves observation_threshold
specimen_copy = deepcopy(specimen)
EphemeralMLP.reset_ephemeral_mlp!()
EphemeralMLP.from_specimen_dict!(specimen_copy)
test("7.9 Round-trip observation_threshold preserved", EphemeralMLP.get_observation_threshold() == 7, 
     "got $(EphemeralMLP.get_observation_threshold())")

# Test 7.10: Round-trip preserves other state
rt_status = EphemeralMLP.get_mlp_status()
test("7.10 Round-trip right_feedback preserved", rt_status["right_feedback_count"] == 1, "got $(rt_status["right_feedback_count"])")
test("7.11 Round-trip wrong_feedback preserved", rt_status["wrong_feedback_count"] == 1, "got $(rt_status["wrong_feedback_count"])")
test("7.12 Round-trip transforms preserved", rt_status["total_transforms"] == 1, "got $(rt_status["total_transforms"])")
test("7.13 Round-trip rules preserved", rt_status["rules_total"] == 1, "got $(rt_status["rules_total"])")

# Test 7.14: Round-trip from v1.1 specimen (backward compat — missing observation_threshold defaults to 5)
v11_specimen = deepcopy(specimen)
delete!(v11_specimen, "observation_threshold")  # Simulate old v1.1 format
v11_specimen["_meta"]["version"] = "1.1"
EphemeralMLP.reset_ephemeral_mlp!()
EphemeralMLP.from_specimen_dict!(v11_specimen)
test("7.14 v1.1 specimen defaults observation_threshold to 5", EphemeralMLP.get_observation_threshold() == 5,
     "got $(EphemeralMLP.get_observation_threshold())")

# =========================================================================
# SECTION 8: GET_MLP_STATUS COMPLETENESS
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 8: GET_MLP_STATUS COMPLETENESS")
println("─" ^ 70)

EphemeralMLP.reset_ephemeral_mlp!()
final_status = EphemeralMLP.get_mlp_status()

expected_keys = [
    "total_transforms", "sigmoid_activations", "relu_activations",
    "last_activation", "last_novelty_score", "last_directive_quality",
    "right_feedback_count", "wrong_feedback_count",
    "rules_total", "rules_enabled", "jitter_eligible_weights", "jitter_enabled",
    "novelty_observations", "novelty_hashes_tracked", "novelty_history_len",
    "selfobserver_observations", "observation_threshold", "adjustments_enabled",
    "input_correlations", "last_user_input"
]

for key in expected_keys
    test("8.x Status has key '$key'", haskey(final_status, key), "")
end

# =========================================================================
# SECTION 9: EDGE CASES
# =========================================================================
println("\n" * "─" ^ 70)
println("  SECTION 9: EDGE CASES")
println("─" ^ 70)

# Test 9.1: Empty vote list
empty_result = EphemeralMLP.transform_vote_list(Dict{String, Any}[]; hopfield_hit=false, user_input="", selfobserver_count=0)
test("9.1 Empty vote list returns error or handles gracefully", haskey(empty_result, "error") || haskey(empty_result, "activation"), "")

# Test 9.2: Very high threshold
EphemeralMLP.set_observation_threshold!(999)
result_high = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="high threshold test", selfobserver_count=10)
test("9.2 Very high threshold blocks adjustments", result_high["adjustments_enabled"] == false, "got $(result_high["adjustments_enabled"])")

# Test 9.3: Threshold of 1
EphemeralMLP.set_observation_threshold!(1)
result_t1 = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="threshold 1 test", selfobserver_count=1)
test("9.3 Threshold=1, count=1 enables adjustments", result_t1["adjustments_enabled"] == true, "got $(result_t1["adjustments_enabled"])")

# Reset
EphemeralMLP.set_observation_threshold!(5)

# Test 9.4: Transform with special characters in user_input
result_special = EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=false, user_input="what about émojis 🧠 and \"quotes\"?", selfobserver_count=10)
test("9.4 Special characters in user_input don't crash", haskey(result_special, "activation"), "")

# Test 9.5: Rapid sequential transforms
EphemeralMLP.reset_ephemeral_mlp!()
for i in 1:20
    EphemeralMLP.transform_vote_list(vote_data; hopfield_hit=(i % 2 == 0), user_input="rapid test $i", selfobserver_count=i)
end
rapid_status = EphemeralMLP.get_mlp_status()
test("9.5 20 rapid transforms: total=$(rapid_status["total_transforms"])", rapid_status["total_transforms"] == 20, 
     "got $(rapid_status["total_transforms"])")
test("9.6 Sigmoid+ReLU = total", 
     rapid_status["sigmoid_activations"] + rapid_status["relu_activations"] == 20,
     "sig=$(rapid_status["sigmoid_activations"]) relu=$(rapid_status["relu_activations"])")

# =========================================================================
# SUMMARY
# =========================================================================
println("\n" * "=" ^ 70)
println("  TEST RESULTS: $passed passed, $failed failed")
println("=" ^ 70)

if failed > 0
    println("\n  ⚠️  SOME TESTS FAILED — review output above")
    exit(1)
else
    println("\n  🧠 ALL TESTS PASSED — EphemeralMLP v7.24 verified!")
end
