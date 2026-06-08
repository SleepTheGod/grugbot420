using Pkg; Pkg.activate(".")
include("src/Main.jl")

# Load the comprehensive specimen directly
println("\n=== Loading comprehensive specimen ===")
result = load_specimen_from_file!("comprehensive_specimen_v742.json")
println("Load result: $result")

# Send a few messages to test auto-learning
println("\n=== Sending test messages ===")
process_mission("hello grug how are you today")
process_mission("tell me about emotions and feelings") 
process_mission("what is the meaning of life and consciousness")
process_mission("explain the concept of gravity and physics")
process_mission("calculate 42 plus 17 for me please")

# Check AutoGrowth status
println("\n=== AUTOGROWTH STATUS ===")
println(AutoGrowth.get_autogrowth_status_summary())

# Check AutoLinker status
println("\n=== AUTOLINKER STATUS ===")
println(AutoLinker.get_autolink_status_summary())
