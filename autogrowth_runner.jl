#!/usr/bin/env julia
# =============================================================================
# Autogrowth Conversation Runner — v7.57
# =============================================================================
# Simulates the full ASK→ANSWER autogrowth cycle by:
#   1. Sending novel input through process_mission → engine asks a question
#   2. Using the internal _create_answer_node/_base_answer_data API to teach
#   3. Verifying follow-up inputs now match
# Logs all telemetry to autogrowth_telemetry_v757.md
# =============================================================================

using Pkg
Pkg.activate(@__DIR__)
include("src/Main.jl")

using JSON
using Dates

const TELEMETRY_FILE = "autogrowth_telemetry_v757.md"
const SPECIMEN_FILE  = "comprehensive_specimen_v757.json"

# ── Capture stdout ──
function capture_process_mission(input_text::String)
    old_stdout = stdout
    rd, wr = redirect_stdout()
    try
        process_mission(input_text)
    catch e
        println("⚠️  Error in process_mission: $e")
    end
    flush(wr)
    redirect_stdout(old_stdout)
    close(wr)
    result = read(rd, String)
    close(rd)
    return result
end

# ── Teach the system using the internal /answer API ──
function teach_answer(pattern_text::String, mode::String, target_lobe::Union{String,Nothing}=nothing)
    # Build answer data
    pending_ask = lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do
        old = _HIPPOCAMPAL_PENDING_ASK[]
        _HIPPOCAMPAL_PENDING_ASK[] = ""
        old
    end

    ans_data = _base_answer_data(mode; pending_ask_text=pending_ask)

    # Mode-specific extensions — mirror the REPL /answer handler's logic
    cfg = get(_ANSWER_MODE_CONFIG, mode, _ANSWER_MODE_CONFIG["reason"])
    action_family = get(cfg, "action_family", "reason")
    action_pkt = "$(action_family)^1"

    # Handle special modes
    if mode == "time"
        # Parse "subject | object" — auto &temporal (like /answer :time)
        parts = split(pattern_text, "|")
        if length(parts) >= 2
            subj = strip(parts[1])
            obj  = strip(parts[2])
            ans_data["answer_mode"] = "time"
            ans_data["time_node"] = true
            ans_data["noun_anchors"] = [lowercase(subj), lowercase(obj)]
            ans_data["required_relations"] = ["&temporal"]
            ans_data["seeded_triple"] = Dict(
                "subject"  => lowercase(subj),
                "relation" => "&temporal",
                "object"   => lowercase(obj),
            )
            ans_data["system_prompt"] = "Grug. I learned this from a question about time. I know that $(lowercase(subj)) &temporal $(lowercase(obj)). I reason about temporal relationships."
            ans_data["voice_register"] = "plain"
            ans_data["frame_hints"] = ["plain", "exploratory"]
            pattern_text = lowercase(subj)
        end
    elseif mode == "relate"
        # Parse "subject | relation | object" — like /answer :relate
        parts = split(pattern_text, "|")
        if length(parts) >= 3
            subj = strip(parts[1])
            rel  = strip(parts[2])
            obj  = strip(parts[3])
            # Expand sigils if present
            rel_for_triple = startswith(rel, "&") ? rel : lowercase(rel)
            ans_data["answer_mode"] = "relate"
            ans_data["noun_anchors"] = [lowercase(subj), lowercase(obj)]
            ans_data["required_relations"] = [rel_for_triple]
            ans_data["seeded_triple"] = Dict(
                "subject"  => lowercase(subj),
                "relation" => rel_for_triple,
                "object"   => lowercase(obj),
            )
            ans_data["system_prompt"] = "Grug. I learned this from a question. I know that $(lowercase(subj)) $(rel_for_triple) $(lowercase(obj)). I reason about this relationship."
            ans_data["voice_register"] = "plain"
            ans_data["frame_hints"] = ["plain", "exploratory"]
            pattern_text = lowercase(subj)
        elseif length(parts) == 2
            subj = strip(parts[1])
            obj  = strip(parts[2])
            ans_data["answer_mode"] = "relate"
            ans_data["noun_anchors"] = [lowercase(subj), lowercase(obj)]
            ans_data["required_relations"] = ["relates"]
            ans_data["seeded_triple"] = Dict(
                "subject"  => lowercase(subj),
                "relation" => "relates",
                "object"   => lowercase(obj),
            )
            ans_data["system_prompt"] = "Grug. I learned this from a question. I know that $(lowercase(subj)) relates $(lowercase(obj)). I reason about this relationship."
            ans_data["voice_register"] = "plain"
            ans_data["frame_hints"] = ["plain", "exploratory"]
            pattern_text = lowercase(subj)
        end
    elseif mode == "proc"
        # Parse "step1; step2; step3" — procedural chain
        steps = split(pattern_text, ";")
        steps = [strip(s) for s in steps if !isempty(strip(s))]
        ans_data["procedure_steps"] = steps
        ans_data["voice_register"] = "terse"
        ans_data["frame_hints"] = ["imperative", "sequential"]
        pattern_text = strip(steps[1])
    elseif mode == "math"
        ans_data["noun_anchors"] = ["math"]
        ans_data["voice_register"] = "terse"
        ans_data["system_prompt"] = "Grug. I compute. I give answers. Numbers are my language. I reason about mathematical truths I was taught."
    end

    # Create the node — use _plant_answer_cluster if fan-out is enabled
    # for this mode, otherwise use _create_answer_node directly.
    local nid::String
    local shadow_ids::Vector{String}

    if _FANOUT_ENABLED[] && mode in _FANOUT_MODES
        nid, shadow_ids, lobe_tag = _plant_answer_cluster(pattern_text, action_pkt, ans_data, target_lobe, mode)
    else
        nid, lobe_tag = _create_answer_node(pattern_text, action_pkt, ans_data, target_lobe)
        shadow_ids = String[]
    end

    # Dampen strain
    try
        EphemeralMLP.dampen_strain!(0.7)
    catch e
        @warn "[AUTOGROWTH] dampen_strain! failed (non-fatal): $e"
    end

    return nid
