#!/usr/bin/env julia
# ============================================================================
# GRUG v7.27: Comprehensive Test Session — Phase Crystal + All Levers
# ============================================================================
# Loads specimen, runs diverse interactions, tests every lever system,
# captures REAL output (not fabricated analysis), and writes a markdown log.
# ============================================================================

using Pkg
Pkg.activate(@__DIR__)

include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

using Dates

# ============================================================================
# LOGGING SETUP
# ============================================================================
const LOG_FILE = "test_session_v727_log.md"
const LOG_ENTRIES = String[]

function log_header!()
    push!(LOG_ENTRIES, "# GrugBot v7.27 Comprehensive Test Session\n")
    push!(LOG_ENTRIES, "**Date:** $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))  ")
    push!(LOG_ENTRIES, "**Specimen:** specimens/comprehensive_v727_test.specimen.json  ")
    push!(LOG_ENTRIES, "**Purpose:** Test all lever systems including Phase Crystal (time crystal), ATP escalation, MLP learning, and cross-system integration\n")
    push!(LOG_ENTRIES, "\n---\n\n")
end

function log_section!(title::String)
    push!(LOG_ENTRIES, "\n## $title\n\n")
end

function log_entry!(entry::String)
    push!(LOG_ENTRIES, entry * "\n")
end

function log_command!(cmd::String, output::String)
    push!(LOG_ENTRIES, "### Input\n```\n$cmd\n```\n\n")
    push!(LOG_ENTRIES, "### Output\n```\n$(rstrip(output))\n```\n\n")
end

function write_log!()
    write(LOG_FILE, join(LOG_ENTRIES))
    println("\n✓ Log written to $LOG_FILE")
end

# ============================================================================
# CAPTURE STDOUT FROM A FUNCTION CALL
# ============================================================================
function capture_output(f::Function)
    buf = IOBuffer()
    original_stdout = stdout
    redirect_stdout(buf)
    try
        f()
    catch e
        println(buf, "ERROR: $e")
    finally
        redirect_stdout(original_stdout)
    end
    return String(take!(buf))
end

# ============================================================================
# RUN A CLI COMMAND AND CAPTURE ITS OUTPUT
# ============================================================================
function run_cli_command(cmd::String)
    # Many CLI commands are handled inside the run_cli() REPL loop.
    # process_mission is accessible directly. For CLI commands we need
    # to call the underlying functions directly.
    buf = IOBuffer()
    original_stdout = stdout
    redirect_stdout(buf)
    try
        if startswith(cmd, "/mission ")
            mission_text = cmd[length("/mission ")+1:end]
            GrugBot420.process_mission(mission_text)
        elseif startswith(cmd, "/automaton phase")
            handle_automaton_phase(cmd)
        elseif cmd == "/mlpStatus"
            handle_mlp_status()
        elseif cmd == "/mlpObserver"
            handle_mlp_observer()
        elseif cmd == "/status"
            handle_status()
        elseif cmd == "/nodes"
            handle_nodes()
        elseif cmd == "/lobes"
            handle_lobes()
        elseif cmd == "/right"
            handle_right()
        elseif cmd == "/wrong"
            handle_wrong()
        elseif startswith(cmd, "/arousal ")
            val = parse(Float64, cmd[length("/arousal ")+1:end])
            GrugBot420.EyeSystem.set_arousal!(val)
            println("Arousal set to $val")
        elseif startswith(cmd, "/saveSpecimen ")
            path = cmd[length("/saveSpecimen ")+1:end]
            GrugBot420.save_specimen_to_file!(path)
        else
            println("Unknown command: $cmd")
        end
    catch e
        println(buf, "ERROR in $cmd: $e")
        for (exc, bt) in current_exceptions()
            showerror(buf, exc, bt)
        end
    finally
        redirect_stdout(original_stdout)
    end
    return String(take!(buf))
end

# --- Handler wrappers for CLI commands ---

function handle_automaton_phase(cmd::String)
    if occursin("threshold", cmd)
        m = match(r"threshold\s+([0-9.]+)", cmd)
        if m !== nothing
            val = parse(Float64, String(m.captures[1]))
            GrugBot420.EphemeralAutomaton.set_phase_pull_threshold!(val)
            println("💎 Phase pull threshold set to $val")
        end
    elseif occursin("surface", cmd)
        m = match(r"surface\s+(\d+)", cmd)
        if m !== nothing
            val = parse(Int, String(m.captures[1]))
            GrugBot420.EphemeralAutomaton.set_phase_surface_count!(val)
            println("💎 Phase surface count set to $val")
        end
    elseif occursin("enable", cmd)
        GrugBot420.EphemeralAutomaton.set_phase_enabled!(true)
        println("💎 Phase pull ENABLED")
    elseif occursin("disable", cmd)
        GrugBot420.EphemeralAutomaton.set_phase_enabled!(false)
        println("💎 Phase pull DISABLED")
    elseif occursin("reset", cmd)
        GrugBot420.EphemeralAutomaton.reset_phase_accumulator!()
        println("💎 Phase accumulator RESET (all snapshots cleared)")
    else
        # status
        println(GrugBot420.EphemeralAutomaton.phase_pull_status_string())
    end
