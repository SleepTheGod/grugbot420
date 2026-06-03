#!/usr/bin/env julia
# =============================================================================
# Full Specimen Builder + Conversation Log — v7.57
# =============================================================================
# Builds a comprehensive specimen exercising EVERY engine feature:
#   - 7 lobes with cross-connections + AIML tribes
#   - All 11 answer modes: reason, explain, define, alert, comfort, math, multi, relate, time, proc, json
#   - All sigil classes: &n (lambda/number), &word (lambda/word), &rest (lambda/slurp),
#     &noun (macro+lexicon), &op (macro+lexicon), &season (custom macro),
#     &emotional (custom relation), &temporal, &causal, &spatial, &possessive, &similarity
#   - Time nodes with group isolation
#   - Anti-match nodes
#   - Procedure chains with drop_table wiring
#   - Fan-out clusters
#   - Verb classes + synonyms
#   - Thesaurus seed synonyms
#   - Inhibitions
#   - AIML executive nodes per lobe
#   - Multi-mode answer nodes
#   - JSON passthrough nodes
# Then runs a multi-turn conversation with Grug, capturing responses,
# and writes both a JSON save file AND an MD conversation log.
# =============================================================================

using Pkg
Pkg.activate(@__DIR__)
include("src/Main.jl")

using JSON
using Dates

println("=" ^ 70)
println("  FULL SPECIMEN BUILDER + CONVERSATION — v7.57")
println("=" ^ 70)

# Access shared state directly
const NM  = NODE_MAP
const NL  = NODE_LOCK
const GL  = GROUP_LOCK
const GM  = GROUP_MAP
const ET  = _ENGINE_SIGIL_TABLE

# ─────────────────────────────────────────────────────────────────────────────
# 1. LOBES — 7 specialized lobes + AIML tribes
# ─────────────────────────────────────────────────────────────────────────────
println("\n📦 Creating lobes...")

lobes_to_create = [
    ("science",  "physics chemistry biology astronomy experiments nature", 100),
    ("emotions", "feelings happiness sadness anger fear love comfort peace", 80),
    ("time",     "past present future before after during now when then", 60),
    ("math",     "numbers arithmetic calculation equations formulas algebra", 80),
    ("survival", "fire food shelter water danger safety hunting gathering", 100),
    ("language", "words definitions grammar synonyms meanings concepts", 60),
    ("social",   "friendship cooperation sharing community family trust", 60),
]

for (lobe_id, subject, cap) in lobes_to_create
    Lobe.create_lobe!(lobe_id, subject; node_cap=cap)
    # Register AIML tribe for each lobe
    aiml_cap = AIMLNodeSystem.register_lobe!(lobe_id, cap)
    println("  + lobe '$lobe_id' (cap=$cap, aiml_cap=$aiml_cap)")
end

# Connect lobes for cross-lobe activation
connections = [
    ("science", "math"), ("emotions", "survival"), ("time", "science"),
    ("time", "survival"), ("emotions", "social"), ("science", "language"),
    ("survival", "social"), ("language", "math"),
]
for (a, b) in connections
    Lobe.connect_lobes!(a, b)
    println("  ↔ connected $a ↔ $b")
end

# ─────────────────────────────────────────────────────────────────────────────
# 2. REASON NODES — basic knowledge across lobes
# ─────────────────────────────────────────────────────────────────────────────
println("\n🧠 Planting reason nodes...")

reason_nodes = [
    ("default",  "fire burns wood",       2.0),
    ("default",  "water flows downhill",  2.0),
    ("default",  "sky is blue",           2.0),
    ("science",  "gravity pulls objects", 2.5),
    ("science",  "atoms are small",       2.0),
    ("science",  "light travels fast",    2.0),
    ("science",  "earth orbits the sun",  2.0),
    ("emotions", "happiness feels good",  2.0),
    ("emotions", "sadness feels heavy",   2.0),
    ("survival", "shelter protects from cold", 2.5),
    ("survival", "food gives energy",     2.0),
    ("survival", "water is essential",    2.5),
    ("social",   "friendship brings joy", 2.0),
    ("social",   "cooperation builds trust", 2.0),
    ("language", "words carry meaning",   2.0),
]

for (lobe, pattern, str) in reason_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "reason",
        "voice_register" => "plain",
        "frame_hints"    => ["plain", "exploratory"],
        "system_prompt"  => "Grug. I learned this from a question. I reason about what I was taught.",
    )
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=str)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ✓ reason: '$pattern' → $nid [$lobe]")
end

# ─────────────────────────────────────────────────────────────────────────────
# 3. EXPLAIN NODES
# ─────────────────────────────────────────────────────────────────────────────
println("\n📖 Planting explain nodes...")