end

# ── Snapshot helpers ──
function node_count()
    lock(() -> length(NODE_MAP), NODE_LOCK)
end
function group_count()
    lock(() -> length(GROUP_MAP), GROUP_LOCK)
end
function get_time_node_count()
    c = Ref(0)
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            if is_time_node(node)
                c[] += 1
            end
        end
    end
    return c[]
end

function safe_truncate(s::String, max_chars::Int)
    if ncodeunits(s) <= max_chars
        return s
    end
    safe_end = prevind(s, min(ncodeunits(s) + 1, max_chars + 1))
    return s[1:safe_end] * "..."
end

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

println("=" ^ 70)
println("  GRUGBOT AUTOGROWTH TEST — v7.57")
println("=" ^ 70)

# ── Load specimen ──
println("\n📦 Loading specimen...")
if isfile(SPECIMEN_FILE)
    load_specimen_from_file!(SPECIMEN_FILE)
    println("✅ Specimen loaded ($(node_count()) nodes)")
else
    println("⚠️  No specimen file, using fresh engine state")
end

initial_nodes = node_count()
initial_groups = group_count()

# ── Open telemetry log ──
open(TELEMETRY_FILE, "w") do f
    println(f, "# GrugBot420 Autogrowth Telemetry — v7.57")
    println(f, "")
    println(f, "Generated: $(Dates.now())")
    println(f, "")
    println(f, "Demonstrates the full ASK→ANSWER autogrowth cycle.")
    println(f, "Novel inputs trigger strain; internal /answer API teaches the system; follow-up confirms learning.")
    println(f, "")
    println(f, "---")
    println(f, "")
    println(f, "## Initial State")
    println(f, "")
    println(f, "- **Nodes**: $initial_nodes")
    println(f, "- **Groups**: $initial_groups")
    println(f, "- **Time Nodes**: $(get_time_node_count())")
    println(f, "")
end

