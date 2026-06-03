#!/usr/bin/env julia
# =============================================================================
# Conversation Runner with Full Telemetry — v7.57
# =============================================================================
# Loads the comprehensive specimen, runs multi-turn conversation through the
# engine, and logs ALL telemetry to an MD file:
#   - Input text
#   - Matched nodes (scan results)
#   - Vote tallies (confidence, action, node_id)
#   - Relational triples
#   - Group memberships
#   - Strength changes (before → after)
#   - Growth/autogrowth events
#   - Time-node isolation checks
#   - Anti-match detections
# =============================================================================

using Pkg
Pkg.activate(@__DIR__)
include("src/Main.jl")

using JSON
using Dates

# ──────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ──────────────────────────────────────────────────────────────────────────────
const TELEMETRY_FILE = "telemetry_log_v757.md"
const SPECIMEN_FILE  = "comprehensive_specimen_v757.json"

# ──────────────────────────────────────────────────────────────────────────────
# HELPER: Capture stdout from a function call
# ──────────────────────────────────────────────────────────────────────────────
function capture_stdout(f::Function)
    buf = IOBuffer()
    old_stdout = stdout
    rd, wr = redirect_stdout()
    try
        f()
    finally
        redirect_stdout(old_stdout)
    end
    close(wr)
    output = String(read(rd))
    close(rd)
    return output
end

# ──────────────────────────────────────────────────────────────────────────────
# HELPER: Snapshot engine state (node strengths, group sizes, etc.)
# ──────────────────────────────────────────────────────────────────────────────
function snapshot_engine_state()
    state = Dict{String, Any}()
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            state[id] = Dict{String, Any}(
                "pattern"      => node.pattern,
                "strength"     => node.strength,
                "is_grave"     => node.is_grave,
                "fired_this_cycle" => node.fired_this_cycle,
                "voted_this_cycle" => node.voted_this_cycle,
                "is_image_node" => node.is_image_node,
                "json_data"    => node.json_data,
            )
        end
    end
    return state
end

function snapshot_groups()
    groups = Dict{String, Any}()
    lock(GROUP_LOCK) do
        for (gid, grp) in GROUP_MAP
            groups[gid] = Dict{String, Any}(
                "members"            => copy(grp.members),
                "is_time_node_group" => grp.is_time_node_group,
                "chatter_count"      => grp.chatter_count,
                "has_grave_slot"     => grp.has_grave_slot,
                "centroid_pattern"   => grp.centroid_pattern,
            )
        end
    end
    return groups
end

function count_nodes_by_lobe()
    counts = Dict{String, Int}()
    for (lobe_id, lobe_data) in Lobe.LOBE_REGISTRY
        counts[lobe_id] = length(lobe_data.node_ids)
    end
    return counts
end

# ──────────────────────────────────────────────────────────────────────────────
# HELPER: Compute strength deltas between two snapshots
# ──────────────────────────────────────────────────────────────────────────────
function compute_strength_deltas(before_state, after_state)
    deltas = []
    for (id, after) in after_state
        if haskey(before_state, id)
            before_str = before_state[id]["strength"]
            after_str  = after["strength"]
            delta = after_str - before_str
            if abs(delta) > 0.001
                push!(deltas, (id, before_str, after_str, delta, after["pattern"]))
            end
        end
    end
    return deltas
end

# ──────────────────────────────────────────────────────────────────────────────
# HELPER: Extract telemetry section from captured output
# ──────────────────────────────────────────────────────────────────────────────
function extract_telemetry(output::String)
    parts = split(output, "--- DEBUG TELEMETRY"; keepempty=false)
    if length(parts) >= 2
        return String(parts[1]), "--- DEBUG TELEMETRY" * String(parts[2])
    end
    return output, ""
end

function extract_scaffold(output::String)
    # Find the AIML scaffold section
    m = match(r"🤖 AIML Output Scaffold:\n(.*)"s, output)
    if !isnothing(m)
        return String(m.captures[1])
    end
    return output
end

