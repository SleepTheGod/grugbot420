# ============================================================
# GrugBot420 — v3 Specimen Interaction Harness
# Loads the comprehensive v3 specimen, runs missions across ALL
# 12 subject lobes, captures input -> response + telemetry, and
# writes a Markdown interaction log. Verifies NO decoherence by
# checking that responses are varied and confidences are healthy.
# ============================================================
ENV["GRUG_NO_AUTOLOAD"] = "1"
include("src/Main.jl")

const SPEC = joinpath(@__DIR__, "specimens", "comprehensive_v3_specimen.json")
println("Loading specimen: $SPEC")
load_specimen_from_file!(SPEC)

# Suppress the engine's verbose stdout during dispatch so the harness
# output stays clean. We capture the REAL speech from _LAST_AIML_OUTPUT.
function run_mission(text::String)
    resp = ""; node = ""; action = ""; conf = 0.0
    # Reset capture refs
    lock(_LAST_AIML_OUTPUT_LOCK) do
        _LAST_AIML_OUTPUT[] = ""
        _LAST_FIRED_NODE[] = ""
        _LAST_PRIMARY_ACTION[] = ""
        _LAST_CONFIDENCE[] = 0.0
    end
    # Dispatch (silence stdout)
    orig = stdout
    (rd, wr) = redirect_stdout()
    try
        process_mission(text)
    catch e
        redirect_stdout(orig); close(wr)
        return (text, "[ERROR: $e]", "", "", 0.0)
    end
    redirect_stdout(orig)
    close(wr)
    close(rd)
    lock(_LAST_AIML_OUTPUT_LOCK) do
        resp   = _LAST_AIML_OUTPUT[]
        node   = _LAST_FIRED_NODE[]
        action = _LAST_PRIMARY_ACTION[]
        conf   = _LAST_CONFIDENCE[]
    end
    return (text, resp, node, action, conf)
end

# Missions organized by subject lobe — matched to natural-language patterns.
missions = [
    ("MATHEMATICS", [
        "what is addition", "how do i add numbers", "what is subtraction",
        "what is multiplication", "what is division", "what is a fraction",
        "what is geometry", "what is nothingness", "count to ten for me",
        "how do i solve an equation",
    ]),
    ("SCIENCE", [
        "what is gravity", "what is energy", "what is an atom", "what is heat",
        "why does the sky look blue", "how does sound travel",
        "what is electricity", "what are the planets",
    ]),
    ("BIOLOGY", [
        "what is a cell", "what is dna", "how do plants make food",
        "what is the brain", "why do we need blood", "what is evolution",
        "what is a species",
    ]),
    ("PHILOSOPHY", [
        "do we have free will", "what is consciousness", "what is truth",
        "what is good and evil", "what is the meaning of life",
        "what happens when we die", "what is the unknowable void",
    ]),
    ("SURVIVAL", [
        "there is danger nearby", "should i fight or flee", "how do i find shelter",
        "how do i make fire", "i feel calm and peaceful",
        "a predator is hunting me", "what do i do in an emergency",
    ]),
    ("EMPATHY", [
        "i am feeling very sad", "i feel joyful", "i feel scared and afraid",
        "i am angry and frustrated", "show me compassion", "how do i comfort someone",
    ]),
    ("CREATIVITY", [
        "write me a poem", "tell me a story", "how do i make music",
        "describe a beautiful painting", "i want to create something",
        "what if i could imagine anything",
    ]),
    ("SOCIAL", [
        "hello grug", "you are my friend", "how do i make friends",
        "can i trust you", "i need help with something", "lets work together",
    ]),
    ("TEMPORAL", [
        "tell me about the past", "what is happening right now",
        "what does the future hold", "how do things change over time",
    ]),
    ("NATURE", [
        "describe the ocean", "tell me about the forest",
        "what makes the weather", "why do rivers flow",
    ]),
    ("TECHNOLOGY", [
        "what is a tool", "how do computers work", "what is a robot",
        "what is the internet", "how do i write code",
    ]),
    ("FOOD", [
        "what should i eat", "i am very hungry", "how do i find clean water",
        "what fruit is safe to eat", "how do i cook meat",
    ]),
    ("SPECIAL NODES", [
        "what do i do in an emergency", "what is the unknowable void",
        "can i join the gathering of friends",
    ]),
]

# Image-type nodes live on the engine's IMAGE scan path (they respond to image
# binary input, not text), so they are intentionally NOT queried as text here.
# They are persisted in the specimen as a node-type feature (is_image_node=true):
#   - lobe_nature: "what is a mountain", "what is a sunset" (SDF image nodes)
#   - lobe_nature: "show me a picture of a sunset over water" (SDF params node)
const IMAGE_NODE_PATTERNS = [
    "what is a mountain", "what is a sunset", "show me a picture of a sunset over water",
]
# Grave (memorial) node: persisted with is_grave=true so it never fires — it is a
# dead/preserved node demonstrating the grave node-type feature.
const GRAVE_NODE_PATTERNS = ["what happened to extinct animals"]

# ---- Run all missions ----
results = []  # (subject, input, resp, node, action, conf)
for (subject, ms) in missions
    for m in ms
        (inp, resp, node, action, conf) = run_mission(m)
        push!(results, (subject, inp, resp, node, action, conf))
        println("[$subject] $inp  ->  node=$node conf=$(round(conf,digits=3))")
    end
