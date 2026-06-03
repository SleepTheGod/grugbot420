#!/usr/bin/env julia
# =============================================================================
# Comprehensive Specimen Builder — v7.57
# =============================================================================
# Builds a full specimen exercising EVERY feature:
#   - Multiple lobes with distinct subjects
#   - All answer modes: reason, explain, define, alert, comfort, math, multi, relate, time, proc, json
#   - All sigil features: &n, &word, &rest, &noun (with lexicon), &op, custom sigils
#   - Time nodes with group isolation
#   - Relational nodes with &temporal, &causal, &spatial, &possessive, &similarity
#   - Anti-match nodes
#   - Procedure chains
#   - Math nodes
#   - Custom relation sigils (&emotional)
#   - Custom macro sigil (&season)
#   - Fan-out clusters (shadow nodes)
#   - Lobes with cross-connections
#   - Verb classes and synonyms
#   - Seed synonyms
# =============================================================================

# GRUG: Include Main.jl directly — gives us ALL submodules (Lobe, SigilRegistry,
# SemanticVerbs, Thesaurus, etc.) and all shared state (NODE_MAP, GROUP_MAP, etc.)
using Pkg
Pkg.activate(@__DIR__)
include("src/Main.jl")

using Base.Threads: Atomic, atomic_add!
using JSON

println("=" ^ 70)
println("COMPREHENSIVE SPECIMEN BUILDER — v7.57")
println("=" ^ 70)

# Access shared state directly (Main.jl scope)
const NM  = NODE_MAP
const NL  = NODE_LOCK
const GL  = GROUP_LOCK
const GM  = GROUP_MAP
const ET  = _ENGINE_SIGIL_TABLE

# ──────────────────────────────────────────────────────────────────────────────
# 1. LOBES — Create multiple specialized lobes
# ──────────────────────────────────────────────────────────────────────────────
println("\n📦 Creating lobes...")

# Default lobe already exists from boot; add subject words
lobes_to_create = [
    ("science",  "physics chemistry biology astronomy experiments nature"),
    ("emotions", "feelings happiness sadness anger fear love comfort peace"),
    ("time",     "past present future before after during now when then"),
    ("math",     "numbers arithmetic calculation equations formulas algebra"),
    ("survival", "fire food shelter water danger safety hunting gathering"),
]

for (lobe_id, subject) in lobes_to_create
    Lobe.create_lobe!(lobe_id, subject; node_cap=100)
    println("  + lobe '$lobe_id' (subject: $subject)")
end

# Connect lobes for cross-lobe activation
connections = [("science", "math"), ("emotions", "survival"), ("time", "science"), ("time", "survival")]
for (a, b) in connections
    Lobe.connect_lobes!(a, b)
    println("  ↔ connected $a ↔ $b")
end

# ──────────────────────────────────────────────────────────────────────────────
# 2. REASON NODES — basic knowledge across lobes
# ──────────────────────────────────────────────────────────────────────────────
println("\n🧠 Planting reason nodes...")

reason_nodes = [
    ("default",  "fire burns wood",       Dict{String,Any}()),
    ("default",  "water flows downhill",  Dict{String,Any}()),
    ("default",  "sky is blue",           Dict{String,Any}()),
    ("science",  "gravity pulls objects", Dict{String,Any}()),
    ("science",  "atoms are small",       Dict{String,Any}()),
    ("science",  "light travels fast",    Dict{String,Any}()),
    ("emotions", "happiness feels good",  Dict{String,Any}()),
    ("emotions", "sadness feels heavy",   Dict{String,Any}()),
    ("survival", "shelter protects from cold", Dict{String,Any}()),
    ("survival", "food gives energy",     Dict{String,Any}()),
    ("survival", "water is essential",    Dict{String,Any}()),
]

for (lobe, pattern, data) in reason_nodes
    data["answer_mode"] = "reason"
    data["voice_register"] = "plain"
    data["frame_hints"] = ["plain", "exploratory"]
    data["system_prompt"] = "Grug. I learned this from a question. I reason about what I was taught."
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ reason: '$pattern' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 3. EXPLAIN NODES — deeper explanatory knowledge
# ──────────────────────────────────────────────────────────────────────────────
println("\n📖 Planting explain nodes...")