# ──────────────────────────────────────────────────────────────────────────────
# HELPER: Format a vote for logging
# ──────────────────────────────────────────────────────────────────────────────
function format_vote(v)
    ut = isempty(v.user_triples) ? "none" : join([string(r.subject, "→", r.relation, "→", r.object) for r in v.user_triples], ", ")
    nt = isempty(v.node_triples) ? "none" : join([string(r.subject, "→", r.relation, "→", r.object) for r in v.node_triples], ", ")
    return "- node=$(v.node_id) | action=$(v.action) | conf=$(round(v.confidence; digits=3)) | antimatch=$(v.antimatch) | user_triples=[$ut] | node_triples=[$nt]"
end

# ──────────────────────────────────────────────────────────────────────────────
# MAIN: Run conversations and log telemetry
# ──────────────────────────────────────────────────────────────────────────────

println("=" ^ 70)
println("  GRUGBOT CONVERSATION RUNNER — v7.57 TELEMETRY")
println("=" ^ 70)

# ── 1. Load specimen ──
println("\n📦 Loading specimen from $SPECIMEN_FILE ...")
if isfile(SPECIMEN_FILE)
    load_specimen_from_file!(SPECIMEN_FILE)
    println("✅ Specimen loaded")
else
    println("⚠️  No specimen file found. Using fresh engine state (from build script).")
end

# ── 2. Open telemetry log ──
open(TELEMETRY_FILE, "w") do f
    println(f, "# GrugBot420 Telemetry Log — v7.57")
    println(f, "")
    println(f, "Generated: $(Dates.now())")
    println(f, "")
    println(f, "---")
    println(f, "")
    println(f, "## Engine State at Start")
    println(f, "")
    n_nodes  = lock(() -> length(NODE_MAP), NODE_LOCK)
    n_groups = lock(() -> length(GROUP_MAP), GROUP_LOCK)
    n_lobes  = length(Lobe.LOBE_REGISTRY)
    n_sigils = length(_ENGINE_SIGIL_TABLE.entries)
    println(f, "- **Nodes**: $n_nodes")
    println(f, "- **Groups**: $n_groups")
    println(f, "- **Lobes**: $n_lobes")
    println(f, "- **Sigils**: $n_sigils")
    println(f, "")

    lobe_counts = count_nodes_by_lobe()
    println(f, "### Lobe Distribution")
    println(f, "")
    println(f, "| Lobe | Nodes |")
    println(f, "|------|-------|")
    for (lid, cnt) in sort(collect(lobe_counts); by=x->x[1])
        println(f, "| $lid | $cnt |")
    end
    println(f, "")

    # Count time nodes
    time_node_count = 0
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if is_time_node(node)
                time_node_count += 1
            end
        end
    end
    println(f, "- **Time Nodes**: $time_node_count")
    println(f, "")
end

