# GrugBot v8.1 Comprehensive Interactive Test Script
# Uses process_mission() directly to avoid stdin/CLI complications
# Captures all output to a log file

include("src/Main.jl")

println("\n" * "="^70)
println("  GRUGBOT v8.1 COMPREHENSIVE INTERACTIVE TEST")
println("="^70)

# ── PHASE 1: Load the v8.1 specimen ─────────────────────────────────
println("\n── PHASE 1: Load v8.1 Specimen ──")
load_specimen_from_file!("comprehensive_specimen_v81.json")

# ── PHASE 2: Record initial state ────────────────────────────────────
println("\n── PHASE 2: Initial State ──")
_node_count = lock(() -> length(NODE_MAP), NODE_LOCK)
_msg_count = length(MESSAGE_HISTORY)
_time_orient, _time_meta = current_time_orientation()
_arousal = EyeSystem.get_arousal()
println("  Nodes: $_node_count")
println("  Messages: $_msg_count")
println("  Time orientation: $_time_orient")
println("  Arousal: $_arousal")

# Count oriented time nodes
_oriented_count = Ref(0)
lock(NODE_LOCK) do
    for (nid, node) in NODE_MAP
        if get(node.json_data, "time_node", false) && haskey(node.json_data, "time_orientation")
            _oriented_count[] += 1
        end
    end
end
println("  Oriented time nodes: $(_oriented_count[])")

# ── PHASE 3: Run test conversations ─────────────────────────────────
println("\n── PHASE 3: Interactive Test Conversations ──")

test_inputs = [
    # General conversation
    "hello grug",
    "what is grug favorite thing to do",
    "tell grug about the cave",

    # Time sigil tests - present
    "&now what is happening right now",
    "&now grug is feeling what today",

    # Time sigil tests - past
    "&before what happened before the fire",
    "&before grug remember what about the old days",

    # Time sigil tests - future
    "&next what comes after winter",
    "&next grug will do what when spring comes",

    # Knowledge & reasoning
    "how does grug make fire",
    "what does grug know about hunting",
    "when does the sun rise",
    "what is the best season for gathering food",

    # Multi-topic / Lobe cross-talk
    "grug want to know about spring and summer seasons",
    "what connects hunting and feasting",
    "how does fire help with cooking meat",

    # Mathematical reasoning
    "what is 3 + 5",
    "grug count to ten",

    # Emotional / social
    "grug hungry",
    "grug feel happy when what happens",
    "grug angry when what happens",

    # Time reasoning
    "how does time work for grug",
    "what is the difference between past and future",
]

# Open log file
log_file = open("v81_interaction_log.txt", "w")

function log_and_print(io::IO, msg::String)
    println(msg)
    write(io, msg * "\n")
    flush(io)
end

for (i, input_text) in enumerate(test_inputs)
    sep = "="^60
    log_and_print(log_file, "\n$sep")
    log_and_print(log_file, "[$i/$(length(test_inputs))] INPUT: \"$input_text\"")
    log_and_print(log_file, sep)

    t_start = time()
    try
        process_mission(input_text)
    catch e
        log_and_print(log_file, "ERROR: $e")
        try
            bt = catch_backtrace()
            log_and_print(log_file, sprint(showerror, e, bt))
        catch
            log_and_print(log_file, "(backtrace unavailable)")
        end
    end
    t_elapsed = round(time() - t_start, digits=3)

    # Telemetry after each turn
    _to, _tm = current_time_orientation()
    _ar = EyeSystem.get_arousal()
    _nc = lock(() -> length(NODE_MAP), NODE_LOCK)
    _mc = length(MESSAGE_HISTORY)

    telemetry = """
    [TELEMETRY] turn=$i elapsed=$(t_elapsed)s
    [TELEMETRY] time_orientation=$(_to)
    [TELEMETRY] nodes=$(_nc) arousal=$(_ar)
    [TELEMETRY] messages=$(_mc)
    """
    log_and_print(log_file, telemetry)

    # Small sleep to let background threads settle
    sleep(0.5)
end

# ── PHASE 4: Time sigil registry check ──────────────────────────────
println("\n── PHASE 4: Time Sigil Registry Check ──")
try
    _sigils = SigilRegistry.list_sigils(SigilRegistry.REGISTRY)
    for s in _sigils
        if s.name in ["now", "before", "next"]
            log_and_print(log_file, "  ✅ Time sigil: $(s.name) class=$(s.class) applies_at=$(s.applies_at)")
        end
    end
catch e
    log_and_print(log_file, "  Could not list sigils: $e")
end

# ── PHASE 5: Final state summary ─────────────────────────────────────
println("\n── PHASE 5: Final State Summary ──")
sep2 = "─"^60
log_and_print(log_file, "\n$sep2")
log_and_print(log_file, "FINAL STATE SUMMARY")
log_and_print(log_file, sep2)

_final_nodes = lock(() -> length(NODE_MAP), NODE_LOCK)
_final_msgs = length(MESSAGE_HISTORY)
_final_orient, _final_meta = current_time_orientation()
_final_arousal = EyeSystem.get_arousal()

# Count time nodes
_final_time = Ref(0)
_final_oriented = Ref(0)
lock(NODE_LOCK) do
    for (nid, node) in NODE_MAP
        if get(node.json_data, "time_node", false)
            _final_time[] += 1
            if haskey(node.json_data, "time_orientation")
                _final_oriented[] += 1
            end
        end
    end
end

summary = """
  Total nodes:     $_final_nodes
  Messages:        $_final_msgs
  Time nodes:      $(_final_time[])
  Oriented:        $(_final_oriented[])
  Time orientation: $_final_orient
  Arousal:         $_final_arousal
"""
log_and_print(log_file, summary)

# Show message history
log_and_print(log_file, "\n── Full Message History ──")
for idx in 1:length(MESSAGE_HISTORY)
    m = MESSAGE_HISTORY[idx]
    preview = length(m.text) > 150 ? m.text[1:150] * "..." : m.text
    log_and_print(log_file, "  [$idx] $(m.role): $(preview)")
end

# Show all time nodes with their orientations
log_and_print(log_file, "\n── Time Nodes with Orientation ──")
lock(NODE_LOCK) do
    for (nid, node) in NODE_MAP
        if get(node.json_data, "time_node", false)
            _orient = get(node.json_data, "time_orientation", "none")
            _sigil = get(node.json_data, "time_sigil", "none")
            log_and_print(log_file, "  $nid: pattern='$(node.pattern)' orientation=$_orient sigil=$_sigil")
        end
    end
end

# ── PHASE 6: Save output specimen ────────────────────────────────────
println("\n── PHASE 6: Save Output Specimen ──")
try
    save_specimen_to_file!("v81_test_output_specimen.json")
    log_and_print(log_file, "\n── Specimen saved to v81_test_output_specimen.json ──")
catch e
    log_and_print(log_file, "  Save failed: $e")
end

close(log_file)
println("\n✅ Comprehensive test complete! Log saved to v81_interaction_log.txt")