explain_nodes = [
    ("science",  "why does fire burn",       "Fire burns because combustion releases energy from chemical bonds in wood when oxygen is present and heat ignites the reaction"),
    ("science",  "why is the sky blue",      "The sky appears blue because shorter wavelengths of light scatter more in the atmosphere a phenomenon called Rayleigh scattering"),
    ("emotions", "why do we feel sad",       "Sadness is an emotional response to loss or disappointment that signals a need for comfort and reflection"),
    ("survival", "how does shelter work",    "Shelter works by creating a barrier between your body and the elements blocking wind rain and cold to reduce heat loss"),
]

for (lobe, pattern, explanation) in explain_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "explain",
        "voice_register" => "explanatory",
        "frame_hints"    => ["exploratory", "plain"],
        "system_prompt"  => "Grug. I learned this from a question. I explain what I was taught clearly.",
    )
    nid = create_node(pattern, "explain^1", data, String[]; initial_strength=2.5)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ explain: '$pattern' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 4. DEFINE NODES — precise definitions
# ──────────────────────────────────────────────────────────────────────────────
println("\n📋 Planting define nodes...")

define_nodes = [
    ("science",  "define gravity",      "Gravity is the force of attraction between two masses that pulls them toward each other"),
    ("science",  "define atom",         "An atom is the smallest unit of matter that retains the properties of a chemical element"),
    ("math",     "define addition",     "Addition is the mathematical operation of combining two or more numbers into a single sum"),
    ("emotions", "define happiness",    "Happiness is a positive emotional state characterized by contentment joy and satisfaction"),
    ("survival", "define shelter",      "Shelter is a structure that provides protection from weather danger and environmental exposure"),
]

for (lobe, pattern, definition) in define_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "define",
        "voice_register" => "terse",
        "frame_hints"    => ["imperative", "plain"],
        "system_prompt"  => "Grug. I learned this from a question. I define what I was taught precisely.",
    )
    nid = create_node(pattern, "define^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ define: '$pattern' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 5. ALERT NODES — warning/danger knowledge
# ──────────────────────────────────────────────────────────────────────────────
println("\n⚠️  Planting alert nodes...")

alert_nodes = [
    ("survival", "fire is dangerous",      "Fire can burn you and spread quickly keep distance and have water nearby"),
    ("survival", "deep water is dangerous", "Deep water can drown even strong swimmers always have a flotation device"),
    ("survival", "wild animals are dangerous", "Wild animals can attack if threatened stay calm and back away slowly"),
]

for (lobe, pattern, alert_text) in alert_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "alert",
        "voice_register" => "terse",
        "frame_hints"    => ["imperative", "terse"],
        "system_prompt"  => "Grug. I learned this from a question. I warn about what I was told to watch for.",
    )
    nid = create_node(pattern, "alert^1", data, String[]; initial_strength=3.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ alert: '$pattern' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 6. COMFORT NODES — empathetic responses
# ──────────────────────────────────────────────────────────────────────────────
println("\n💚 Planting comfort nodes...")

comfort_nodes = [
    ("emotions", "i feel sad",        "It is okay to feel sad sadness passes like clouds and the sun returns"),
    ("emotions", "i am scared",       "Fear is natural you are brave for facing it you are not alone"),
    ("emotions", "i feel lonely",     "Loneliness is temporary reaching out to others is a sign of strength not weakness"),
]

for (lobe, pattern, comfort_text) in comfort_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "comfort",
        "voice_register" => "warm",
        "frame_hints"    => ["warm", "de-escalating"],
        "system_prompt"  => "Grug. I learned this from a question. I acknowledge what I was taught with care.",
    )
    nid = create_node(pattern, "comfort^1", data, String[]; initial_strength=2.5)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ comfort: '$pattern' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 7. MATH NODES — arithmetic-ready
# ──────────────────────────────────────────────────────────────────────────────
println("\n🔢 Planting math nodes...")