# ── 3. Define conversation turns ──
# Each turn is a tuple: (description, input_text)
const CONVERSATION_TURNS = [
    # ── REASON MODE TESTS ──
    ("Reason: basic fire knowledge", "fire burns wood"),
    ("Reason: gravity", "gravity pulls objects"),
    ("Reason: synonym expansion", "flame combust wood"),  # test thesaurus synonyms
    ("Reason: water knowledge", "stream flows"),  # stream→flow synonym

    # ── EXPLAIN MODE TESTS ──
    ("Explain: fire burning", "why does fire burn"),
    ("Explain: sky color", "why is the sky blue"),
    ("Explain: sadness", "why do we feel sad"),

    # ── DEFINE MODE TESTS ──
    ("Define: gravity", "define gravity"),
    ("Define: atom", "define atom"),
    ("Define: addition", "define addition"),
    ("Define: shelter", "define shelter"),

    # ── ALERT MODE TESTS ──
    ("Alert: fire danger", "fire is dangerous"),
    ("Alert: deep water", "deep water is dangerous"),

    # ── COMFORT MODE TESTS ──
    ("Comfort: sadness", "i feel sad"),
    ("Comfort: fear", "i am scared"),
    ("Comfort: loneliness", "i feel lonely"),

    # ── MATH MODE TESTS ──
    ("Math: basic addition", "2 plus 2"),
    ("Math: multiplication", "3 times 4"),
    ("Math: subtraction", "10 minus 3"),
    ("Math: sigil pattern", "what is 5 plus 3"),  # test &n sigil

    # ── RELATE MODE TESTS ──
    ("Relate: fire burns wood", "fire burns wood"),
    ("Relate: earth orbits sun", "earth orbits sun"),

    # ── TEMPORAL/TIME MODE TESTS ──
    ("Time: past to present", "past before present"),
    ("Time: seasons cycle", "spring to summer"),
    ("Time: day cycle", "dawn to day"),

    # ── CAUSAL SIGIL TESTS ──
    ("Causal: heat evaporation", "heat causes evaporation"),
    ("Causal: rain flooding", "rain causes flooding"),
    ("Causal: cold freezing", "cold causes freezing"),

    # ── SPATIAL SIGIL TESTS ──
    ("Spatial: clouds sky", "clouds in the sky"),
    ("Spatial: fire hearth", "fire at the hearth"),

    # ── POSSESSIVE SIGIL TESTS ──
    ("Possessive: tree branches", "tree has branches"),
    ("Possessive: river water", "river has water"),

    # ── SIMILARITY SIGIL TESTS ──
    ("Similarity: fire star", "fire resembles star"),
    ("Similarity: cave shelter", "cave resembles shelter"),

    # ── ANTI-MATCH TESTS ──
    ("Anti-match: wrong input", "wrong bad incorrect"),
    ("Anti-match: fake input", "fake false nonsense"),

    # ── PROCEDURE CHAIN TESTS ──
    ("Proc: make fire", "how to make fire"),
    ("Proc: find water", "how to find water"),

    # ── CUSTOM SIGIL TESTS ──
    ("Custom &emotional: music", "person feels music"),
    ("Custom &season: spring", "spring season"),

    # ── AUTOGROWTH TESTS (novel inputs) ──
    ("Autogrowth: novel — volcanoes", "volcanoes erupt lava"),  # novel, should trigger growth
    ("Autogrowth: novel — thunderstorms", "thunderstorms bring lightning"),  # novel
    ("Autogrowth: novel — oceans deep", "oceans are deep and vast"),  # novel
    ("Autogrowth: novel — friendship", "friendship brings happiness"),  # novel, cross-lobe potential
    ("Autogrowth: novel — cooking", "cooking food makes it safe"),  # novel, survival-adjacent
    ("Autogrowth: follow-up — volcanoes again", "volcanoes are mountains of fire"),  # should find node from prior growth

    # ── CROSS-LOBE TESTS ──
    ("Cross-lobe: fire + emotion", "fire makes me feel warm and safe"),  # survival + emotions
    ("Cross-lobe: math + science", "gravity is a mathematical force"),  # math + science
    ("Cross-lobe: time + survival", "when do we hunt for food"),  # time + survival

    # ── SYNONYM EXPANSION TESTS ──
    ("Synonym: ignite = burn", "ignite the wood"),
    ("Synonym: forage = gather", "forage for berries"),
    ("Synonym: construct = build", "construct a shelter"),
    ("Synonym: ponder = think", "ponder the meaning"),

    # ── EDGE CASES ──
    ("Edge: very short input", "fire"),
    ("Edge: question format", "what is water?"),
    ("Edge: multiple concepts", "fire burns wood and water flows"),
]

# ── 4. Run each conversation turn ──
println("\n🚀 Running $(length(CONVERSATION_TURNS)) conversation turns...")