# ── Autogrowth scenarios ──
# (description, novel_input, answer_mode, answer_content, target_lobe)
const AUTOGROWTH_SCENARIOS = [
    ("Reason: volcanoes",       "volcanoes erupt hot lava",                          "reason",  "volcanoes erupt hot lava",                          "science"),
    ("Explain: thunderstorms",  "thunderstorms make loud noises",                    "explain", "thunderstorms make loud noises",                    "science"),
    ("Define: ocean",           "what is an ocean",                                  "define",  "ocean is a vast body of saltwater covering earth",  "science"),
    ("Alert: venomous snakes",  "venomous snakes are dangerous",                     "alert",   "venomous snakes carry deadly poison",               "survival"),
    ("Comfort: grief",          "i feel grief",                                      "comfort", "grief is the weight of love with nowhere to go",   "emotions"),
    ("Math: new equation",      "what is 100 minus 37",                              "math",    "100 minus 37 equals 63",                           "math"),
    ("Relate: cooking",         "cooking transforms raw food",                       "relate",  "cooking | transforms | raw food",                   "survival"),
    ("Time: geological epochs", "paleozoic precedes mesozoic",                       "time",    "paleozoic | mesozoic",                             "time"),
    ("Proc: hunting procedure", "how to hunt deer",                                  "proc",    "track deer; approach quietly; aim carefully; release arrow; retrieve game", "survival"),
    ("Causal: earthquake",      "earthquake causes building collapse",               "relate",  "earthquake | &causal | building collapse",         "science"),
    ("Similarity: river blood", "river resembles blood vessels",                     "relate",  "river | &similarity | blood vessels",               "science"),
    ("Cross-lobe: music",       "music changes how we feel",                         "relate",  "music | &emotional | feelings",                     "emotions"),
]

total_asked = Ref(0)
total_learned = Ref(0)
total_new_nodes = Ref(0)

for (idx, (desc, novel_input, answer_mode, answer_content, target_lobe)) in enumerate(AUTOGROWTH_SCENARIOS)
    println("\n── Autogrowth $idx/$(length(AUTOGROWTH_SCENARIOS)): $desc ──")

    # ── PHASE 1: Novel input → expect ASK question ──
    println("   Phase 1: Novel input → \"$novel_input\"")
    before_nodes = node_count()
    before_groups = group_count()

    output1 = capture_process_mission(novel_input)
    after_p1_nodes = node_count()
    after_p1_groups = group_count()
    asked = occursin("Ask Question", output1) || occursin("don't have a frame", output1) || occursin("strain=", output1)
    if asked
        total_asked[] += 1
    end

    # ── PHASE 2: Teach using internal API ──
    println("   Phase 2: Teaching → mode=$answer_mode, lobe=$target_lobe, content=\"$answer_content\"")
    try
        nid = teach_answer(answer_content, answer_mode, target_lobe)
        println("   → Created node: $nid")
    catch e
        println("   ⚠️  Teaching failed: $e")
    end
    after_p2_nodes = node_count()
    after_p2_groups = group_count()
    new_nodes = after_p2_nodes - before_nodes
    new_groups = after_p2_groups - before_groups
    total_new_nodes[] += new_nodes

    # ── PHASE 3: Follow-up → verify learning ──
    println("   Phase 3: Follow-up → \"$novel_input\"")
    output3 = capture_process_mission(novel_input)
    after_p3_nodes = node_count()
    after_p3_groups = group_count()
    learned = !occursin("Ask Question", output3) && !occursin("don't have a frame", output3)
    if learned
        total_learned[] += 1
    end

    println("   Result: asked=$asked, new_nodes=$new_nodes, new_groups=$new_groups, learned=$learned")

    # ── Write telemetry ──
    open(TELEMETRY_FILE, "a") do f
        println(f, "## Autogrowth $idx: $desc")
        println(f, "")
        println(f, "### Phase 1: Novel Input")
        println(f, "")
        println(f, "- **Input**: `$(novel_input)`")
        println(f, "- **Nodes**: $before_nodes → $after_p1_nodes")
        println(f, "- **Asked question**: $asked")
        println(f, "")
        if asked
            println(f, "<details><summary>Ask Output</summary>")
            println(f, "")
            println(f, "```")
            println(f, safe_truncate(output1, 600))
            println(f, "```")
            println(f, "")
            println(f, "</details>")
            println(f, "")
        end

        println(f, "### Phase 2: Answer (Internal API)")
        println(f, "")
        println(f, "- **Mode**: `:$answer_mode`")
        println(f, "- **Lobe**: `@$target_lobe`")
        println(f, "- **Content**: `$(answer_content)`")
        println(f, "- **Nodes**: $after_p1_nodes → $after_p2_nodes $(new_nodes > 0 ? "(+$new_nodes 🌱)" : "")")
        println(f, "- **Groups**: $after_p1_groups → $after_p2_groups $(new_groups > 0 ? "(+$new_groups 🌱)" : "")")
        println(f, "")

        println(f, "### Phase 3: Follow-up Verification")
        println(f, "")
        println(f, "- **Input**: `$(novel_input)`")
        println(f, "- **Nodes**: $after_p2_nodes → $after_p3_nodes")
        println(f, "- **Learned**: $(learned ? "✅ YES" : "❌ NO")")
        println(f, "")
        println(f, "<details><summary>Follow-up Output</summary>")
        println(f, "")
        println(f, "```")
        println(f, safe_truncate(output3, 600))
        println(f, "```")
        println(f, "")
        println(f, "</details>")
        println(f, "")

        println(f, "---")
        println(f, "")
    end