end

function handle_mlp_status()
    status = GrugBot420.EphemeralMLP.mlp_status_string()
    println(status)
end

function handle_mlp_observer()
    println(GrugBot420.SelfObserver.audit_trail(GrugBot420._MLP_OBSERVER_STORE[]))
end

function handle_status()
    # Simplified status
    n_nodes = length(GrugBot420.NODE_MAP)
    n_lobes = length(GrugBot420.LOBE_MAP)
    n_rules = length(GrugBot420.RULE_MAP)
    n_msgs = length(GrugBot420.MESSAGE_HISTORY)
    println("📊 Status: nodes=$n_nodes | lobes=$n_lobes | rules=$n_rules | messages=$n_msgs")
    try
        pa = GrugBot420.EphemeralAutomaton.phase_pull_status()
        println("💎 Phase: crystal_size=$(get(pa, "crystal_size", 0)) | threshold=$(get(pa, "pull_threshold", 0.55)) | enabled=$(get(pa, "enabled", true))")
    catch e
        println("💎 Phase: ERROR getting status: $e")
    end
end

function handle_nodes()
    for (id, node) in GrugBot420.NODE_MAP
        grave_marker = node.is_grave ? " ☠️GRAVE" : ""
        println("  [$id] pattern=$(node.pattern[1:min(30,length(node.pattern))])... strength=$(round(node.strength, digits=2))$grave_marker")
    end
end

function handle_lobes()
    for (id, lobe) in GrugBot420.LOBE_MAP
        println("  [$id] subject=$(lobe.subject) nodes=$(lobe.node_count)")
    end
end

function handle_right()
    ids = lock(GrugBot420.LAST_VOTER_LOCK) do
        copy(GrugBot420.LAST_CONTRIBUTOR_IDS)
    end
    if isempty(ids)
        println("⚠️ /right: No previous contributors to reward.")
    else
        GrugBot420.apply_right_feedback!(ids)
        println("✅ /right applied. $(length(ids)) contributor(s) rewarded.")
    end
end

function handle_wrong()
    ids = lock(GrugBot420.LAST_VOTER_LOCK) do
        copy(GrugBot420.LAST_CONTRIBUTOR_IDS)
    end
    if isempty(ids)
        println("⚠️ /wrong: No previous contributors to penalize.")
    else
        GrugBot420.apply_wrong_feedback!(ids)
        println("❌ /wrong applied. $(length(ids)) contributor(s) penalized.")
    end
end

# ============================================================================
# MAIN TEST SEQUENCE
# ============================================================================

println("="^70)
println("   GRUG v7.27 COMPREHENSIVE TEST SESSION")
println("="^70 * "\n")

log_header!()

# ── 1. LOAD SPECIMEN ──
log_section!("1. Specimen Load")
println("[1] Loading specimen...")

specimen_path = joinpath(@__DIR__, "specimens", "comprehensive_v727_test.specimen.json")
if !isfile(specimen_path)
    println("  ✗ Specimen not found: $specimen_path")
    write_log!()
    exit(1)
end

output = run_cli_command("/loadSpecimen $specimen_path")
log_command!("/loadSpecimen specimens/comprehensive_v727_test.specimen.json", output)

# ── 2. PHASE CRYSTAL STATUS (initial) ──
log_section!("2. Phase Crystal Status (Initial)")
output = run_cli_command("/automaton phase status")
log_command!("/automaton phase status", output)

# ── 3. SYSTEM STATUS ──
log_section!("3. System Status")
output = run_cli_command("/status")
log_command!("/status", output)

# ── 4. BASIC GREETING ──
log_section!("4. Basic Greeting")
output = run_cli_command("/mission hello grug")
log_command!("/mission hello grug", output)

# ── 5. SIMPLE QUESTION (triggers QUERY family → maybe escalation) ──
log_section!("5. Simple Question — QUERY Action Family")
output = run_cli_command("/mission what is fire")
log_command!("/mission what is fire", output)

# ── 6. EMERGENCY INPUT (triggers ESCALATE family → crystal growth) ──
log_section!("6. Emergency Input — ESCALATE Action Family")
output = run_cli_command("/mission emergency help danger")
log_command!("/mission emergency help danger", output)

# ── 7. PHILOSOPHICAL INPUT (triggers SPECULATE → reflection) ──
log_section!("7. Philosophical Input — SPECULATE Action Family")
output = run_cli_command("/mission what is the meaning of existence why do we exist")
log_command!("/mission what is the meaning of existence why do we exist", output)

# ── 8. COMMAND INPUT (triggers COMMAND → directive) ──
log_section!("8. Command Input — COMMAND Action Family")
output = run_cli_command("/mission tell me about the danger and show me how to survive")
log_command!("/mission tell me about the danger and show me how to survive", output)

