
include("src/Main.jl")

# Load the v8.1 specimen
println("\n=== LOADING V8.1 SPECIMEN ===")
result = load_specimen_from_file!("comprehensive_specimen_v81.json")
println(result)
println()

# Now process test inputs
test_inputs = [
    "hello grug",
    "&now what is happening right now",
    "&before what happened before the fire",
    "&next what comes after winter",
    "how does grug make fire",
    "when does the sun rise",
    "what does grug know about hunting and feasting",
    "grug hungry",
    "what is 3 + 5",
    "grug want to know about spring and summer seasons",
    "/status",
    "/saveSpecimen test_save_v81.json",
]

log_file = open("interaction_log_v81.txt", "w")

for (i, input_text) in enumerate(test_inputs)
    separator = "=" ^ 60
    header = "\n[$i] INPUT: $(input_text)\n$(separator)"
    println(header)
    write(log_file, header * "\n")

    # Process the input through the main loop
    t_start = time()
    try
        result = process_input(input_text)
        t_elapsed = round(time() - t_start, digits=3)

        # Get telemetry
        time_orient, time_meta = current_time_orientation()
        telemetry = """
        [TELEMETRY] elapsed=$(t_elapsed)s
        [TELEMETRY] time_orientation=$(time_orient)
        [TELEMETRY] nodes=$(length(NODE_MAP))
        [TELEMETRY] arousal=$(EyeSystem.get_arousal())
        """
        println(telemetry)
        write(log_file, telemetry * "\n")
    catch e
        err_msg = "ERROR: $e"
        println(err_msg)
        write(log_file, err_msg * "\n")
    end
    println()
end

# Show final state
println("\n" * "="^60)
println("FINAL STATE SUMMARY")
println("="^60)
println("  Nodes: $(length(NODE_MAP))")
println("  Messages: $(length(MESSAGE_HISTORY))")
# Count time nodes with orientation
time_oriented = 0
for (nid, node) in NODE_MAP
    if get(node.json_data, "time_node", false) && haskey(node.json_data, "time_orientation")
        time_oriented += 1
    end
end
println("  Oriented time nodes: $time_oriented")

time_orient, time_meta = current_time_orientation()
println("  Current time orientation: $(time_orient)")

close(log_file)
println("\nInteraction log saved to interaction_log_v81.txt")
