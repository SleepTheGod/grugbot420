#!/usr/bin/env julia --project=.
# =============================================================================
# Idle Systems Integration Test v6
# =============================================================================
# Tests ALL idle systems: mitosis, chatter, phagy (all 12 automata)
# Accesses GrugBot420 internals via qualified names since they're not exported.
#
# ⚠️⚠️⚠️  HOPFIELD IS DEAD. It was commented out ages ago. The
#     HOPFIELD_CACHE and HOPFIELD_CACHE_LOCK positional args in run_phagy!()
#     are vestigial — automaton 7 (CACHE_VALIDATOR) is permanently disabled.
#     Do NOT waste time on hopfield. Ever. They will be cleaned up when the
#     function signature is next refactored.
# =============================================================================

using GrugBot420
using JSON
using Random

# Qualify all internal symbols
const GB = GrugBot420

const TEST_RESULTS = Dict{String, Any}()
const ERRORS = String[]

function main()
    println("=" ^ 70)
    println("IDLE SYSTEMS INTEGRATION TEST v6")
    println("=" ^ 70)
    println()

    # ── PHASE 1: Build specimen ─────────────────────────────────────────────
    println("─" ^ 70)
    println("PHASE 1: BUILD SPECIMEN")
    println("─" ^ 70)

    lobes = [
        ("AlphaLobe",    "alpha primary core foundation base"),
        ("BetaLobe",     "beta secondary support auxiliary help"),
        ("GammaLobe",    "gamma tertiary extension branch reach"),
        ("DeltaLobe",    "delta change transformation shift evolve"),
        ("EpsilonLobe",  "epsilon precision accuracy exact detail"),
        ("ZetaLobe",     "zeta zeal enthusiasm energy vigor"),
        ("EtaLobe",      "eta efficiency economy optimal stream"),
        ("ThetaLobe",    "theta thought contemplation reflection mind"),
        ("IotaLobe",     "iota small detail particular specific"),
        ("KappaLobe",    "kappa knowledge wisdom understanding learn"),
        ("LambdaLobe",   "lambda logic inference deduction reason"),
    ]

    for (name, subj) in lobes
        try
            GB.Lobe.create_lobe!(name, subj)
            println("  Created lobe: $name")
        catch e
            println("  ⚠️  Failed to create lobe $name: $e")
        end
    end
    println("  Created $(length(lobes)) lobes")

    # Connect lobes (function is connect_lobes! not connect_lobe!)
    for i in 1:length(lobes)
        for j in i+1:min(i+2, length(lobes))
            try
                GB.Lobe.connect_lobes!(lobes[i][1], lobes[j][1])
            catch e
                println("  ⚠️  Failed to connect $(lobes[i][1])-$(lobes[j][1]): $e")
            end
        end
    end
    println("  Connected adjacent lobes")

    # Grow 5 nodes per lobe = 55 total (above mitosis gate of 10)
    # create_node signature: create_node(pattern, action_packet, data, drop_table)
    node_count = 0
    for (lobe_idx, (lobe_name, subj)) in enumerate(lobes)
        words = split(subj)
        for n in 1:5
            node_count += 1
            w = words[((n-1) % length(words)) + 1]
            pattern = "n$(node_count) $(w) topic$(node_count)"
            prompt = "Grug handles $(w) topic$(node_count)."
            try
                node_data = Dict{String,Any}(
                    "system_prompt" => prompt,
                    "noun_anchors" => [string(w)],
                    "voice_register" => "plain",
                    "frame_hints" => ["plain"],
                    "lobe_id" => lobe_name,
                )
                GB.create_node(
                    pattern,
                    "respond[answer]^4|reason[think]^3|support[help]^2",
                    node_data,
                    String[]
                )
            catch e
                println("  ⚠️  Failed to grow node $node_count: $e")
            end
        end
    end
    println("  Grew $node_count nodes")

    # Count alive nodes
    alive_count = lock(GB.NODE_LOCK) do
        count(n -> !n.is_grave && !n.is_image_node, values(GB.NODE_MAP))
    end
    println("  Alive non-image nodes: $alive_count")
    TEST_RESULTS["alive_nodes"] = alive_count

    if alive_count < 10
        println("  ❌ FATAL: Too few nodes for ANY idle system. Aborting.")
        return
    end
    println()

    # ── PHASE 2: Lower population gate for testing ───────────────────────────
    println("─" ^ 70)
    println("PHASE 2: LOWER POPULATION GATE FOR TESTING")
    println("─" ^ 70)

    prev_gates = GB.ChatterMode._override_test_gates!(min_population=10)
    println("  Lowered MIN_POPULATION_FOR_CHATTER from $(prev_gates.min_population) to 10")
    GB.LAST_INPUT_TIME[] = time() - 200
    println("  Set LAST_INPUT_TIME to 200s ago (forces idle)")
    println()

    # ── PHASE 3: Set up test data for v7.30 automata ──────────────────────────
    println("─" ^ 70)
    println("PHASE 3: SET UP TEST DATA FOR v7.30 AUTOMATA")
    println("─" ^ 70)

    # 3a. Zombie injector for INJECTOR_GRAVEYARD_SWEEP (automaton 8)
    print("  Setting up zombie injector... ")
    try
        lock(GB.EphemeralAutomaton._INJECTOR_LOCK) do
            disposition = GB.EphemeralAutomaton.InjectorDisposition(;
                trigger_action = :ACTION_ASSERT,
                keyword_hints = String["test"],
                confidence_weight = 0.5,
                probe_depth = 3,
                drop_table_walk_bias = 0.5,
            )
            zombie = GB.EphemeralAutomaton.ContextInjectorAgent(
                "test_zombie_1",
                "test_rule",
                disposition;
                injection_target = :scaffold,
                timeout_seconds = 1.0,
            )
            # Force status to :probing but timeout_at in the past (zombie!)
            zombie.status = :probing
            zombie.timeout_at = time() - 30.0
            GB.EphemeralAutomaton._ACTIVE_INJECTORS["test_zombie_1"] = zombie
        end
        println("✅ OK")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_zombie_injector: $e")
    end

    # 3b. Phase snapshots for PHASE_ACCUMULATOR_AGING (automaton 9)
    print("  Setting up phase snapshots... ")
    try
        acc = GB.EphemeralAutomaton._phase_accumulator()
        lock(acc.lock) do
            for i in 1:5
                key = "test_phase_$i"
                snap = GB.EphemeralAutomaton.PhaseSnapshot(
                    "snap_$i",
                    zeros(12);
                    trigger_action = :ACTION_ASSERT,
                    rule_id = "test_rule_$i",
                    atp_confidence = 0.5,
                )
                snap.timestamp = time() - (5 - i) * 100
                acc.entries[key] = snap
                acc.total_snapshots_recorded += 1
            end
        end
        println("✅ OK (5 snapshots)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_phase_snapshots: $e")
    end

    # 3c. Observer store entries for OBSERVER_STORE_PRUNE (automaton 10)
    print("  Setting up observer store entries... ")
    try
        for i in 1:20
            key = "test_obs_$(i % 5)"
            GB.SelfObserver.observe!(GB._MLP_OBSERVER_STORE, key, :lexical,
                Dict{String,Any}("content" => "test microlog $i", "idx" => i);
                p_write=1.0,
                salience=0.5,
                provenance=:test,
            )
        end
        println("✅ OK (~20 entries)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_observer_entries: $e")
    end

    # 3d. Sigils for SIGIL_CONSISTENCY_CHECK (automaton 11)
    # SIGIL_CLASSES = (:lambda, :macro, :tag, :glue, :functor, :procedure)
    # SIGIL_APPLIES_AT = (:bind, :match, :vote_shape, :tone, :render, ...)
    print("  Setting up test sigils... ")
    try
        GB.SigilRegistry.register_sigil!(GB._ENGINE_SIGIL_TABLE;
            name="testmacro",
            class=:macro,
            applies_at=:bind,
            lexicon=["alpha", "beta", "gamma"],
        )
        GB.SigilRegistry.register_sigil!(GB._ENGINE_SIGIL_TABLE;
            name="testtag",
            class=:tag,
            applies_at=:match,
        )
        println("✅ OK")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_sigils: $e")
    end

    # 3e. Trajectory entries for STALE_TRAJECTORY_TRIM (automaton 12)
    print("  Setting up trajectory entries... ")
    try
        lock(GB.ActionTonePredictor._trajectory_lock) do
            for i in 1:10
                entry = GB.ActionTonePredictor.TrajectoryEntry(
                    Dict(GB.ActionTonePredictor.ACTION_ASSERT => 0.5,
                         GB.ActionTonePredictor.ACTION_QUERY => 0.3,
                         GB.ActionTonePredictor.ACTION_COMMAND => 0.2),
                    Dict(GB.ActionTonePredictor.TONE_NEUTRAL => 0.6,
                         GB.ActionTonePredictor.TONE_CURIOUS => 0.4),
                    time() - (10 - i) * 50,
                )
                push!(GB.ActionTonePredictor._trajectory_buffer, entry)
            end
        end
        println("✅ OK (10 entries)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_trajectory_entries: $e")
    end

    # 3f. Rules for RULE_PRUNER (automaton 5)
    print("  Setting up test rules... ")
    try
        push!(GB.PHAGY_RULES_REF[], Dict{String,Any}(
            "pattern" => "test_rule_dormant",
            "fire_count" => 0,
            "dormancy_strikes" => 50,
            "is_dormant" => false,
        ))
        push!(GB.PHAGY_RULES_REF[], Dict{String,Any}(
            "pattern" => "test_rule_active",
            "fire_count" => 100,
            "dormancy_strikes" => 0,
            "is_dormant" => false,
        ))
        println("✅ OK (2 rules)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_rules: $e")
    end

    # ── v7.31: Test data for automata 13-23 ──

    # 3g. Over-cap lobe for LOBE_POPULATION_GUARD (automaton 13)
    print("  Setting up over-cap lobe... ")
    try
        GB.Lobe.create_lobe!("TinyLobe", "tiny overflow test"; node_cap=2)
        # Add 5 nodes to a lobe with cap=2
        for i in 1:5
            nid = "tiny_node_$i"
            node_data = Dict{String,Any}("system_prompt" => "tiny $i", "lobe_id" => "TinyLobe")
            GB.create_node("tiny_$i pattern", "respond[ok]", node_data, String[])
        end
        # Add the nodes to the lobe manually
        lock(GB.Lobe.LOBE_LOCK) do
            for i in 1:5
                nid = "tiny_node_$i"
                if haskey(GB.NODE_MAP, nid)
                    push!(GB.Lobe.LOBE_REGISTRY["TinyLobe"].node_ids, nid)
                end
            end
        end
        println("✅ OK (TinyLobe cap=2, 5 nodes)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_overcap_lobe: $e")
    end

    # 3h. Expired cooldown entries for CHATTER_COOLDOWN_PURGE (automaton 14)
    print("  Setting up expired cooldowns... ")
    try
        lock(GB.CHATTER_NODE_COOLDOWN_LOCK) do
            for i in 1:10
                GB.CHATTER_NODE_COOLDOWN["cooldown_node_$i"] = time() - 7200.0  # 2hr ago (expired)
            end
            for i in 11:15
                GB.CHATTER_NODE_COOLDOWN["cooldown_node_$i"] = time() - 100.0  # recent (valid)
            end
        end
        lock(GB.ChatterMode.MORPH_COOLDOWN_LOCK) do
            for i in 1:5
                GB.ChatterMode.MORPH_COOLDOWN_MAP["morph_node_$i"] = time() - 100000.0  # expired
            end
        end
        println("✅ OK (10 expired chatter + 5 valid, 5 expired morph)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_cooldowns: $e")
    end

    # 3i. Attachment entries for grave nodes (automaton 15)
    print("  Setting up grave attachments... ")
    try
        # Find a node and grave it, then set up attachment pointing to it
        grave_id = nothing
        lock(GB.NODE_LOCK) do
            for (nid, node) in GB.NODE_MAP
                if !node.is_image_node
                    node.is_grave = true
                    node.grave_reason = "TEST_GRAVE"
                    grave_id = nid
                    break
                end
            end
        end
        if !isnothing(grave_id)
            lock(GB.ATTACHMENT_LOCK) do
                GB.ATTACHMENT_MAP[grave_id] = GB.AttachedNode[]  # grave target
                # Also add attachment FROM alive node TO grave node
                alive_id = nothing
                for (nid, node) in GB.NODE_MAP
                    if !node.is_grave && !node.is_image_node
                        alive_id = nid
                        break
                    end
                end
                if !isnothing(alive_id)
                    # Create an AttachedNode referencing the grave node
                    att = GB.AttachedNode(grave_id, "test_pattern", Float64[], 0.5)
                    GB.ATTACHMENT_MAP[alive_id] = [att]
                end
            end
            println("✅ OK (grave target + grave attached node)")
        else
            println("⚠️  No node available to grave")
        end
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_grave_attachments: $e")
    end

    # 3j. Old immune ledger entries (automaton 17)
    print("  Setting up old immune ledger entries... ")
    try
        lock(GB.ImmuneSystem.LEDGER_LOCK) do
            for i in 1:20
                entry = GB.ImmuneSystem.LedgerEntry(time() - 100000.0 + i, :test, UInt64(1000 + i), "old entry $i")
                push!(GB.ImmuneSystem.IMMUNE_LEDGER, entry)
            end
            # Add a few recent entries
            for i in 1:5
                entry = GB.ImmuneSystem.LedgerEntry(time() - 100.0 + i, :test, UInt64(2000 + i), "recent entry $i")
                push!(GB.ImmuneSystem.IMMUNE_LEDGER, entry)
            end
        end
        println("✅ OK (20 old + 5 recent entries)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_immune_ledger: $e")
    end

    # 3k. Zero-swap chatter sessions (automaton 18)
    print("  Setting up stale chatter sessions... ")
    try
        lock(GB.ChatterMode.CHATTER_LOG_LOCK) do
            for i in 1:5
                session = GB.ChatterMode.ChatterSession(
                    "stale_session_$i",   # session_id
                    time() - 1000.0,       # start_time
                    time() - 900.0,        # end_time
                    10,                    # window_size
                    0,                     # cursor_start
                    10,                    # cursor_end
                    GB.ChatterMode.ChatterNodeClone[],  # clones
                    false,                 # is_running
                    String[],              # queued_inputs
                    0,                     # swaps_attempted  ← ZERO = stale
                    0,                     # swaps_accepted
                    0,                     # swaps_blocked_cooldown
                    0,                     # swaps_blocked_strength
                    0,                     # swaps_blocked_semantic
                    0,                     # swaps_blocked_coinflip
                )
                push!(GB.ChatterMode.CHATTER_LOG, session)
            end
        end
        println("✅ OK (5 stale sessions)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_stale_chatter: $e")
    end

    # 3l. No-growth mitosis log entries (automaton 20)
    print("  Setting up no-growth mitosis entries... ")
    try
        lock(GB.MitosisMode.MITOSIS_LOG_LOCK) do
            for i in 1:5
                entry = GB.MitosisMode.MitosisStats(
                    "no_warrant",    # source
                    "",              # new_node_id ← EMPTY = no growth
                    "test_pattern",  # new_pattern
                    "AlphaLobe",     # target_lobe
                    0.0,             # warrant_score
                    10.0,            # cycle_time_ms
                    "no growth",     # notes
                    "",              # latched_to
                )
                push!(GB.MitosisMode.MITOSIS_LOG, entry)
            end
        end
        println("✅ OK (5 no-growth entries)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_nogrowth_mitosis: $e")
    end

    # 3m. Disabled MLP rules (automaton 22)
    print("  Setting up disabled MLP rules... ")
    try
        mlp_st = GB.EphemeralMLP._state()
        lock(mlp_st.lock) do
            lock(mlp_st.rules.lock) do
                # Add a disabled rule
                disabled_rule = GB.EphemeralMLP.MLPTransformerRule(
                    "test_disabled_rule",
                    "disabled_pattern";
                    key="disabled_key",
                    weight_value=0.5,
                    transform_type=:fuzzy,
                )
                disabled_rule.enabled = false
                mlp_st.rules.rules["test_disabled_rule"] = disabled_rule
                if !haskey(mlp_st.rules.key_index, "disabled_key")
                    mlp_st.rules.key_index["disabled_key"] = String[]
                end
                push!(mlp_st.rules.key_index["disabled_key"], "test_disabled_rule")

                # Add a zero-weight rule
                zero_rule = GB.EphemeralMLP.MLPTransformerRule(
                    "test_zero_weight_rule",
                    "zero_pattern";
                    key="zero_key",
                    weight_value=0.0,
                    transform_type=:fuzzy,
                )
                mlp_st.rules.rules["test_zero_weight_rule"] = zero_rule
                if !haskey(mlp_st.rules.key_index, "zero_key")
                    mlp_st.rules.key_index["zero_key"] = String[]
                end
                push!(mlp_st.rules.key_index["zero_key"], "test_zero_weight_rule")
            end
        end
        println("✅ OK (1 disabled + 1 zero-weight rule)")
    catch e
        println("❌ FAIL: $e")
        push!(ERRORS, "setup_disabled_mlp_rules: $e")
    end

    println()

    # ── PHASE 4: Test individual phagy automata directly ─────────────────────
    println("─" ^ 70)
    println("PHASE 4: TEST INDIVIDUAL PHAGY AUTOMATA")
    println("─" ^ 70)

    # Automaton 1: ORPHAN_PRUNER
    print("  [1] ORPHAN_PRUNER... ")
    try
        stats = GB.PhagyMode.prune_orphan_nodes!(GB.NODE_MAP, GB.NODE_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["orphan_pruner"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "orphan_pruner: $e")
        TEST_RESULTS["orphan_pruner"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 2: STRENGTH_DECAYER
    print("  [2] STRENGTH_DECAYER... ")
    try
        stats = GB.PhagyMode.decay_forgotten_strengths!(GB.NODE_MAP, GB.NODE_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["strength_decayer"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "strength_decayer: $e")
        TEST_RESULTS["strength_decayer"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 3: GRAVE_RECYCLER
    print("  [3] GRAVE_RECYCLER... ")
    try
        stats = GB.PhagyMode.recycle_grave_assets!(GB.NODE_MAP, GB.NODE_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["grave_recycler"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "grave_recycler: $e")
        TEST_RESULTS["grave_recycler"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 4: DROP_TABLE_COMPACT
    print("  [4] DROP_TABLE_COMPACT... ")
    try
        stats = GB.PhagyMode.compact_drop_tables!(GB.NODE_MAP, GB.NODE_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["drop_table_compact"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "drop_table_compact: $e")
        TEST_RESULTS["drop_table_compact"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 5: RULE_PRUNER
    print("  [5] RULE_PRUNER... ")
    try
        stats = GB.PhagyMode.prune_dormant_rules!(GB.PHAGY_RULES_REF[], GB.PHAGY_RULES_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["rule_pruner"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "rule_pruner: $e")
        TEST_RESULTS["rule_pruner"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 6: MEMORY_FORENSICS
    print("  [6] MEMORY_FORENSICS... ")
    try
        stats = GB.PhagyMode.run_memory_forensics!(GB.NODE_MAP, GB.NODE_LOCK, GB.MESSAGE_HISTORY, GB.MESSAGE_HISTORY_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["memory_forensics"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "memory_forensics: $e")
        TEST_RESULTS["memory_forensics"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 8: INJECTOR_GRAVEYARD_SWEEP
    print("  [8] INJECTOR_GRAVEYARD_SWEEP... ")
    try
        stats = GB.PhagyMode.sweep_injector_graveyard!(GB.EphemeralAutomaton._ACTIVE_INJECTORS, GB.EphemeralAutomaton._INJECTOR_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["injector_graveyard_sweep"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "injector_graveyard_sweep: $e")
        TEST_RESULTS["injector_graveyard_sweep"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 9: PHASE_ACCUMULATOR_AGING
    print("  [9] PHASE_ACCUMULATOR_AGING... ")
    try
        acc = GB.EphemeralAutomaton._phase_accumulator()
        stats = GB.PhagyMode.age_phase_accumulator!(acc)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["phase_accumulator_aging"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "phase_accumulator_aging: $e")
        TEST_RESULTS["phase_accumulator_aging"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 10: OBSERVER_STORE_PRUNE
    print("  [10] OBSERVER_STORE_PRUNE... ")
    try
        stats = GB.PhagyMode.prune_observer_store!(GB._MLP_OBSERVER_STORE)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["observer_store_prune"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "observer_store_prune: $e")
        TEST_RESULTS["observer_store_prune"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 11: SIGIL_CONSISTENCY_CHECK
    print("  [11] SIGIL_CONSISTENCY_CHECK... ")
    try
        stats = GB.PhagyMode.check_sigil_consistency!(GB._ENGINE_SIGIL_TABLE)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["sigil_consistency_check"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "sigil_consistency_check: $e")
        TEST_RESULTS["sigil_consistency_check"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 12: STALE_TRAJECTORY_TRIM
    print("  [12] STALE_TRAJECTORY_TRIM... ")
    try
        stats = GB.PhagyMode.trim_stale_trajectory!(
            GB.ActionTonePredictor._trajectory_config,
            GB.ActionTonePredictor._trajectory_buffer,
            GB.ActionTonePredictor._trajectory_lock
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["stale_trajectory_trim"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "stale_trajectory_trim: $e")
        TEST_RESULTS["stale_trajectory_trim"] = Dict("status" => "fail", "error" => string(e))
    end

    # ── v7.31: Automata 13-23 ──

    # Automaton 13: LOBE_POPULATION_GUARD
    print("  [13] LOBE_POPULATION_GUARD... ")
    try
        stats = GB.PhagyMode.lobe_population_guard!(
            GB.NODE_MAP, GB.NODE_LOCK,
            GB.Lobe.LOBE_REGISTRY, GB.Lobe.LOBE_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["lobe_population_guard"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "lobe_population_guard: $e")
        TEST_RESULTS["lobe_population_guard"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 14: CHATTER_COOLDOWN_PURGE
    print("  [14] CHATTER_COOLDOWN_PURGE... ")
    try
        stats = GB.PhagyMode.chatter_cooldown_purge!(
            GB.CHATTER_NODE_COOLDOWN, GB.CHATTER_NODE_COOLDOWN_LOCK,
            GB.ChatterMode.MORPH_COOLDOWN_MAP, GB.ChatterMode.MORPH_COOLDOWN_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["chatter_cooldown_purge"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "chatter_cooldown_purge: $e")
        TEST_RESULTS["chatter_cooldown_purge"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 15: ATTACHMENT_GRAVE_SWEEP
    print("  [15] ATTACHMENT_GRAVE_SWEEP... ")
    try
        stats = GB.PhagyMode.attachment_grave_sweep!(
            GB.NODE_MAP, GB.NODE_LOCK,
            GB.ATTACHMENT_MAP, GB.ATTACHMENT_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["attachment_grave_sweep"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "attachment_grave_sweep: $e")
        TEST_RESULTS["attachment_grave_sweep"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 16: GROUP_GRAVE_SWEEP
    print("  [16] GROUP_GRAVE_SWEEP... ")
    try
        stats = GB.PhagyMode.group_grave_sweep!(
            GB.NODE_MAP, GB.NODE_LOCK,
            GB.GROUP_MAP, GB.GROUP_LOCK, GB.NODE_TO_GROUP
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["group_grave_sweep"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "group_grave_sweep: $e")
        TEST_RESULTS["group_grave_sweep"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 17: IMMUNE_STATE_TRIM
    print("  [17] IMMUNE_STATE_TRIM... ")
    try
        stats = GB.PhagyMode.immune_state_trim!(
            GB.ImmuneSystem.IMMUNE_LEDGER, GB.ImmuneSystem.LEDGER_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["immune_state_trim"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "immune_state_trim: $e")
        TEST_RESULTS["immune_state_trim"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 18: CHATTER_LOG_ROTATE
    print("  [18] CHATTER_LOG_ROTATE... ")
    try
        stats = GB.PhagyMode.chatter_log_rotate!(
            GB.ChatterMode.CHATTER_LOG, GB.ChatterMode.CHATTER_LOG_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["chatter_log_rotate"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "chatter_log_rotate: $e")
        TEST_RESULTS["chatter_log_rotate"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 19: PHAGY_LOG_ROTATE
    print("  [19] PHAGY_LOG_ROTATE... ")
    try
        stats = GB.PhagyMode.phagy_log_rotate!(
            GB.PhagyMode.PHAGY_LOG, GB.PhagyMode.PHAGY_LOG_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["phagy_log_rotate"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "phagy_log_rotate: $e")
        TEST_RESULTS["phagy_log_rotate"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 20: MITOSIS_LOG_ROTATE
    print("  [20] MITOSIS_LOG_ROTATE... ")
    try
        stats = GB.PhagyMode.mitosis_log_rotate!(
            GB.MitosisMode.MITOSIS_LOG, GB.MitosisMode.MITOSIS_LOG_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["mitosis_log_rotate"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "mitosis_log_rotate: $e")
        TEST_RESULTS["mitosis_log_rotate"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 21: LOBE_CONNECTION_AUDIT
    print("  [21] LOBE_CONNECTION_AUDIT... ")
    try
        stats = GB.PhagyMode.lobe_connection_audit!(
            GB.Lobe.LOBE_REGISTRY, GB.Lobe.LOBE_LOCK
        )
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["lobe_connection_audit"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "lobe_connection_audit: $e")
        TEST_RESULTS["lobe_connection_audit"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 22: MLP_RULE_GRAVE_SWEEP
    print("  [22] MLP_RULE_GRAVE_SWEEP... ")
    try
        mlp_st = GB.EphemeralMLP._state()
        stats = GB.PhagyMode.mlp_rule_grave_sweep!(mlp_st)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["mlp_rule_grave_sweep"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "mlp_rule_grave_sweep: $e")
        TEST_RESULTS["mlp_rule_grave_sweep"] = Dict("status" => "fail", "error" => string(e))
    end

    # Automaton 23: RELATIONAL_TRIPLE_AUDIT
    print("  [23] RELATIONAL_TRIPLE_AUDIT... ")
    try
        stats = GB.PhagyMode.relational_triple_audit!(GB.NODE_MAP, GB.NODE_LOCK)
        println("✅ Processed=$(stats.items_processed), Changed=$(stats.items_changed)")
        TEST_RESULTS["relational_triple_audit"] = Dict("status" => "pass", "processed" => stats.items_processed, "changed" => stats.items_changed)
    catch e
        println("❌ $e")
        push!(ERRORS, "relational_triple_audit: $e")
        TEST_RESULTS["relational_triple_audit"] = Dict("status" => "fail", "error" => string(e))
    end

    println()

    # ── PHASE 5: Test run_phagy! dispatcher (3 random cycles) ────────────────
    # ⚠️  HOPFIELD_CACHE / HOPFIELD_CACHE_LOCK positional args are DEAD.
    #     Passed only because run_phagy!() still expects them in its signature.
    #     They do absolutely nothing. Ignore them.
    println("─" ^ 70)
    println("PHASE 5: TEST run_phagy! DISPATCHER (3 cycles)")
    println("─" ^ 70)

    for cycle in 1:3
        print("    Cycle $cycle: ")
        try
            # ⚠️⚠️⚠️  HOPFIELD_CACHE / HOPFIELD_CACHE_LOCK BELOW ARE DEAD VESTIGIAL
            #     ARGS. They were commented out ages ago. Automaton 7
            #     (CACHE_VALIDATOR) is permanently disabled. They do NOTHING.
            #     Do NOT waste time on them. Ever.
            stats = GB.PhagyMode.run_phagy!(
                GB.NODE_MAP,
                GB.NODE_LOCK,
                GB.HOPFIELD_CACHE,       # ⚠️ DEAD — see notice above
                GB.HOPFIELD_CACHE_LOCK,  # ⚠️ DEAD — see notice above
                GB.PHAGY_RULES_REF[],
                GB.PHAGY_RULES_LOCK;
                message_history       = GB.MESSAGE_HISTORY,
                history_lock          = GB.MESSAGE_HISTORY_LOCK,
                injector_dict         = GB.EphemeralAutomaton._ACTIVE_INJECTORS,
                injector_lock         = GB.EphemeralAutomaton._INJECTOR_LOCK,
                phase_acc             = GB.EphemeralAutomaton._phase_accumulator(),
                observer_store        = GB._MLP_OBSERVER_STORE,
                sigil_table           = GB._ENGINE_SIGIL_TABLE,
                trajectory_config_ref = GB.ActionTonePredictor._trajectory_config,
                trajectory_buffer     = GB.ActionTonePredictor._trajectory_buffer,
                trajectory_lock       = GB.ActionTonePredictor._trajectory_lock,
                # GRUG v7.31: Full organ coverage kwargs
                lobe_registry              = GB.Lobe.LOBE_REGISTRY,
                lobe_lock                  = GB.Lobe.LOBE_LOCK,
                chatter_node_cooldown      = GB.CHATTER_NODE_COOLDOWN,
                chatter_node_cooldown_lock = GB.CHATTER_NODE_COOLDOWN_LOCK,
                morph_cooldown_map         = GB.ChatterMode.MORPH_COOLDOWN_MAP,
                morph_cooldown_lock        = GB.ChatterMode.MORPH_COOLDOWN_LOCK,
                attachment_map             = GB.ATTACHMENT_MAP,
                attachment_lock            = GB.ATTACHMENT_LOCK,
                group_map                  = GB.GROUP_MAP,
                group_lock                 = GB.GROUP_LOCK,
                node_to_group              = GB.NODE_TO_GROUP,
                immune_ledger              = GB.ImmuneSystem.IMMUNE_LEDGER,
                ledger_lock                = GB.ImmuneSystem.LEDGER_LOCK,
                chatter_log                = GB.ChatterMode.CHATTER_LOG,
                chatter_log_lock           = GB.ChatterMode.CHATTER_LOG_LOCK,
                mitosis_log                = GB.MitosisMode.MITOSIS_LOG,
                mitosis_log_lock           = GB.MitosisMode.MITOSIS_LOG_LOCK,
                mlp_state                  = GB.EphemeralMLP._state(),
            )
            println("✅ Automaton=$(stats.automaton), Processed=$(stats.items_processed), Changed=$(stats.items_changed), Time=$(round(stats.cycle_time_ms, digits=2))ms")
            TEST_RESULTS["phagy_dispatcher_$cycle"] = Dict("status" => "pass", "automaton" => stats.automaton, "processed" => stats.items_processed, "changed" => stats.items_changed)
        catch e
            println("❌ FAIL: $e")
            push!(ERRORS, "phagy_dispatcher_$cycle: $e")
            TEST_RESULTS["phagy_dispatcher_$cycle"] = Dict("status" => "fail", "error" => string(e))
        end
    end
    println()

    # ── PHASE 6: Test maybe_run_idle() end-to-end ────────────────────────────
    println("─" ^ 70)
    println("PHASE 6: TEST maybe_run_idle() END-TO-END")
    println("─" ^ 70)

    for attempt in 1:5
        GB.LAST_INPUT_TIME[] = time() - 200
        print("  Idle attempt $attempt: ")
        try
            GB.maybe_run_idle()
            println("✅ Completed")
        catch e
            println("❌ FAIL: $e")
            push!(ERRORS, "maybe_run_idle_$attempt: $e")
        end
    end
    println()

    # ── PHASE 7: Restore gates ────────────────────────────────────────────────
    println("─" ^ 70)
    println("PHASE 7: RESTORE GATES")
    println("─" ^ 70)

    GB.ChatterMode._override_test_gates!(;
        min_population=prev_gates.min_population,
        window_min=prev_gates.window_min,
        window_max=prev_gates.window_max,
        weak_floor=prev_gates.weak_floor,
        strong_floor=prev_gates.strong_floor,
    )
    println("  Restored population gates to production values")

    # ── SUMMARY ────────────────────────────────────────────────────────────────
    println()
    println("=" ^ 70)
    println("TEST SUMMARY")
    println("=" ^ 70)

    pass_count = count(v -> isa(v, Dict) && get(v, "status", "") == "pass", values(TEST_RESULTS))
    fail_count = count(v -> isa(v, Dict) && get(v, "status", "") == "fail", values(TEST_RESULTS))

    println("  Passed: $pass_count")
    println("  Failed: $fail_count")

    if !isempty(ERRORS)
        println()
        println("  ERRORS:")
        for e in ERRORS
            println("    - $e")
        end
    end

    # Save results
    open("test_results_v6.json", "w") do f
        JSON.print(f, TEST_RESULTS, 4)
    end
    println()
    println("  Results saved to test_results_v6.json")

    if fail_count > 0
        println()
        println("  ⚠️  SOME TESTS FAILED — see errors above")
        exit(1)
    else
        println()
        println("  ✅ ALL TESTS PASSED")
    end
end

main()
