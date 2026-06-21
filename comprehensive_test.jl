#!/usr/bin/env julia --project=.
# ═══════════════════════════════════════════════════════════════════════════════
# GrugBot420 Comprehensive Coherence Test Harness
# Uses _LAST_VOICE_OUTPUT / _LAST_VOICE_OUTPUT_LOCK for response capture
# Tests: regular questions, math, multipart, /answer mechanic
# ═══════════════════════════════════════════════════════════════════════════════

using Pkg; Pkg.instantiate()
using Dates
using JSON

include("src/GrugBot420.jl")
using .GrugBot420

import .GrugBot420:
    process_mission, load_specimen_from_file!, save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _create_answer_node, _base_answer_data,
    _HIPPOCAMPAL_PENDING_ASK, _HIPPOCAMPAL_PENDING_ASK_LOCK,
    EphemeralMLP

const SPEC_PATH = joinpath(@__DIR__, "grug_comprehensive_full.specimen")
const LOG_PATH  = joinpath(@__DIR__, "grug_comprehensive_test_log.md")
const SAVE_PATH = joinpath(@__DIR__, "grug_comprehensive_full_post_test.specimen")

# ──── Response capture via internals ────
read_last() = lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[]; end

function ask_grug(text::String)::String
    lock(_LAST_VOICE_OUTPUT_LOCK) do; _LAST_VOICE_OUTPUT[] = ""; end
    try; process_mission(text); catch e; @warn "process_mission error: $e"; end
    r = read_last()
    # Strip DEBUG TELEMETRY section if present
    ti = findfirst("--- DEBUG TELEMETRY", r)
    if ti !== nothing; r = r[1:first(ti)-1]; end
    return strip(replace(r, r"\n{3,}" => "\n\n"))
end

# ──── Disable chatter for clean testing ────
ENV["GRUG_CHATTER_ENABLED"] = "false"

println("=" ^ 60)
println("  GRUGBOT420 COMPREHENSIVE COHERENCE TEST")
println("  Specimen: grug_comprehensive_full.specimen")
println("=" ^ 60)

# ──── Load specimen ────
println("\n📦 Loading specimen...")
load_specimen_from_file!(SPEC_PATH)
println("✅ Loaded. Starting tests...\n")

# ═══════════════════════════════════════════════════════════════════════════════
# TEST QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

struct TestQ; cat::String; q::String; end

tests = TestQ[
    # ── Greeting ──
    TestQ("greeting", "hello"),
    TestQ("greeting", "hey grug"),
    TestQ("greeting", "good morning"),

    # ── Regular knowledge (nodes exist for these) ──
    TestQ("knowledge", "what is fire"),
    TestQ("knowledge", "what is water"),
    TestQ("knowledge", "what is earth"),
    TestQ("knowledge", "what is sky"),
    TestQ("knowledge", "what is love"),
    TestQ("knowledge", "what is fear"),
    TestQ("knowledge", "what is courage"),
    TestQ("knowledge", "what is river"),
    TestQ("knowledge", "what is forest"),
    TestQ("knowledge", "what is gravity"),
    TestQ("knowledge", "what is algebra"),
    TestQ("knowledge", "what is calculus"),
    TestQ("knowledge", "why does fire burn"),
    TestQ("knowledge", "how does water flow"),

    # ── Math ──
    TestQ("math", "what is 2 plus 2"),
    TestQ("math", "what is 3 times 4"),
    TestQ("math", "what is 7 plus 8"),
    TestQ("math", "what is 9 minus 3"),
    TestQ("math", "what is 10 divided by 2"),

    # ── Multipart ──
    TestQ("multipart", "what is fire and what is water"),
    TestQ("multipart", "why does fire burn and why does water flow"),
    TestQ("multipart", "what is love and what is courage"),

    # ── Philosophy / Emotion / Metacognition ──
    TestQ("philosophy", "what is consciousness"),
    TestQ("philosophy", "what is truth"),
    TestQ("philosophy", "what is ethics"),
    TestQ("emotion", "i feel sad"),
    TestQ("emotion", "i am afraid"),
    TestQ("metacognition", "how do you think"),
    TestQ("metacognition", "who are you"),

    # ── Science / Technology ──
    TestQ("science", "what is physics"),
    TestQ("science", "what is chemistry"),
    TestQ("science", "what is biology"),
    TestQ("technology", "what is programming"),
    TestQ("technology", "what is the internet"),

    # ── History / Language ──
    TestQ("history", "what is civilization"),
    TestQ("history", "what is revolution"),
    TestQ("language", "what is poetry"),
    TestQ("language", "what is grammar"),
]

# ═══════════════════════════════════════════════════════════════════════════════
# RUN MAIN QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