end

# ── Final Summary ──
println("\n" * "=" ^ 70)
println("  AUTOGROWTH TEST COMPLETE")
println("=" ^ 70)

final_nodes = node_count()
final_groups = group_count()

open(TELEMETRY_FILE, "a") do f
    println(f, "## Final Summary")
    println(f, "")
    println(f, "- **Autogrowth scenarios**: $(length(AUTOGROWTH_SCENARIOS))")
    println(f, "- **Asked questions**: $(total_asked[]) / $(length(AUTOGROWTH_SCENARIOS))")
    println(f, "- **Learned after answer**: $(total_learned[]) / $(length(AUTOGROWTH_SCENARIOS))")
    println(f, "- **Total new nodes**: $(total_new_nodes[])")
    println(f, "- **Initial node count**: $initial_nodes")
    println(f, "- **Final node count**: $final_nodes (+$(final_nodes - initial_nodes))")
    println(f, "- **Final group count**: $final_groups")
    println(f, "- **Time Nodes**: $(get_time_node_count())")
    println(f, "")

    # Time-node isolation check
    time_groups = Ref(0)
    regular_groups = Ref(0)
    mixed_groups = Ref(0)
    lock(GROUP_LOCK) do
        for (gid, grp) in GROUP_MAP
            if grp.is_time_node_group
                all_time = true
                for mid in grp.members
                    n = lock(() -> get(NODE_MAP, mid, nothing), NODE_LOCK)
                    if !isnothing(n) && !is_time_node(n)
                        all_time = false
                    end
                end
                if all_time
                    time_groups[] += 1
                else
                    mixed_groups[] += 1
                end
            else
                regular_groups[] += 1
            end
        end
    end
    println(f, "### Time-Node Group Isolation")
    println(f, "")
    println(f, "- **Regular groups**: $(regular_groups[])")
    println(f, "- **Time-node groups**: $(time_groups[])")
    println(f, "- **Mixed groups**: $(mixed_groups[])")
    if mixed_groups[] == 0
        println(f, "- ✅ **All time-node groups properly isolated**")
    else
        println(f, "- ❌ **Isolation violated!**")
    end
    println(f, "")

    # Show new nodes created by autogrowth
    all_nodes = lock(NODE_LOCK) do
        [(id, n.pattern, n.strength, get(n.json_data, "answer_mode", ""), get(n.json_data, "growth_source", "")) for (id, n) in NODE_MAP]
    end
    new_answer_nodes = filter(n -> n[5] == "hippocampal_answer", all_nodes)
    if !isempty(new_answer_nodes)
        println(f, "### Nodes Created by Autogrowth")
        println(f, "")
        println(f, "| Node | Pattern | Strength | Mode |")
        println(f, "|------|---------|----------|------|")
        for (id, pat, str, mode, _) in sort(new_answer_nodes; by=x->x[1])
            pat_short = length(pat) > 50 ? pat[1:47] * "..." : pat
            println(f, "| $id | $pat_short | $(round(str; digits=2)) | $mode |")
        end
        println(f, "")
    end

    # Top 15 strongest
    sorted = sort(all_nodes; by=x->x[3], rev=true)
    println(f, "### Top 15 Strongest Nodes")
    println(f, "")
    println(f, "| Node | Pattern | Strength |")
    println(f, "|------|---------|----------|")
    for (id, pat, str, _, _) in sorted[1:min(15, length(sorted))]
        pat_short = length(pat) > 50 ? pat[1:47] * "..." : pat
        println(f, "| $id | $pat_short | $(round(str; digits=2)) |")
    end
    println(f, "")
end

println("\n📝 Autogrowth telemetry written to $TELEMETRY_FILE")
println("📊 Final state: $final_nodes nodes, $final_groups groups (+$(final_nodes - initial_nodes) from autogrowth)")
println("   Asked: $(total_asked[]), Learned: $(total_learned[]), New nodes: $(total_new_nodes[])")