# ── 9. COMPOUND/COMPLEX INPUT (should trigger phase pull) ──
log_section!("9. Compound Input — Phase Pull Activation Test")
output = run_cli_command("/mission why do we exist and what is the meaning of truth but also tell me about danger")
log_command!("/mission why do we exist and what is the meaning of truth but also tell me about danger", output)

# ── 10. PHASE CRYSTAL STATUS (after interactions) ──
log_section!("10. Phase Crystal Status (After Interactions)")
output = run_cli_command("/automaton phase status")
log_command!("/automaton phase status", output)

# ── 11. MLP STATUS ──
log_section!("11. MLP Status")
output = run_cli_command("/mlpStatus")
log_command!("/mlpStatus", output)

# ── 12. RIGHT FEEDBACK (positive reinforcement) ──
log_section!("12. Right Feedback — Positive Reinforcement")
output = run_cli_command("/right")
log_command!("/right", output)

# ── 13. REPEAT SAME INPUT (test learning — should response change?) ──
log_section!("13. Repeat Input — Learning Test")
output = run_cli_command("/mission what is fire")
log_command!("/mission what is fire", output)

# ── 14. WRONG FEEDBACK (negative reinforcement) ──
log_section!("14. Wrong Feedback — Negative Reinforcement")
output = run_cli_command("/wrong")
log_command!("/wrong", output)

# ── 15. REPEAT SAME INPUT AGAIN (after correction) ──
log_section!("15. Repeat Input After Wrong Feedback")
output = run_cli_command("/mission what is fire")
log_command!("/mission what is fire", output)

# ── 16. PHASE THRESHOLD CHANGE ──
log_section!("16. Phase Threshold Configuration")
output = run_cli_command("/automaton phase threshold 0.35")
log_command!("/automaton phase threshold 0.35", output)

output = run_cli_command("/automaton phase status")
log_command!("/automaton phase status", output)

# ── 17. PHASE SURFACE COUNT ──
log_section!("17. Phase Surface Count Configuration")
output = run_cli_command("/automaton phase surface 5")
log_command!("/automaton phase surface 5", output)

# ── 18. PHASE DISABLE ──
log_section!("18. Phase Disable Test")
output = run_cli_command("/automaton phase disable")
log_command!("/automaton phase disable", output)

output = run_cli_command("/mission why does truth matter and what is existence")
log_command!("/mission why does truth matter and what is existence", output)

# ── 19. PHASE RE-ENABLE ──
log_section!("19. Phase Re-Enable Test")
output = run_cli_command("/automaton phase enable")
log_command!("/automaton phase enable", output)

output = run_cli_command("/mission why does truth matter and what is existence")
log_command!("/mission why does truth matter and what is existence", output)

# ── 20. PHASE RESET ──
log_section!("20. Phase Reset Test")
output = run_cli_command("/automaton phase reset")
log_command!("/automaton phase reset", output)

output = run_cli_command("/automaton phase status")
log_command!("/automaton phase status", output)

# ── 21. MATH INPUT (tests arithmetic engine) ──
log_section!("21. Math / Arithmetic Engine")
output = run_cli_command("/mission calculate 15 plus 27")
log_command!("/mission calculate 15 plus 27", output)

# ── 22. EMOTIONAL INPUT ──
log_section!("22. Emotional Input")
output = run_cli_command("/mission I feel sad and afraid today")
log_command!("/mission I feel sad and afraid today", output)

# ── 23. BRAINSTORM (heavy jitter) ──
log_section!("23. Brainstorm — Heavy Jitter Mode")
# brainstorm is tricky since it's in the CLI loop; use process_mission directly
# with brainstorm wrapper
buf = IOBuffer()
redirect_stdout(buf)
try
    GrugBot420.RelationalJitter.with_brainstorm_jitter() do
        GrugBot420.process_mission("what is the meaning of existence")
    end
catch e
    println(buf, "ERROR: $e")
finally
    redirect_stdout(stdout)
end
output = String(take!(buf))
log_command!("/brainstorm what is the meaning of existence", output)

# ── 24. SAVE SPECIMEN (with accumulated learning) ──
log_section!("24. Save Specimen — Preserve Learned State")
output = run_cli_command("/saveSpecimen specimens/v727_after_test.specimen.json")
log_command!("/saveSpecimen specimens/v727_after_test.specimen.json", output)

# ── 25. FINAL STATUS ──
log_section!("25. Final System Status")
output = run_cli_command("/status")
log_command!("/status", output)

output = run_cli_command("/automaton phase status")
log_command!("/automaton phase status", output)

output = run_cli_command("/mlpStatus")
log_command!("/mlpStatus", output)

# ============================================================================
# WRITE LOG
# ============================================================================
log_section!("Session Complete")
log_entry!("All 25 test phases completed. Log written.")
write_log!()

println("\n" * "="^70)
println("   COMPREHENSIVE TEST SESSION COMPLETE")
println("="^70)
println("\n📝 Log: $LOG_FILE")