log = String[]
ts = Dates.format(Dates.now(), "yyyy-mm-dd HH:MM:SS")
push!(log, "# GrugBot420 Comprehensive Coherence Test Log\n\n")
push!(log, "**Date:** $(ts)\n\n")
push!(log, "**Specimen:** grug_comprehensive_full.specimen (276 nodes, 10 lobes)\n\n")
push!(log, "**Chatter:** DISABLED\n\n")
push!(log, "**Capture method:** _LAST_VOICE_OUTPUT / _LAST_VOICE_OUTPUT_LOCK (application internals)\n\n")
push!(log, "---\n\n")

results = Dict{String, String}()

for (i, t) in enumerate(tests)
    r = ask_grug(t.q)
    results[t.q] = r
    push!(log, "## Turn $i — $(t.cat)\n\n")
    push!(log, "**User:** $(t.q)\n\n")
    push!(log, "> $(replace(r, "\n" => "  \n> "))\n\n")
    push!(log, "---\n\n")
    short = length(r) > 120 ? r[1:117] * "..." : r
    println("[$i/$(length(tests))] [$(t.cat)] Q: $(t.q)\n  A: $(short)\n")
end

# ═══════════════════════════════════════════════════════════════════════════════
# /answer MECHANIC TEST (Hippocampal ask → /answer → recall cycle)
# ═══════════════════════════════════════════════════════════════════════════════

push!(log, "\n# /answer Mechanic Test (Hippocampal Ask → Teach → Recall)\n\n---\n\n")

# --- :explain mode ---
q1 = "what is a stromatolite"
r_ask1 = ask_grug(q1)
push!(log, "## /answer Step 1: Ask Unknown (explain mode)\n\n")
push!(log, "**User:** $(q1)\n\n> $(replace(r_ask1, "\n" => "  \n> "))\n\n")
is_ask1 = occursin("/answer", r_ask1) || occursin("teach me", lowercase(r_ask1)) || occursin("Nothing in the cave", r_ask1) || occursin("not know", lowercase(r_ask1))
push!(log, "**Verdict:** $(is_ask1 ? "✅ ASK generated" : "❌ NO ask detected")\n\n---\n\n")
println("[/answer explain] Step 1: → $(is_ask1 ? "ASK ✅" : "NO ASK ❌")")

# Teach via :explain
lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = q1; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

ad1 = _base_answer_data("explain"; pending_ask_text=q1, answer_content="stromatolites are layered rock structures formed by cyanobacteria in shallow water. They are among the oldest evidence of life on earth dating back 3.5 billion years.")
ad1["noun_anchors"] = ["stromatolite", "cyanobacteria", "fossil"]
nid1, lt1 = _create_answer_node("stromatolite", "explain^1", ad1, "science")
push!(log, "## /answer Step 2: Teach (explain mode)\n\n")
push!(log, "**Cmd:** /answer @science :explain stromatolites are layered rock structures formed by cyanobacteria\n\n")
push!(log, "**Node created:** $(nid1) in lobe $(lt1)\n\n---\n\n")
println("[/answer explain] Step 2: node $(nid1) in lobe $(lt1)")

# Re-ask to test recall
r_recall1 = ask_grug(q1)
push!(log, "## /answer Step 3: Recall (explain mode)\n\n")
push!(log, "**User:** $(q1)\n\n> $(replace(r_recall1, "\n" => "  \n> "))\n\n")
rc1 = !occursin("Nothing in the cave", r_recall1) && !occursin("teach me", lowercase(r_recall1))
mt1 = occursin("stromatolite", lowercase(r_recall1)) || occursin("cyanobacteria", lowercase(r_recall1)) || occursin("layered", lowercase(r_recall1))
push!(log, "**Verdict:** $(rc1 ? "✅" : "❌") $(mt1 ? "(topic content mentioned ✅)" : "(topic content NOT mentioned ❌)")\n\n---\n\n")
println("[/answer explain] Step 3: → $(rc1 ? "RECALLED ✅" : "FAILED ❌") topic: $(mt1 ? "YES" : "NO")")

# --- :math mode ---
q2 = "what is the factorial of 6"
r_ask2 = ask_grug(q2)
push!(log, "## /answer Step 1: Ask Unknown (math mode)\n\n")
push!(log, "**User:** $(q2)\n\n> $(replace(r_ask2, "\n" => "  \n> "))\n\n")
is_ask2 = occursin("/answer", r_ask2) || occursin("teach me", lowercase(r_ask2)) || occursin("Nothing in the cave", r_ask2) || occursin("not know", lowercase(r_ask2))
push!(log, "**Verdict:** $(is_ask2 ? "✅ ASK generated" : "❌ NO ask detected")\n\n---\n\n")
println("[/answer math] Step 1: → $(is_ask2 ? "ASK ✅" : "NO ASK ❌")")

lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = q2; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