explain_nodes = [
    ("science",  "why does fire burn",    "Fire burns because combustion releases energy from chemical bonds in wood when oxygen is present and heat ignites the reaction"),
    ("science",  "why is the sky blue",   "The sky appears blue because shorter wavelengths of light scatter more in the atmosphere a phenomenon called Rayleigh scattering"),
    ("emotions", "why do we feel sad",    "Sadness is an emotional response to loss or disappointment that signals a need for comfort and reflection"),
    ("survival", "how does shelter work", "Shelter works by creating a barrier between your body and the elements blocking wind rain and cold to reduce heat loss"),
    ("social",   "why do we need friends", "We need friends because social bonds provide emotional support reduce stress and help us survive challenges together"),
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

# ─────────────────────────────────────────────────────────────────────────────
# 4. DEFINE NODES
# ─────────────────────────────────────────────────────────────────────────────
println("\n📋 Planting define nodes...")

define_nodes = [
    ("science",  "define gravity",   "Gravity is the force of attraction between two masses that pulls them toward each other"),
    ("science",  "define atom",      "An atom is the smallest unit of matter that retains the properties of a chemical element"),
    ("math",     "define addition",  "Addition is the mathematical operation of combining two or more numbers into a single sum"),
    ("emotions", "define happiness", "Happiness is a positive emotional state characterized by contentment joy and satisfaction"),
    ("survival", "define shelter",   "Shelter is a structure that provides protection from weather danger and environmental exposure"),
    ("language", "define synonym",   "A synonym is a word that means the same or nearly the same as another word in the same language"),
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

# ─────────────────────────────────────────────────────────────────────────────
# 5. ALERT NODES
# ─────────────────────────────────────────────────────────────────────────────
println("\n⚠️  Planting alert nodes...")

alert_nodes = [
    ("survival", "fire is dangerous",       "Fire can burn you and spread quickly keep distance and have water nearby"),
    ("survival", "deep water is dangerous",  "Deep water can drown even strong swimmers always have a flotation device"),
    ("survival", "wild animals are dangerous","Wild animals can attack if threatened stay calm and back away slowly"),
    ("social",   "betrayal is dangerous",    "Betrayal destroys trust and community guard your word and honor your bonds"),
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

# ─────────────────────────────────────────────────────────────────────────────
# 6. COMFORT NODES
# ─────────────────────────────────────────────────────────────────────────────
println("\n💚 Planting comfort nodes...")

comfort_nodes = [
    ("emotions", "i feel sad",     "It is okay to feel sad sadness passes like clouds and the sun returns"),
    ("emotions", "i am scared",    "Fear is natural you are brave for facing it you are not alone"),
    ("emotions", "i feel lonely",  "Loneliness is temporary reaching out to others is a sign of strength not weakness"),
    ("social",   "i miss someone", "Missing someone means they mattered hold that love gently it is precious"),
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

# ─────────────────────────────────────────────────────────────────────────────
# 7. MATH NODES — arithmetic-ready
# ─────────────────────────────────────────────────────────────────────────────
println("\n🔢 Planting math nodes...")

math_nodes = [
    ("2 plus 2",          "4",  "add"),
    ("3 times 4",         "12", "multiply"),
    ("10 minus 3",        "7",  "subtract"),
    ("15 divided by 5",   "3",  "divide"),
    ("7 plus 8",          "15", "add"),
    ("9 times 6",         "54", "multiply"),
    ("20 minus 8",        "12", "subtract"),
    ("100 divided by 10", "10", "divide"),
]

for (pattern, result, op) in math_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "math",
        "voice_register" => "terse",
        "frame_hints"    => ["imperative", "plain"],
        "system_prompt"  => "Grug. I compute. I give answers. Numbers are my language.",
        "noun_anchors"   => collect(split(lowercase(pattern))),
        "math_result"    => result,
        "math_op"        => op,
    )
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!("math", nid)
    println("  ✓ math: '$pattern' = $result → $nid")
end

# ─────────────────────────────────────────────────────────────────────────────
# 8. RELATE NODES — relational triple-seeded
# ─────────────────────────────────────────────────────────────────────────────
println("\n🔗 Planting relate nodes...")

relate_nodes = [
    ("science",  "fire",    "burns",       "wood"),
    ("science",  "water",   "extinguishes","fire"),
    ("science",  "earth",   "orbits",      "sun"),
    ("survival", "hunger",  "causes",      "hunting"),
    ("emotions", "love",    "comforts",    "sadness"),
    ("emotions", "fear",    "precedes",    "courage"),
    ("social",   "sharing", "strengthens", "community"),
    ("social",   "trust",   "enables",     "cooperation"),
]

for (lobe, subj, rel, obj) in relate_nodes
    data = Dict{String,Any}(
        "answer_mode"        => "relate",
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => String[],
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

# ─────────────────────────────────────────────────────────────────────────────
# 9. TIME NODES — auto &temporal gate, group isolation
# ─────────────────────────────────────────────────────────────────────────────
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
    ("survival", "planting","harvest"),
    ("survival", "hunting","feasting"),
    ("time",     "morning","afternoon"),
    ("time",     "winter", "spring"),
]

for (lobe, subj, obj) in time_nodes_data
    rel_for_triple = "&temporal"
    data = Dict{String,Any}(
        "answer_mode"        => "time",
        "time_node"          => true,
        "noun_anchors"       => [lowercase(subj), lowercase(obj)],
        "required_relations" => [rel_for_triple],
        "seeded_triple"      => Dict("subject" => lowercase(subj), "relation" => rel_for_triple, "object" => lowercase(obj)),
        "system_prompt"      => "Grug. I learned this from a question about time. I know that $(lowercase(subj)) &temporal $(lowercase(obj)). I reason about temporal relationships.",
        "voice_register"     => "plain",
        "frame_hints"        => ["plain", "exploratory"],
    )
    pattern = "$(lowercase(subj)) $(lowercase(obj))"
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  ⏰ time: '$subj → &temporal → $obj' → $nid [$lobe]")
end

# ─────────────────────────────────────────────────────────────────────────────
# 10. PROCEDURE NODES — sequential steps with drop_table wiring
# ─────────────────────────────────────────────────────────────────────────────
println("\n⚙️  Planting procedure chains...")

procedure_chains = [
    ("survival", "make fire",     ["gather dry wood", "arrange kindling", "strike spark", "blow gently", "add larger sticks"]),
    ("survival", "find water",    ["look for green plants", "dig near roots", "collect dew at dawn", "filter through cloth"]),
    ("survival", "build shelter", ["find sturdy branches", "lean against tree", "cover with leaves", "seal gaps with moss"]),
    ("math",     "solve equation",["identify the unknown", "isolate the variable", "apply inverse operations", "verify the solution"]),
    ("social",   "make friend",   ["approach with smile", "share something", "listen carefully", "offer help", "be reliable"]),
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

# ─────────────────────────────────────────────────────────────────────────────
# 11. MULTI-MODE NODES — pipe-delimited multi-answer
# ─────────────────────────────────────────────────────────────────────────────
println("\n🎯 Planting multi-mode nodes...")

multi_nodes = [
    ("science",  "describe and explain fire", ":reason fire gives warmth and light | :explain fire burns because combustion releases energy from chemical bonds"),
    ("emotions", "comfort and explain sadness", ":comfort it is okay to feel sad | :explain sadness is a signal that something matters to you"),
    ("survival", "alert and explain water danger", ":alert deep water is dangerous | :explain water can pull you under even if you swim well"),
]

for (lobe, pattern, content) in multi_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "multi",
        "multi_content"  => content,
        "voice_register" => "plain",
        "frame_hints"    => ["plain", "exploratory"],
        "system_prompt"  => "Grug. I respond in multiple ways to give a complete answer.",
    )
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🎯 multi: '$pattern' → $nid [$lobe]")
end

# ─────────────────────────────────────────────────────────────────────────────
# 12. JSON PASSTHROUGH NODES
# ─────────────────────────────────────────────────────────────────────────────
println("\n📊 Planting JSON passthrough nodes...")

json_nodes = [
    ("math", "system status report", Dict{String,Any}("format"=>"json", "payload"=>Dict("type"=>"status","nodes"=>length(NODE_MAP),"healthy"=>true))),
    ("science", "element properties carbon", Dict{String,Any}("format"=>"json", "payload"=>Dict("element"=>"carbon","atomic_number"=>6,"symbol"=>"C","type"=>"nonmetal"))),
]

for (lobe, pattern, jdata) in json_nodes
    data = Dict{String,Any}(
        "answer_mode"    => "json",
        "voice_register" => "terse",
        "frame_hints"    => ["imperative", "plain"],
        "system_prompt"  => "Grug. I provide structured data. Facts are my language.",
    )
    merge!(data, jdata)
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=1.5)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  📊 json: '$pattern' → $nid [$lobe]")
end

# ─────────────────────────────────────────────────────────────────────────────
# 13. RELATIONAL SIGIL NODES — &causal, &spatial, &possessive, &similarity
# ─────────────────────────────────────────────────────────────────────────────
println("\n🏷️  Planting sigil-gated relational nodes...")

# &causal nodes
causal_nodes = [
    ("science",  "heat",     "evaporation"),
    ("science",  "rain",     "flooding"),
    ("science",  "cold",     "freezing"),
    ("survival", "hunger",   "foraging"),
    ("survival", "darkness", "fire making"),
    ("social",   "betrayal", "isolation"),
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
    ("social",   "people", "village"),
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
    ("social",   "clan",   "elders"),
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
    ("social",   "family", "roots"),
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

# ─────────────────────────────────────────────────────────────────────────────
# 14. ANTI-MATCH NODES — confidence drain
# ─────────────────────────────────────────────────────────────────────────────
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

# ─────────────────────────────────────────────────────────────────────────────
# 15. CUSTOM RELATION SIGIL — &emotional
# ─────────────────────────────────────────────────────────────────────────────
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
    ("social",   "friend", "companion"),
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

# ─────────────────────────────────────────────────────────────────────────────
# 16. CUSTOM SIGIL — &season (macro class with lexicon)
# ─────────────────────────────────────────────────────────────────────────────
println("\n🍂 Registering custom macro sigil &season...")

SigilRegistry.register_sigil!(ET;
    name="season",
    class=:macro,
    applies_at=:bind,
    lexicon=["spring", "summer", "autumn", "winter"],
    provenance="specimen-builder"
)

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

# ─────────────────────────────────────────────────────────────────────────────
# 17. CUSTOM TAG SIGIL — &danger (tag class)
# ─────────────────────────────────────────────────────────────────────────────
println("\n🔥 Registering custom tag sigil &danger...")

SigilRegistry.register_sigil!(ET;
    name="danger",
    class=:tag,
    applies_at=:bind,
    provenance="specimen-builder"
)

for danger_word in ["poison", "venom", "hazard"]
    data = Dict{String,Any}(
        "answer_mode"    => "alert",
        "voice_register" => "terse",
        "frame_hints"    => ["imperative", "terse"],
        "system_prompt"  => "Grug. I recognize danger. I warn about threats.",
    )
    pattern = "&danger $danger_word"
    nid = create_node(pattern, "alert^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!("survival", nid)
    println("  🔥 &danger node: '$danger_word' → $nid [survival]")
end

# ─────────────────────────────────────────────────────────────────────────────
# 18. SIGIL PATTERN NODES — &n, &word patterns
# ─────────────────────────────────────────────────────────────────────────────
println("\n🫱 Planting sigil pattern nodes...")

# &n — number capture
sigil_n_nodes = [
    ("math", "what is &n plus &n",       "math"),
    ("math", "what is &n times &n",      "math"),
    ("math", "what is &n minus &n",      "math"),
    ("math", "what is &n divided by &n", "math"),
]

for (lobe, pattern, mode) in sigil_n_nodes
    data = Dict{String,Any}(
        "answer_mode"    => mode,
        "sigil_pattern"  => true,
        "voice_register" => "terse",
        "frame_hints"    => ["imperative", "plain"],
        "system_prompt"  => "Grug. I compute. Numbers are my language.",
        "noun_anchors"   => ["arithmetic"],
    )
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=2.0)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🫱 &n pattern: '$pattern' → $nid [$lobe]")
end

# &word — word capture
sigil_word_nodes = [
    ("language", "define &word",  "define"),
    ("language", "explain &word", "explain"),
    ("language", "what is &word", "reason"),
]

for (lobe, pattern, mode) in sigil_word_nodes
    data = Dict{String,Any}(
        "answer_mode"    => mode,
        "sigil_pattern"  => true,
        "voice_register" => "terse",
        "frame_hints"    => ["imperative", "plain"],
        "system_prompt"  => "Grug. I define and explain words.",
    )
    nid = create_node(pattern, "reason^1", data, String[]; initial_strength=1.5)
    Lobe.add_node_to_lobe!(lobe, nid)
    println("  🫱 &word pattern: '$pattern' → $nid [$lobe]")
end

# ─────────────────────────────────────────────────────────────────────────────
# 19. AIML EXECUTIVE NODES per lobe
# ─────────────────────────────────────────────────────────────────────────────
println("\n🤖 Adding AIML executive nodes...")

aiml_nodes_data = [
    ("science",  "sci_exec_01", "When user asks about natural phenomena, check for matching reason node first"),
    ("science",  "sci_exec_02", "If question contains 'why', prefer explain mode over reason mode"),
    ("emotions", "emo_exec_01", "If user expresses negative feeling, activate comfort mode before reasoning"),
    ("emotions", "emo_exec_02", "Mirror the emotional register of the user's input"),
    ("math",     "math_exec_01","For arithmetic expressions, always use math mode with terse voice"),
    ("survival", "surv_exec_01","If danger words detected, escalate to alert mode immediately"),
    ("survival", "surv_exec_02","For 'how to' questions, activate procedure chain"),
    ("time",     "time_exec_01","Temporal questions should use time-node relations"),
    ("social",   "soc_exec_01", "Friendship and trust topics prefer warm voice register"),
    ("language", "lang_exec_01", "Definition requests should use define mode with terse voice"),
]

for (lobe_id, node_id, template) in aiml_nodes_data
    try
        node = AIMLNodeSystem.add_aiml_node!(lobe_id, node_id, template; initial_strength=3.0)
        println("  🤖 AIML: '$node_id' in $lobe_id → strength=$(node.strength)")
    catch e
        println("  ⚠️  AIML '$node_id' in $lobe_id skipped: $e")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 20. VERB CLASSES + SYNONYMS
# ─────────────────────────────────────────────────────────────────────────────
println("\n📝 Setting up verb classes and synonyms...")

verb_classes = ["action", "emotional", "cognitive", "causal", "similarity", "possessive", "social"]
for cls in verb_classes
    try
        SemanticVerbs.add_relation_class!(cls)
        println("  📝 class: '$cls'")
    catch e
        println("  ⚠️  class '$cls' skipped: $e")
    end
end

verb_assignments = [
    ("burn",     "action"),    ("flow",     "action"),
    ("feel",     "emotional"), ("think",    "cognitive"),
    ("build",    "action"),    ("hunt",     "action"),
    ("gather",   "action"),    ("cause",    "causal"),
    ("produce",  "causal"),    ("create",   "causal"),
    ("resemble", "similarity"),("contain",  "possessive"),
    ("share",    "social"),    ("trust",    "social"),
    ("cooperate","social"),    ("love",     "emotional"),
    ("fear",     "emotional"), ("know",     "cognitive"),
    ("remember", "cognitive"), ("orbit",    "action"),
    ("protect",  "action"),    ("comfort",  "emotional"),
]

for (verb, cls) in verb_assignments
    try
        SemanticVerbs.add_verb!(verb, cls)
        println("  📝 verb: '$verb' → class '$cls'")
    catch e
        println("  ⚠️  verb '$verb' skipped: $e")
    end
end

synonym_pairs = [
    ("burn","ignite"),    ("burn","combust"),    ("flow","stream"),
    ("flow","run"),       ("feel","experience"), ("feel","sense"),
    ("think","ponder"),   ("think","consider"),  ("build","construct"),
    ("build","assemble"), ("hunt","chase"),      ("hunt","track"),
    ("gather","collect"), ("gather","forage"),   ("cause","produce"),
    ("cause","trigger"),  ("create","make"),     ("create","generate"),
    ("share","distribute"),("trust","rely upon"),("fear","dread"),
    ("love","adore"),     ("know","understand"), ("protect","guard"),
    ("comfort","console"),("cooperate","collaborate"),
]

for (canonical, synonym) in synonym_pairs
    try
        SemanticVerbs.add_synonym!(canonical, synonym)
        println("  📝 synonym: '$canonical' ≈ '$synonym'")
    catch e
        println("  ⚠️  synonym '$canonical'≈'$synonym' skipped: $e")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 21. SEED SYNONYMS (Thesaurus)
# ─────────────────────────────────────────────────────────────────────────────
println("\n📇 Adding seed synonyms to Thesaurus...")

seed_syns = [
    ("fire",    ["flame", "blaze", "inferno", "conflagration"]),
    ("water",   ["stream", "river", "lake", "ocean", "rain"]),
    ("food",    ["nourishment", "sustenance", "provisions", "rations"]),
    ("shelter", ["refuge", "haven", "sanctuary", "dwelling"]),
    ("happy",   ["joyful", "glad", "content", "cheerful"]),
    ("sad",     ["unhappy", "sorrowful", "melancholy", "gloomy"]),
    ("big",     ["large", "huge", "vast", "enormous"]),
    ("small",   ["tiny", "little", "minute", "diminutive"]),
    ("friend",  ["companion", "ally", "comrade", "partner"]),
    ("danger",  ["peril", "hazard", "threat", "menace"]),
]

for (canonical, syns) in seed_syns
    try
        Thesaurus.add_seed_synonym!(canonical, syns)
        println("  📇 seed synonyms: '$canonical' → [$(join(syns, ", "))]")
    catch e
        println("  ⚠️  seed synonyms '$canonical' skipped: $e")
    end
end

# ─────────────────────────────────────────────────────────────────────────────
# 22. BUMP KEY STRENGTHS — stratify the population
# ─────────────────────────────────────────────────────────────────────────────
println("\n💪 Bumping key node strengths...")

boost_patterns = [
    "fire burns wood", "water is essential", "gravity pulls objects",
    "past present", "define gravity", "shelter protects from cold",
    "fire is dangerous", "friendship brings joy",
]
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

# ─────────────────────────────────────────────────────────────────────────────
# 23. BUILD SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
println("\n" * "=" ^ 70)

n_nodes = lock(() -> length(NM), NL)
n_groups = lock(() -> length(GM), GL)
n_lobes = length(Lobe.LOBE_REGISTRY)
n_sigils = length(ET.entries)
n_aiml = sum(AIMLNodeSystem.get_population_size(lid) for lid in AIMLNodeSystem.get_registered_lobes())

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
println("  AIML nodes:    $n_aiml")
println("=" ^ 70)

# ═══════════════════════════════════════════════════════════════════════════
# PART 2: CONVERSATION WITH GRUG
# ═══════════════════════════════════════════════════════════════════════════

const CONVO_LOG = "CONVERSATION_LOG_v758.md"
const SPEC_FILE = "comprehensive_specimen_v758.json"

# ─────────────────────────────────────────────────────────────────────────────
# Capture helper — redirect stdout to capture Grug's responses
# ─────────────────────────────────────────────────────────────────────────────
function capture_grug_response(input_text::String)
    old_stdout = stdout
    rd, wr = redirect_stdout()
    try
        process_mission(input_text)
    catch e
        println("⚠️  process_mission error: $e")
    end
    flush(wr)
    redirect_stdout(old_stdout)
    close(wr)
    raw = read(rd, String)
    close(rd)
    return raw
end

# ─────────────────────────────────────────────────────────────────────────────
# Extract the AIML scaffold reply from raw output
# ─────────────────────────────────────────────────────────────────────────────
function extract_grug_reply(raw::String)
    # The engine prints "🤖 AIML Output Scaffold:\n" followed by the reply
    marker = "🤖 AIML Output Scaffold:\n"
    idx = findfirst(marker, raw)
    if isnothing(idx)
        # fallback: look for "AIML Output Scaffold"
        marker2 = "AIML Output Scaffold:\n"
        idx2 = findfirst(marker2, raw)
        if isnothing(idx2)
            return raw  # return everything if no marker found
        end
        start = idx2[end] + 1
    else
        start = idx[end] + 1
    end
    remainder = raw[start:end]
    # The scaffold ends before debug telemetry if present
    tele_marker = "--- DEBUG TELEMETRY"
    tele_idx = findfirst(tele_marker, remainder)
    if !isnothing(tele_idx)
        remainder = remainder[1:tele_idx[1]-1]
    end
    return String(strip(remainder))
end

# ─────────────────────────────────────────────────────────────────────────────
# Clean up Grug's reply for the conversation log — remove debug noise,
# trim excessive whitespace, ensure coherence
# ─────────────────────────────────────────────────────────────────────────────
function clean_grug_reply(reply::AbstractString)
    # Remove lines that are pure debug/telemetry noise
    lines = split(reply, "\n")
    clean_lines = String[]
    for line in lines
        # Skip debug-ish lines
        if occursin(r"^\[DEBUG\]", line) && length(line) > 80
            continue
        end
        if occursin(r"^---\s+(DEBUG|TELEMETRY|FRESH MEMORY)", line)
            continue
        end
        push!(clean_lines, line)
    end
    result = String(strip(join(clean_lines, "\n")))
    # Collapse 3+ consecutive newlines to 2
    result = String(replace(result, r"\n{3,}" => "\n\n"))
    return result
end

# ─────────────────────────────────────────────────────────────────────────────
# Conversation turns — each is (speaker_label, input_text)
# We write natural inputs that test specific features
# ─────────────────────────────────────────────────────────────────────────────
const CONVERSATION = [
    # ── Opening / General knowledge (reason mode) ──
    (1,  "Hey Grug, what do you know about fire?"),
    (2,  "Tell me about water."),
    (3,  "How does gravity work?"),

    # ── Explain mode ──
    (4,  "Why does fire burn, Grug?"),
    (5,  "Why is the sky blue?"),
    (6,  "Why do we feel sad sometimes?"),

    # ── Define mode ──
    (7,  "Define gravity for me."),
    (8,  "What is an atom?"),

    # ── Alert mode ──
    (9,  "Is fire dangerous?"),
    (10, "What about deep water?"),

    # ── Comfort mode ──
    (11, "I feel sad today, Grug."),
    (12, "I'm scared of what's coming."),
    (13, "I feel so lonely."),

    # ── Math mode ──
    (14, "What is 2 plus 2?"),
    (15, "What is 3 times 4?"),
    (16, "What is 10 minus 3?"),

    # ── Time/temporal mode ──
    (17, "What comes before the present?"),
    (18, "Tell me about spring and summer."),

    # ── Relational / sigil tests ──
    (19, "Heat causes evaporation."),
    (20, "Clouds are in the sky."),
    (21, "A tree has branches."),

    # ── Procedure mode ──
    (22, "How do I make fire?"),
    (23, "How do I find water?"),

    # ── Synonym expansion ──
    (24, "Flame combust wood."),        # test: flame→fire, combust→burn
    (25, "Forage for berries."),        # test: forage→gather
    (26, "Construct a shelter."),        # test: construct→build

    # ── Cross-lobe / emotional+survival ──
    (27, "Fire makes me feel warm and safe."),
    (28, "I need shelter from the cold."),

    # ── Custom sigils ──
    (29, "Person feels music."),
    (30, "Spring season."),

    # ── Social lobe ──
    (31, "Friendship brings joy."),
    (32, "Cooperation builds trust."),

    # ── Anti-match detection ──
    (33, "Wrong bad incorrect stuff."),
    (34, "Fake false nonsense."),

    # ── Novel inputs (autogrowth trigger) ──
    (35, "Volcanoes erupt hot lava."),
    (36, "Thunderstorms bring lightning."),
    (37, "Cooking food makes it safe."),

    # ── Follow-up on novel inputs (should find autogrowth nodes) ──
    (38, "Tell me about volcanoes again."),

    # ── Edge cases ──
    (39, "fire"),
    (40, "What is water?"),
    (41, "Define happiness."),
    (42, "I miss someone."),
    (43, "What comes after winter?"),

    # ── Closing ──
    (44, "Thank you Grug, you've been helpful."),
]

# ─────────────────────────────────────────────────────────────────────────────
# Run the conversation and write the MD log
# ─────────────────────────────────────────────────────────────────────────────
println("\n🚀 Running $(length(CONVERSATION)) conversation turns...")

# Open log file and write header
open(CONVO_LOG, "w") do f
    println(f, "# 🗣️ Conversation with GrugBot420 — v7.58")
    println(f, "")
    println(f, "Generated: $(Dates.now())")
    println(f, "")
    println(f, "A multi-turn conversation exercising all GrugBot420 engine features:")
    println(f, "all answer modes, all sigil types, all relation sigils, time nodes,")
    println(f, "procedure chains, anti-match, cross-lobe activation, synonym expansion,")
    println(f, "autogrowth on novel input, AIML executive nodes, and more.")
    println(f, "")
    println(f, "---")
    println(f, "")
    println(f, "## Engine Configuration")
    println(f, "")
    println(f, "- **Nodes**: $n_nodes")
    println(f, "- **Groups**: $n_groups")
    println(f, "- **Lobes**: $n_lobes")
    println(f, "- **Sigils**: $n_sigils")
    println(f, "- **AIML nodes**: $n_aiml")
    println(f, "")
    println(f, "### Lobe Distribution")
    println(f, "")
    println(f, "| Lobe | Nodes | AIML |")
    println(f, "|------|-------|------|")
    for (lid, lobe_data) in sort(collect(Lobe.LOBE_REGISTRY); by=x->x[1])
        n_main = length(lobe_data.node_ids)
        n_aiml_here = AIMLNodeSystem.is_lobe_registered(lid) ? AIMLNodeSystem.get_population_size(lid) : 0
        println(f, "| $lid | $n_main | $n_aiml_here |")
    end
    println(f, "")
    println(f, "---")
    println(f, "")
end

# Track any decoherence issues for post-hoc fixing
decoherence_notes = String[]

for (turn_num, input_text) in CONVERSATION
    println("\n── Turn $turn_num/$(length(CONVERSATION)) ──")
    println("   Input: \"$input_text\"")

    before_nodes = lock(() -> length(NM), NL)

    # Capture Grug's response
    raw_output = capture_grug_response(input_text)
    grug_reply = extract_grug_reply(raw_output)
    cleaned_reply = clean_grug_reply(grug_reply)

    after_nodes = lock(() -> length(NM), NL)
    new_nodes = after_nodes - before_nodes

    # Check for decoherence
    is_coherent = true
    coherence_note = ""

    # Empty reply check
    if length(cleaned_reply) < 5
        is_coherent = false
        coherence_note = "Empty or near-empty reply from Grug"
    end

    # Repetition check (same phrase repeated 3+ times)
    if is_coherent
        words = split(lowercase(cleaned_reply))
        if length(words) > 10
            for i in 1:(length(words)-6)
                trigram = join(words[i:i+2], " ")
                count = 0
                for j in 1:(length(words)-2)
                    if join(words[j:j+2], " ") == trigram
                        count += 1
                    end
                end
                if count >= 4
                    is_coherent = false
                    coherence_note = "Excessive repetition detected: '$trigram' appears $count times"
                    break
                end
            end
        end
    end

    # Garbled check (too many non-word characters)
    if is_coherent && length(cleaned_reply) > 20
        non_word = length(collect(eachmatch(r"[^a-zA-Z0-9\s'.,!?;:\-\(\)]", cleaned_reply)))
        if non_word > length(cleaned_reply) * 0.15
            is_coherent = false
            coherence_note = "Garbled output: too many non-word characters ($non_word / $(length(cleaned_reply)))"
        end
    end

    if !is_coherent
        push!(decoherence_notes, "Turn $turn_num: \"$input_text\" → $coherence_note")
    end

    # Truncate very long replies for the log
    display_reply = cleaned_reply
    if length(display_reply) > 1500
        safe_end = prevind(display_reply, min(ncodeunits(display_reply)+1, 1501))
        display_reply = String(display_reply[1:safe_end]) * "\n\n*[reply truncated for log]*"
    end

    # Write to conversation log
    open(CONVO_LOG, "a") do f
        println(f, "### Turn $turn_num")
        println(f, "")
        println(f, "**You**: $input_text")
        println(f, "")
        println(f, "**Grug**: $display_reply")
        if new_nodes > 0
            println(f, "")
            println(f, "*[🌱 +$new_nodes new node(s) created — autogrowth]*")
        end
        if !is_coherent
            println(f, "")
            println(f, "*[⚠️ DECOHERENCE NOTE: $coherence_note]*")
        end
        println(f, "")
        println(f, "---")
        println(f, "")
    end

    println("   ✅ Logged (nodes: $before_nodes→$after_nodes$(new_nodes > 0 ? ", +$new_nodes 🌱" : ""))$(is_coherent ? "" : " ⚠️ DECOHERENCE")")
end

# ─────────────────────────────────────────────────────────────────────────────
# Post-conversation: Fix any decoherence in the MD log
# ─────────────────────────────────────────────────────────────────────────────
if !isempty(decoherence_notes)
    println("\n⚠️  Decoherence detected in $(length(decoherence_notes)) turn(s):")
    for note in decoherence_notes
        println("   - $note")
    end
    println("\n🔧 Fixing decoherence in conversation log...")

    # Read the full log and patch decoherent sections
    log_content = read(CONVO_LOG, String)

    for note in decoherence_notes
        # Parse turn number from note
        m = match(r"Turn (\d+)", note)
        if !isnothing(m)
            turn_str = "### Turn $(m.captures[1])"
            # Find the decoherent section and add a coherence fix note
            marker = "*[⚠️ DECOHERENCE NOTE:"
            if occursin(marker, log_content)
                # Add a coherence fix annotation
                log_content = replace(log_content, marker => "*[🔧 COHERENCE FIX: This response was flagged as decoherent. The engine may need tuning for this input pattern. Original issue noted below.]*\n*[⚠️ DECOHERENCE NOTE:")
            end
        end
    end

    write(CONVO_LOG, log_content)
    println("   ✅ Decoherence annotations added")
else
    println("\n✅ No decoherence detected — all responses coherent!")
end

# ─────────────────────────────────────────────────────────────────────────────
# Write final summary section to the conversation log
# ─────────────────────────────────────────────────────────────────────────────
final_nodes = lock(() -> length(NM), NL)
final_groups = lock(() -> length(GM), GL)

open(CONVO_LOG, "a") do f
    println(f, "## Session Summary")
    println(f, "")
    println(f, "- **Total turns**: $(length(CONVERSATION))")
    println(f, "- **Initial nodes**: $n_nodes")
    println(f, "- **Final nodes**: $final_nodes (+$(final_nodes - n_nodes) from autogrowth)")
    println(f, "- **Final groups**: $final_groups")
    println(f, "- **Decoherence events**: $(length(decoherence_notes))")
    println(f, "")

    # Time-node isolation check
    time_groups = Ref(0)
    regular_groups = Ref(0)
    mixed_groups = Ref(0)
    lock(GL) do
        for (gid, grp) in GM
            if grp.is_time_node_group
                all_time = true
                for mid in grp.members
                    n = lock(() -> get(NM, mid, nothing), NL)
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
    println(f, "- Regular groups: $(regular_groups[])")
    println(f, "- Time-node groups: $(time_groups[])")
    println(f, "- Mixed groups (VIOLATION): $(mixed_groups[])")
    if mixed_groups[] == 0
        println(f, "- ✅ All time-node groups properly isolated")
    else
        println(f, "- ❌ TIME-NODE ISOLATION VIOLATED")
    end
    println(f, "")

    # Final lobe distribution
    println(f, "### Final Lobe Distribution")
    println(f, "")
    println(f, "| Lobe | Nodes | AIML |")
    println(f, "|------|-------|------|")
    for (lid, lobe_data) in sort(collect(Lobe.LOBE_REGISTRY); by=x->x[1])
        n_main = length(lobe_data.node_ids)
        n_aiml_here = AIMLNodeSystem.is_lobe_registered(lid) ? AIMLNodeSystem.get_population_size(lid) : 0
        println(f, "| $lid | $n_main | $n_aiml_here |")
    end
    println(f, "")

    # Top 10 strongest nodes
    println(f, "### Top 10 Strongest Nodes")
    println(f, "")
    println(f, "| Node | Pattern | Strength |")
    println(f, "|------|---------|----------|")
    all_nodes = lock(NL) do
        [(id, n.pattern, n.strength) for (id, n) in NM]
    end
    sorted = sort(all_nodes; by=x->x[3], rev=true)
    for (id, pat, str) in sorted[1:min(10, length(sorted))]
        pat_short = length(pat) > 50 ? pat[1:47] * "..." : pat
        println(f, "| $id | $pat_short | $(round(str; digits=2)) |")
    end
    println(f, "")

    # Sigil inventory
    println(f, "### Sigil Inventory")
    println(f, "")
    for (name, entry) in sort(collect(ET.entries); by=p->p.first)
        lex_str = isnothing(entry.lexicon) ? "" : " [lexicon: $(join(entry.lexicon, ","))]"
        exp_str = isnothing(entry.expansion) ? "" : " [expansion: $(join(entry.expansion, ","))]"
        println(f, "- &$name — class=$(entry.class), applies_at=$(entry.applies_at)$(lex_str)$(exp_str)")
    end
    println(f, "")
end

# ─────────────────────────────────────────────────────────────────────────────
# Save the specimen
# ─────────────────────────────────────────────────────────────────────────────
println("\n💾 Saving specimen...")
save_specimen_to_file!(SPEC_FILE)
println("✅ Saved to $SPEC_FILE")

println("\n" * "=" ^ 70)
println("  FULL SPECIMEN + CONVERSATION COMPLETE")
println("=" ^ 70)
println("  📄 Conversation log: $CONVO_LOG")
println("  💾 Specimen file:   $SPEC_FILE")
println("  📊 Final state:     $final_nodes nodes, $final_groups groups")
println("  🌱 Autogrowth:      +$(final_nodes - n_nodes) new nodes")
println("  ⚠️  Decoherence:     $(length(decoherence_notes)) events")
println("=" ^ 70)
