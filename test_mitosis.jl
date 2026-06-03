# Test MitosisMode integration with existing boot seeds
include("src/GrugBot420.jl")
using .GrugBot420

println("\n=== MITOSIS INTEGRATION TEST ===\n")

# Check current state (boot seeds created automatically)
alive_count = lock(GrugBot420.NODE_LOCK) do
    count(n -> !n.is_grave, values(GrugBot420.NODE_MAP))
end
println("[TEST] Alive nodes (boot seeds): $alive_count")
println("[TEST] Min population gate: $(GrugBot420.MitosisMode.MIN_POPULATION_GATE)")

# Add some messages to MESSAGE_HISTORY so warrant sources have data
println("\n[TEST] Adding messages to history for warrant analysis...")
lock(GrugBot420.MESSAGE_HISTORY_LOCK) do
    for i in 1:5
        push!(GrugBot420.MESSAGE_HISTORY, GrugBot420.Main.ChatMessage(i, "User", "what is the meaning of consciousness and existence", false, 0.8))
    end
    for i in 6:10
        push!(GrugBot420.MESSAGE_HISTORY, GrugBot420.Main.ChatMessage(i, "User", "grug afraid of the dark storm outside", false, 0.9))
    end
    for i in 11:15
        push!(GrugBot420.MESSAGE_HISTORY, GrugBot420.Main.ChatMessage(i, "User", "hello friend how are you today", false, 0.5))
    end
end
println("[TEST] Added 15 messages to history")
println("[TEST] Message history size: $(length(GrugBot420.MESSAGE_HISTORY))")

# Show existing node patterns
println("\n[TEST] Current node patterns:")
lock(GrugBot420.NODE_LOCK) do
    for (id, node) in GrugBot420.NODE_MAP
        if !node.is_grave
            lobe_hint = get(node.json_data, "lobe_hint", "default")
            println("  $id: pattern='$(node.pattern)' lobe=$lobe_hint")
        end
    end
end

# Run mitosis directly
println("\n[TEST] Running mitosis cycle directly...")
stats = GrugBot420.MitosisMode.run_mitosis!(
    node_map              = GrugBot420.NODE_MAP,
    node_lock             = GrugBot420.NODE_LOCK,
    message_history       = GrugBot420.MESSAGE_HISTORY,
    history_lock          = GrugBot420.MESSAGE_HISTORY_LOCK,
    thesaurus_gate_filter = (word) -> GrugBot420.Thesaurus.thesaurus_gate_filter(word),
    thesaurus_word_similarity = (w1, w2) -> GrugBot420.Thesaurus.word_similarity(w1, w2),
    create_node_fn        = GrugBot420.create_node,
    lobe_registry         = GrugBot420.LOBE_REGISTRY,
    attachment_map        = GrugBot420.ATTACHMENT_MAP,
    immune_gate_fn        = nothing,  # Skip immune for test
)

println("[TEST] Mitosis result:")
println("  Source: $(stats.source)")
println("  New node ID: $(stats.new_node_id)")
println("  New pattern: $(stats.new_pattern)")
println("  Target lobe: $(stats.target_lobe)")
println("  Warrant score: $(stats.warrant_score)")
println("  Notes: $(stats.notes)")

# If it grew, show the new node
if !isempty(stats.new_node_id)
    new_node = lock(GrugBot420.NODE_LOCK) do
        get(GrugBot420.NODE_MAP, stats.new_node_id, nothing)
    end
    if new_node !== nothing
        println("\n[TEST] New node details:")
        println("  Pattern: $(new_node.pattern)")
        println("  Action packet: $(new_node.action_packet)")
        println("  System prompt: $(get(new_node.json_data, "system_prompt", "none"))")
        println("  Lobe hint: $(get(new_node.json_data, "lobe_hint", "none"))")
        println("  Mitosis source: $(get(new_node.json_data, "mitosis_source", "none"))")
        println("  Strength: $(new_node.strength)")
    end
end

# Run a second cycle (should be on cooldown)
println("\n[TEST] Running second mitosis cycle (should be cooldown)...")
stats2 = GrugBot420.MitosisMode.run_mitosis!(
    node_map              = GrugBot420.NODE_MAP,
    node_lock             = GrugBot420.NODE_LOCK,
    message_history       = GrugBot420.MESSAGE_HISTORY,
    history_lock          = GrugBot420.MESSAGE_HISTORY_LOCK,
    thesaurus_gate_filter = (word) -> GrugBot420.Thesaurus.thesaurus_gate_filter(word),
    thesaurus_word_similarity = (w1, w2) -> GrugBot420.Thesaurus.word_similarity(w1, w2),
    create_node_fn        = GrugBot420.create_node,
    lobe_registry         = GrugBot420.LOBE_REGISTRY,
    attachment_map        = GrugBot420.ATTACHMENT_MAP,
    immune_gate_fn        = nothing,
)
println("[TEST] Second cycle result: source=$(stats2.source), notes=$(stats2.notes)")

# Check mitosis status
println("\n[TEST] Mitosis status summary:")
println(GrugBot420.MitosisMode.get_mitosis_status_summary())

# Final node count
alive_after = lock(GrugBot420.NODE_LOCK) do
    count(n -> !n.is_grave, values(GrugBot420.NODE_MAP))
end
println("\n[TEST] Nodes before: $alive_count, after: $alive_after")
println("\n=== MITOSIS TEST COMPLETE ===")