for (i, (desc, input_text)) in enumerate(CONVERSATION_TURNS)
    println("\n── Turn $i/$(length(CONVERSATION_TURNS)): $desc ──")
    println("   Input: \"$input_text\"")

    # Snapshot BEFORE
    before_state  = snapshot_engine_state()
    before_groups = snapshot_groups()
    before_node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
    before_group_count = lock(() -> length(GROUP_MAP), GROUP_LOCK)

    # Capture output by redirecting stdout
    output = capture_stdout() do
        try
            process_mission(input_text)
        catch e
            println("⚠️  process_mission error: $e")
        end
    end

    # Snapshot AFTER
    after_state  = snapshot_engine_state()
    after_groups = snapshot_groups()
    after_node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
    after_group_count = lock(() -> length(GROUP_MAP), GROUP_LOCK)

    # Extract conversational reply and telemetry
    reply, telemetry = extract_telemetry(output)
    scaffold = extract_scaffold(output)

    # Compute strength deltas
    deltas = compute_strength_deltas(before_state, after_state)

    # Get voter info
    voter_ids = lock(LAST_VOTER_LOCK) do
        copy(LAST_VOTER_IDS)
    end
    contributor_votes = lock(LAST_VOTER_LOCK) do
        copy(LAST_CONTRIBUTOR_VOTES)
    end

    # New nodes/groups (autogrowth detection)
    new_nodes  = after_node_count - before_node_count
    new_groups = after_group_count - before_group_count

    # ── Write to telemetry log ──
    open(TELEMETRY_FILE, "a") do f
        println(f, "## Turn $i: $desc")
        println(f, "")
        println(f, "- **Input**: `$(input_text)`")
        println(f, "- **Nodes before**: $before_node_count → **after**: $after_node_count $(new_nodes > 0 ? "(+$new_nodes 🌱)" : "")")
        println(f, "- **Groups before**: $before_group_count → **after**: $after_group_count $(new_groups > 0 ? "(+$new_groups 🌱)" : "")")
        println(f, "")

        # Conversational reply (first 500 chars)
        println(f, "### Reply")
        println(f, "")
        clean_reply = replace(replace(scaffold, r"\n{3,}" => "\n\n"), r"^\s+" => "")
        if length(clean_reply) > 800
            # Safe truncation: find last valid character boundary before 800 bytes
            safe_end = prevind(clean_reply, min(ncodeunits(clean_reply)+1, 801))
            println(f, "```")
            println(f, clean_reply[1:safe_end] * "...")
            println(f, "```")
        else
            println(f, "```")
            println(f, clean_reply)
            println(f, "```")
        end
        println(f, "")

        # Voter details
        println(f, "### Vote Details")
        println(f, "")
        println(f, "- **Voter IDs**: $(length(voter_ids)) total")
        if !isempty(contributor_votes)
            println(f, "- **Contributing Votes**:")
            for v in contributor_votes
                println(f, "  $(format_vote(v))")
            end
        end
        println(f, "")

        # Strength deltas
        if !isempty(deltas)
            println(f, "### Strength Changes")
            println(f, "")
            println(f, "| Node | Pattern | Before | After | Delta |")
            println(f, "|------|---------|--------|-------|-------|")
            for (id, bef, aft, delta, pat) in sort(deltas; by=x->abs(x[4]), rev=true)
                pat_short = length(pat) > 40 ? pat[1:37] * "..." : pat
                println(f, "| $id | $pat_short | $(round(bef; digits=2)) | $(round(aft; digits=2)) | $(round(delta; digits=3)) |")
            end
            println(f, "")
        end

        # New groups formed (growth events)
        if new_groups > 0
            println(f, "### 🌱 Growth Events")
            println(f, "")
            for (gid, grp) in after_groups
                if !haskey(before_groups, gid)
                    time_flag = grp["is_time_node_group"] ? " ⏰ TIME-NODE GROUP" : ""
                    println(f, "- **New group $gid**$(time_flag): members=$(grp["members"])")
                end
            end
            println(f, "")
        end

        # New nodes formed (autogrowth)
        if new_nodes > 0
            println(f, "### 🌱 New Nodes (Autogrowth)")
            println(f, "")
            for (id, after) in after_state
                if !haskey(before_state, id)
                    time_flag = ""
                    if haskey(after, "json_data") && haskey(after["json_data"], "time_node") && after["json_data"]["time_node"] == true
                        time_flag = " ⏰ TIME NODE"
                    end
                    println(f, "- **New node $id**$(time_flag): pattern=\"$(after["pattern"])\" strength=$(after["strength"])")
                end
            end
            println(f, "")
        end

        # Debug telemetry (if available)
        if !isempty(telemetry)
            println(f, "<details><summary>🔍 Debug Telemetry</summary>")
            println(f, "")
            println(f, "```")
            # Truncate very long telemetry
            if length(telemetry) > 2000
                safe_end = prevind(telemetry, min(ncodeunits(telemetry)+1, 2001))
                println(f, telemetry[1:safe_end] * "\n... (truncated)")
            else
                println(f, telemetry)
            end
            println(f, "```")
            println(f, "")
            println(f, "</details>")
            println(f, "")
        end

        println(f, "---")
        println(f, "")
    end

    println("   ✅ Logged (nodes: $before_node_count→$after_node_count, groups: $before_group_count→$after_group_count)")