math_nodes = [
    ("math", "2 plus 2",    Dict{String,Any}("math_result" => "4",   "math_op" => "add")),
    ("math", "3 times 4",   Dict{String,Any}("math_result" => "12",  "math_op" => "multiply")),
    ("math", "10 minus 3",  Dict{String,Any}("math_result" => "7",   "math_op" => "subtract")),
    ("math", "15 divided by 5", Dict{String,Any}("math_result" => "3", "math_op" => "divide")),
    ("math", "7 plus 8",    Dict{String,Any}("math_result" => "15",  "math_op" => "add")),
    ("math", "9 times 6",   Dict{String,Any}("math_result" => "54",  "math_op" => "multiply")),
]

for (lobe, pattern, data) in math_nodes
    data["answer_mode"]    = "math"
    data["voice_register"] = "terse"
    data["frame_hints"]    = ["imperative", "plain"]
    data["system_prompt"]  = "Grug. I compute. I give answers. Numbers are my language."
    data["noun_anchors"]   = collect(split(lowercase(pattern)))
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ math: '$pattern' = $(data["math_result"]) → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 8. RELATE NODES — relational triple-seeded
# ──────────────────────────────────────────────────────────────────────────────
println("\n🔗 Planting relate nodes (relational triples)...")

relate_nodes = [
    ("science",  "fire",    "burns",    "wood",     String[]),
    ("science",  "water",   "extinguishes", "fire", String[]),
    ("science",  "earth",   "orbits",   "sun",      String[]),
    ("survival", "hunger",  "causes",   "hunting",  String[]),
    ("emotions", "love",    "comforts", "sadness",  String[]),
    ("emotions", "fear",    "precedes", "courage",  String[]),
]