end

# ---- Decoherence analysis ----
responses = [r[3] for r in results]
unique_resp = unique(responses)
n_total = length(results)
n_unique = length(unique_resp)
confs = [r[6] for r in results]
n_healthy = count(c -> c >= 0.30, confs)
n_fired = count(r -> !isempty(r[4]), results)  # node fired (not empty-cave)
avg_conf = isempty(confs) ? 0.0 : sum(confs)/length(confs)

# detect generic fallback repetition
fallback_markers = ["think about math, philosophy, nature"]
n_fallback = count(r -> any(occursin(fm, lowercase(r[3])) for fm in fallback_markers), results)

println("\n" * "="^60)
println("DECOHERENCE ANALYSIS")
println("="^60)
println("Total missions      : $n_total")
println("Unique responses    : $n_unique  ($(round(100*n_unique/n_total,digits=1))%)")
println("Nodes fired         : $n_fired")
println("Healthy conf (>=0.3): $n_healthy")
println("Avg confidence      : $(round(avg_conf,digits=3))")
println("Generic fallbacks   : $n_fallback")

# ---- Telemetry snapshot ----
n_lobes  = length(Lobe.LOBE_REGISTRY)
n_nodes  = lock(NODE_LOCK) do; length(NODE_MAP); end
n_sigils = try; length(SigilRegistry.list_sigils(_ENGINE_SIGIL_TABLE)); catch; -1; end
n_thes   = try; Thesaurus.seed_synonym_count(); catch; -1; end
n_mlp    = try; length(EphemeralMLP.list_mlp_rules()); catch; -1; end
arousal  = try; EyeSystem.get_arousal(); catch; -1.0; end
jitter_on = try; RelationalJitter.is_jitter_enabled(); catch; false; end
jitter_r  = try; RelationalJitter.get_jitter_ratio(); catch; -1.0; end
cf_snap   = try; CoherenceField.coherence_config_snapshot(); catch; nothing; end
cf_weight = cf_snap === nothing ? -1.0 : cf_snap.weight

# ---- Write Markdown log ----
io = open(joinpath(@__DIR__, "interaction_results_v3.md"), "w")
println(io, "# GrugBot420 — Comprehensive v3 Specimen Interaction Log\n")
println(io, "Generated by `interact_v3.jl` against `comprehensive_v3_specimen.json`.\n")
println(io, "## Engine & specimen telemetry\n")
println(io, "| Metric | Value |")
println(io, "|---|---|")
println(io, "| Lobes | $n_lobes |")
println(io, "| Nodes | $n_nodes |")
println(io, "| Custom sigils (table) | $n_sigils |")
println(io, "| Thesaurus seed words | $n_thes |")
println(io, "| EphemeralMLP rules | $n_mlp |")
println(io, "| Arousal | $(round(arousal,digits=3)) |")
println(io, "| RelationalJitter enabled | $jitter_on (ratio=$(round(jitter_r,digits=3))) |")
println(io, "| CoherenceField weight | $(round(cf_weight,digits=3)) |")
println(io, "")
println(io, "## Decoherence verdict\n")
verdict = (n_fallback == 0 && n_unique >= Int(round(0.8*n_total)) && avg_conf >= 0.3) ? "✅ NO DECOHERENCE" : "⚠️ CHECK"
println(io, "$verdict\n")
println(io, "| Metric | Value |")
println(io, "|---|---|")
println(io, "| Total missions | $n_total |")
println(io, "| Unique responses | $n_unique ($(round(100*n_unique/n_total,digits=1))%) |")
println(io, "| Nodes fired | $n_fired |")
println(io, "| Healthy confidence (>=0.30) | $n_healthy |")
println(io, "| Average confidence | $(round(avg_conf,digits=3)) |")
println(io, "| Generic fallback responses | $n_fallback |")
println(io, "")
println(io, "## Interaction Transcript\n")
println(io, "Note on image nodes: the specimen contains `is_image_node=true` nodes ")
println(io, "(`what is a mountain`, `what is a sunset`, `show me a picture of a sunset over water`). ")
println(io, "These respond to image input rather than text, so they are persisted as a node-type ")
println(io, "feature but not queried here. The grave node `what happened to extinct animals` is ")
println(io, "persisted with `is_grave=true` and never fires by design, so it is also not queried.\n")

# Strip the engine's verbose DEBUG TELEMETRY block from the spoken response so
# the transcript reads like plain conversation. The real telemetry (node,
# action, confidence) is already captured separately and shown on one line.
function clean_speech(s::String)
    idx = findfirst("--- DEBUG TELEMETRY", s)
    body = idx === nothing ? s : s[1:first(idx)-1]
    # collapse any leftover orchestration transition prefixes is unnecessary;
    # just trim whitespace and stray newlines.
    return strip(replace(body, r"\n+" => " "))
end

let cur = ""
    for (subject, inp, resp, node, action, conf) in results
        if subject != cur
            println(io, "\n### $subject\n")
            cur = subject
        end
        speech = clean_speech(resp)
        println(io, "**$inp**  ")
        println(io, "_node $node · action $action · confidence $(round(conf,digits=3))_\n")
        println(io, "Grug: $speech\n")
    end
end
close(io)

println("\n✅ Wrote interaction_results_v3.md ($n_total missions)")
println("Decoherence verdict: $verdict")