ad2 = _base_answer_data("math"; pending_ask_text=q2, answer_content="the factorial of 6 is 720. 6 times 5 times 4 times 3 times 2 times 1 equals 720")
ad2["noun_anchors"] = ["factorial", "6", "720"]
nid2, lt2 = _create_answer_node("factorial of 6", "reason^1", ad2, "mathematics")
push!(log, "## /answer Step 2: Teach (math mode)\n\n")
push!(log, "**Cmd:** /answer @mathematics :math the factorial of 6 is 720\n\n")
push!(log, "**Node created:** $(nid2) in lobe $(lt2)\n\n---\n\n")
println("[/answer math] Step 2: node $(nid2) in lobe $(lt2)")

r_recall2 = ask_grug(q2)
push!(log, "## /answer Step 3: Recall (math mode)\n\n")
push!(log, "**User:** $(q2)\n\n> $(replace(r_recall2, "\n" => "  \n> "))\n\n")
rc2 = !occursin("Nothing in the cave", r_recall2) && !occursin("teach me", lowercase(r_recall2))
mt2 = occursin("factorial", lowercase(r_recall2)) || occursin("720", r_recall2) || occursin("720", r_recall2)
push!(log, "**Verdict:** $(rc2 ? "✅" : "❌") $(mt2 ? "(math content mentioned ✅)" : "(math content NOT mentioned ❌)")\n\n---\n\n")
println("[/answer math] Step 3: → $(rc2 ? "RECALLED ✅" : "FAILED ❌") topic: $(mt2 ? "YES" : "NO")")

# --- :reason mode ---
q3 = "what is a quasar"
r_ask3 = ask_grug(q3)
push!(log, "## /answer Step 1: Ask Unknown (reason mode)\n\n")
push!(log, "**User:** $(q3)\n\n> $(replace(r_ask3, "\n" => "  \n> "))\n\n")
is_ask3 = occursin("/answer", r_ask3) || occursin("teach me", lowercase(r_ask3)) || occursin("Nothing in the cave", r_ask3) || occursin("not know", lowercase(r_ask3))
push!(log, "**Verdict:** $(is_ask3 ? "✅ ASK generated" : "❌ NO ask detected")\n\n---\n\n")
println("[/answer reason] Step 1: → $(is_ask3 ? "ASK ✅" : "NO ASK ❌")")

lock(_HIPPOCAMPAL_PENDING_ASK_LOCK) do; _HIPPOCAMPAL_PENDING_ASK[] = q3; end
try; EphemeralMLP.dampen_strain!(0.7); catch; end

ad3 = _base_answer_data("reason"; pending_ask_text=q3, answer_content="quasars are extremely luminous active galactic nuclei powered by supermassive black holes. They are among the brightest objects in the universe.")
ad3["noun_anchors"] = ["quasar", "black_hole", "luminous"]
nid3, lt3 = _create_answer_node("quasar", "reason^1", ad3, "science")
push!(log, "## /answer Step 2: Teach (reason mode)\n\n")
push!(log, "**Cmd:** /answer @science :reason quasars are extremely luminous active galactic nuclei powered by supermassive black holes\n\n")
push!(log, "**Node created:** $(nid3) in lobe $(lt3)\n\n---\n\n")
println("[/answer reason] Step 2: node $(nid3) in lobe $(lt3)")

r_recall3 = ask_grug(q3)
push!(log, "## /answer Step 3: Recall (reason mode)\n\n")
push!(log, "**User:** $(q3)\n\n> $(replace(r_recall3, "\n" => "  \n> "))\n\n")
rc3 = !occursin("Nothing in the cave", r_recall3) && !occursin("teach me", lowercase(r_recall3))
mt3 = occursin("quasar", lowercase(r_recall3)) || occursin("black hole", lowercase(r_recall3)) || occursin("luminous", lowercase(r_recall3))
push!(log, "**Verdict:** $(rc3 ? "✅" : "❌") $(mt3 ? "(content mentioned ✅)" : "(content NOT mentioned ❌)")\n\n---\n\n")
println("[/answer reason] Step 3: → $(rc3 ? "RECALLED ✅" : "FAILED ❌") topic: $(mt3 ? "YES" : "NO")")

# ═══════════════════════════════════════════════════════════════════════════════
# SAVE POST-TEST SPECIMEN
# ═══════════════════════════════════════════════════════════════════════════════

println("\n💾 Saving post-test specimen...")
try; save_specimen_to_file!(SAVE_PATH); catch e; @warn "save failed: $e"; end
println("Saved to $(SAVE_PATH)")

# ═══════════════════════════════════════════════════════════════════════════════
# WRITE LOG FILE
# ═══════════════════════════════════════════════════════════════════════════════

open(LOG_PATH, "w") do f; print(f, join(log, "")); end
println("\n✅ Log → $(LOG_PATH)")

println("\n", "=" ^ 60)
println("  ALL TESTS COMPLETE")
println("=" ^ 60)