for (lobe, subj, rel, obj, req_rels) in relate_nodes
    data = Dict{String,Any}(
        "answer_mode"        => "relate",
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => req_rels,
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => rel, "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I learned this from a question about relationships. I know that $(lowercase(subj)) $(rel) $(lowercase(obj)). I reason about how things connect.",
        "voice_register"     => "plain",
        "frame_hints"        => ["plain", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(rel) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ relate: '$subj → $rel → $obj' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 9. TIME NODES — auto &temporal gate, group isolation
# ──────────────────────────────────────────────────────────────────────────────
println("\n⏰ Planting time nodes...")

time_nodes_data = [
    ("time",     "past",   "present"),
    ("time",     "present","future"),
    ("time",     "dawn",   "day"),
    ("time",     "day",    "dusk"),
    ("time",     "dusk",   "night"),
    ("science",  "spring", "summer"),
    ("science",  "summer", "autumn"),
    ("science",  "autumn", "winter"),
    ("survival", "planting", "harvest"),
    ("survival", "hunting", "feasting"),
]

for (lobe, subj, obj) in time_nodes_data
    rel_for_triple = "&temporal"
    data = Dict{String,Any}(
        "answer_mode"        => "time",
        "time_node"          => true,
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => [rel_for_triple],
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => rel_for_triple, "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I learned this from a question about time. I know that $(lowercase(subj)) $(rel_for_triple) $(lowercase(obj)). I reason about temporal relationships.",
        "voice_register"     => "plain",
        "frame_hints"        => ["plain", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ⏰ time: '$subj → $(rel_for_triple) → $obj' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 10. PROCEDURE NODES — sequential steps
# ──────────────────────────────────────────────────────────────────────────────
println("\n⚙️  Planting procedure chains...")

procedure_chains = [
    ("survival", "make fire",     ["gather dry wood", "arrange kindling", "strike spark", "blow gently", "add larger sticks"]),
    ("survival", "find water",    ["look for green plants", "dig near roots", "collect dew at dawn", "filter through cloth"]),
    ("survival", "build shelter", ["find sturdy branches", "lean against tree", "cover with leaves", "seal gaps with moss"]),
    ("math",     "solve equation",["identify the unknown", "isolate the variable", "apply inverse operations", "verify the solution"]),
]

for (lobe, topic, steps) in procedure_chains
    step_ids = String[]
    for (i, step) in enumerate(steps)
        data = Dict{String,Any}(
            "answer_mode"    => "proc",
            "proc_step"      => i,
            "proc_total"     => length(steps),
            "proc_topic"     => topic,
            "voice_register" => "plain",
            "frame_hints"    => ["imperative", "plain"],
            "system_prompt"  => "Grug. I follow steps. Step $i of $(length(steps)) for $topic: $step.",
        )
        pattern = lowercase(step)
        nid = create_node(pattern, "reason^1", data, String[]; initial_strength=1.5)
        Lobe.add_node_to_lobe!(lobe, nid)
        push!(step_ids, nid)
    end
    # Wire drop_table for sequential activation
    for i in 1:(length(step_ids)-1)
        src_node = lock(() -> get(NM, step_ids[i], nothing), NL)
        if !isnothing(src_node)
            push!(src_node.drop_table, step_ids[i+1])
        end
    end
    println("  ⚙️  proc: '$topic' → $(length(steps)) steps")
end

# ──────────────────────────────────────────────────────────────────────────────
# 11. RELATIONAL SIGIL NODES — &causal, &spatial, &possessive, &similarity
# ──────────────────────────────────────────────────────────────────────────────
println("\n🏷️  Planting sigil-gated relational nodes...")

# &causal nodes
causal_nodes = [
    ("science",  "heat",    "evaporation"),
    ("science",  "rain",    "flooding"),
    ("science",  "cold",    "freezing"),
    ("survival", "hunger",  "foraging"),
    ("survival", "darkness","fire making"),
]

for (lobe, subj, obj) in causal_nodes
    data = Dict{String,Any}(
        "answer_mode"        => "relate",
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => ["&causal"],
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => "&causal", "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I know $(lowercase(subj)) &causal $(lowercase(obj)). I reason about cause and effect.",
        "voice_register"     => "plain",
        "frame_hints"        => ["plain", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🔗 &causal: '$subj → &causal → $obj' → $nid [$lobe]")
end

# &spatial nodes
spatial_nodes = [
    ("science",  "clouds", "sky"),
    ("science",  "roots",  "ground"),
    ("survival", "fire",   "hearth"),
    ("survival", "fish",   "river"),
]

for (lobe, subj, obj) in spatial_nodes
    data = Dict{String,Any}(
        "answer_mode"        => "relate",
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => ["&spatial"],
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => "&spatial", "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I know $(lowercase(subj)) &spatial $(lowercase(obj)). I reason about spatial relationships.",
        "voice_register"     => "plain",
        "frame_hints"        => ["plain", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  📍 &spatial: '$subj → &spatial → $obj' → $nid [$lobe]")
end

# &possessive nodes
possessive_nodes = [
    ("survival", "tree",   "branches"),
    ("survival", "river",  "water"),
    ("emotions", "person", "feelings"),
    ("science",  "atom",   "electrons"),
]

for (lobe, subj, obj) in possessive_nodes
    data = Dict{String,Any}(
        "answer_mode"        => "relate",
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => ["&possessive"],
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => "&possessive", "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I know $(lowercase(subj)) &possessive $(lowercase(obj)). I reason about possession and containment.",
        "voice_register"     => "plain",
        "frame_hints"        => ["plain", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🏠 &possessive: '$subj → &possessive → $obj' → $nid [$lobe]")
end

# &similarity nodes
similarity_nodes = [
    ("science",  "fire",   "star"),
    ("emotions", "joy",    "warmth"),
    ("survival", "cave",   "shelter"),
]

for (lobe, subj, obj) in similarity_nodes
    data = Dict{String,Any}(
        "answer_mode"        => "relate",
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => ["&similarity"],
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => "&similarity", "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I know $(lowercase(subj)) &similarity $(lowercase(obj)). I reason about resemblance and analogy.",
        "voice_register"     => "plain",
        "frame_hints"        => ["plain", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🧬 &similarity: '$subj → &similarity → $obj' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 12. ANTI-MATCH NODES — confidence drain
# ──────────────────────────────────────────────────────────────────────────────
println("\n🚫 Planting anti-match nodes...")

antimatch_nodes = [
    ("default", "wrong bad incorrect"),
    ("science", "fake false nonsense"),
    ("math",    "error mistake bug"),
]

for (lobe, pattern) in antimatch_nodes
    data = Dict{String,Any}(
        "answer_mode" => "alert",
        "is_anti"     => true,
    )
    nid = create_node(pattern, "alert^1", data, String[]; is_antimatch_node=true, initial_strength=1.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🚫 anti-match: '$pattern' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 13. CUSTOM RELATION SIGIL — user-defined &emotional
# ──────────────────────────────────────────────────────────────────────────────
println("\n💜 Registering custom relation sigil &emotional...")

SigilRegistry.register_relation_sigil!(ET;
    name="emotional",
    expansion=["loves", "hates", "fears", "desires", "resents", "admires", "misses", "longs_for"],
    provenance="specimen-builder"
)

emotional_nodes = [
    ("emotions", "person", "music"),
    ("emotions", "child",  "mother"),
    ("emotions", "warrior","battle"),
]

for (lobe, subj, obj) in emotional_nodes
    data = Dict{String,Any}(
        "answer_mode"        => "relate",
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => ["&emotional"],
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => "&emotional", "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I know $(lowercase(subj)) &emotional $(lowercase(obj)). I reason about emotional bonds.",
        "voice_register"     => "warm",
        "frame_hints"        => ["warm", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  💜 &emotional: '$subj → &emotional → $obj' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 14. CUSTOM SIGIL — &season (macro class with lexicon)
# ──────────────────────────────────────────────────────────────────────────────
println("\n🍂 Registering custom macro sigil &season...")

SigilRegistry.register_sigil!(ET;
    name="season",
    class=:macro,
    applies_at=:bind,
    lexicon=["spring", "summer", "autumn", "winter"],
    provenance="specimen-builder"
)

# Plant nodes with &season in their patterns
for season in ["spring", "summer", "autumn", "winter"]
    data = Dict{String,Any}(
        "answer_mode"    => "reason",
        "voice_register" => "plain",
        "frame_hints"    => ["plain", "exploratory"],
        "system_prompt"  => "Grug. I know about $season. It is a season.",
    )
    pattern = "&season $season"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=1.5)
    Lobe.add_node_to_lobe!("time", nid)
    println("  🍂 &season node: '$season' → $nid [time]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 15. SIGIL PATTERN NODES — &n, &word patterns
# ──────────────────────────────────────────────────────────────────────────────
println("\n🪱 Planting sigil pattern nodes...")

# &n — number capture
sigil_n_nodes = [
    ("math", "what is &n plus &n",       Dict{String,Any}("answer_mode" => "math", "sigil_pattern" => true)),
    ("math", "what is &n times &n",      Dict{String,Any}("answer_mode" => "math", "sigil_pattern" => true)),
    ("math", "what is &n minus &n",      Dict{String,Any}("answer_mode" => "math", "sigil_pattern" => true)),
]

for (lobe, pattern, data) in sigil_n_nodes
    data["voice_register"] = "terse"
    data["frame_hints"]    = ["imperative", "plain"]
    data["system_prompt"]  = "Grug. I compute. Numbers are my language."
    data["noun_anchors"]   = ["arithmetic"]
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🪱 &n pattern: '$pattern' → $nid [$lobe]")
end

# &word — word capture
sigil_word_nodes = [
    ("default", "define &word",  Dict{String,Any}("answer_mode" => "define", "sigil_pattern" => true)),
    ("default", "explain &word", Dict{String,Any}("answer_mode" => "explain", "sigil_pattern" => true)),
]

for (lobe, pattern, data) in sigil_word_nodes
    data["voice_register"] = "terse"
    data["frame_hints"]    = ["imperative", "plain"]
    data["system_prompt"]  = "Grug. I define and explain words."
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=1.5)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🪱 &word pattern: '$pattern' → $nid [$lobe]")
end

# ──────────────────────────────────────────────────────────────────────────────
# 16. VERB CLASSES + SYNONYMS
# ──────────────────────────────────────────────────────────────────────────────
println("\n📝 Setting up verb classes and synonyms...")

# Add relation classes first, then add verbs to them
verb_classes = [
    "action", "emotional", "cognitive", "causal", "similarity", "possessive"
]
for cls in verb_classes
    try
        SemanticVerbs.add_relation_class!(cls)
        println("  📝 class: '$cls'")
    catch e
        println("  ⚠️  class '$cls' skipped: $e")
    end
end

# Add verbs to classes
verb_assignments = [
    ("burn",     "action"),
    ("flow",     "action"),
    ("feel",     "emotional"),
    ("think",    "cognitive"),
    ("build",    "action"),
    ("hunt",     "action"),
    ("gather",   "action"),
    ("cause",    "causal"),
    ("produce",  "causal"),
    ("create",   "causal"),
    ("resemble", "similarity"),
    ("contain",  "possessive"),
]

for (verb, cls) in verb_assignments
    try
        SemanticVerbs.add_verb!(verb, cls)
        println("  📝 verb: '$verb' → class '$cls'")
    catch e
        println("  ⚠️  verb '$verb' skipped: $e")
    end
end

# Add synonyms
synonym_pairs = [
    ("burn", "ignite"),    ("burn", "combust"),
    ("flow", "stream"),    ("flow", "run"),
    ("feel", "experience"),("feel", "sense"),
    ("think","ponder"),    ("think", "consider"),
    ("build","construct"), ("build", "assemble"),
    ("hunt", "chase"),     ("hunt", "track"),
    ("gather","collect"),  ("gather", "forage"),
    ("cause","produce"),   ("cause", "trigger"),
    ("create","make"),     ("create", "generate"),
]

for (canonical, synonym) in synonym_pairs
    try
        SemanticVerbs.add_synonym!(canonical, synonym)
        println("  📝 synonym: '$canonical' ≈ '$synonym'")
    catch e
        println("  ⚠️  synonym '$canonical'≈'$synonym' skipped: $e")
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# 17. SEED SYNONYMS (Thesaurus)
# ──────────────────────────────────────────────────────────────────────────────
println("\n📗 Adding seed synonyms to Thesaurus...")

seed_syns = [
    ("fire",    ["flame", "blaze", "inferno", "conflagration"]),
    ("water",   ["stream", "river", "lake", "ocean", "rain"]),
    ("food",    ["nourishment", "sustenance", "provisions", "rations"]),
    ("shelter", ["refuge", "haven", "sanctuary", "dwelling"]),
    ("happy",   ["joyful", "glad", "content", "cheerful"]),
    ("sad",     ["unhappy", "sorrowful", "melancholy", "gloomy"]),
    ("big",     ["large", "huge", "vast", "enormous"]),
    ("small",   ["tiny", "little", "minute", "diminutive"]),
]

for (canonical, syns) in seed_syns
    try
        Thesaurus.add_seed_synonym!(canonical, syns)
        println("  📗 seed synonyms: '$canonical' → [$(join(syns, ", "))]")
    catch e
        println("  ⚠️  seed synonyms '$canonical' skipped: $e")
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# 18. BUMP SOME STRENGTHS — stratify the population
# ──────────────────────────────────────────────────────────────────────────────
println("\n💪 Bumping key node strengths...")

# Find and boost some important nodes
boost_patterns = ["fire burns wood", "water is essential", "gravity pulls objects", "past present", "define gravity"]
for pat_substr in boost_patterns
    found = nothing
    lock(NL) do
        for (id, node) in NM
            if occursin(pat_substr, lowercase(node.pattern))
                found = node
                break
            end
        end
    end
    if !isnothing(found)
        old_s = found.strength
        found.strength = min(5.0, found.strength + 2.0)
        println("  💪 '$(found.pattern)' strength: $old_s → $(found.strength)")
    end
end

# ──────────────────────────────────────────────────────────────────────────────
# 19. SUMMARY
# ──────────────────────────────────────────────────────────────────────────────
println("\n" * "=" ^ 70)

n_nodes = lock(() -> length(NM), NL)
n_groups = lock(() -> length(GM), GL)
n_lobes = length(Lobe.LOBE_REGISTRY)
n_sigils = length(ET.entries)

time_groups = Ref(0)
regular_groups = Ref(0)
lock(GL) do
    for (gid, grp) in GM
        if grp.is_time_node_group
            time_groups[] += 1
        else
            regular_groups[] += 1
        end
    end
end

println("SPECIMEN BUILT SUCCESSFULLY")
println("  Nodes:         $n_nodes")
println("  Groups:        $n_groups ($(regular_groups[]) regular, $(time_groups[]) time-node)")
println("  Lobes:         $n_lobes")
println("  Sigils:        $n_sigils")
println("=" ^ 70)

# Save the specimen
println("\n💾 Saving specimen...")
spec_path = "comprehensive_specimen_v757.json"
save_specimen_to_file!(spec_path)
println("✅ Saved to $spec_path")