end

# ── 5. Final summary ──
println("\n" * "=" ^ 70)
println("  TELEMETRY COMPLETE")
println("=" ^ 70)

final_nodes  = lock(() -> length(NODE_MAP), NODE_LOCK)
final_groups = lock(() -> length(GROUP_MAP), GROUP_LOCK)

open(TELEMETRY_FILE, "a") do f
    println(f, "## Final Summary")
    println(f, "")
    println(f, "- **Total conversation turns**: $(length(CONVERSATION_TURNS))")
    println(f, "- **Final node count**: $final_nodes")
    println(f, "- **Final group count**: $final_groups")
    println(f, "")
    lobe_counts = count_nodes_by_lobe()
    println(f, "### Final Lobe Distribution")
    println(f, "")
    println(f, "| Lobe | Nodes |")
    println(f, "|------|-------|")
    for (lid, cnt) in sort(collect(lobe_counts); by=x->x[1])
        println(f, "| $lid | $cnt |")
    end
    println(f, "")

    # Count time nodes
    time_node_count = 0
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if is_time_node(node)
                time_node_count += 1
            end
        end
    end
    println(f, "- **Time Nodes**: $time_node_count")
    println(f, "")

    # Show time-node group isolation
    time_groups = 0
    regular_groups = 0
    mixed_groups = 0
    lock(GROUP_LOCK) do
        for (gid, grp) in GROUP_MAP
            if grp.is_time_node_group
                # Verify all members are actually time nodes
                all_time = true
                for mid in grp.members
                    n = lock(() -> get(NODE_MAP, mid, nothing), NODE_LOCK)
                    if !isnothing(n) && !is_time_node(n)
                        all_time = false
                    end
                end
                if all_time
                    time_groups += 1
                else
                    mixed_groups += 1
                end
            else
                regular_groups += 1
            end
        end
    end
    println(f, "### Time-Node Group Isolation Check")
    println(f, "")
    println(f, "- **Regular groups**: $regular_groups")
    println(f, "- **Time-node groups**: $time_groups")
    println(f, "- **Mixed groups (VIOLATION)**: $mixed_groups")
    if mixed_groups == 0
        println(f, "- ✅ **All time-node groups are properly isolated**")
    else
        println(f, "- ❌ **TIME-NODE ISOLATION VIOLATED** — mixed groups found!")
    end
    println(f, "")

    # Top 10 strongest nodes
    println(f, "### Top 10 Strongest Nodes")
    println(f, "")
    println(f, "| Node | Pattern | Strength |")
    println(f, "|------|---------|----------|")
    all_nodes = lock(NODE_LOCK) do
        [(id, n.pattern, n.strength) for (id, n) in NODE_MAP]
    end
    sorted = sort(all_nodes; by=x->x[3], rev=true)
    for (id, pat, str) in sorted[1:min(10, length(sorted))]
        pat_short = length(pat) > 40 ? pat[1:37] * "..." : pat
        println(f, "| $id | $pat_short | $(round(str; digits=2)) |")
    end
    println(f, "")
end

println("\n📝 Telemetry written to $TELEMETRY_FILE")
println("📊 Final state: $final_nodes nodes, $final_groups groups")
