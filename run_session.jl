# Loader: include Main.jl in a way that triggers its auto-run, but first load
# the GrugBot420 package so all its modules are pre-included (Main.jl's
# !isdefined guards then skip their own redundant includes — no double-load).
using Pkg
Pkg.activate(@__DIR__)

include(joinpath(@__DIR__, "src", "GrugBot420.jl"))
using .GrugBot420

# Now run Main.jl as a script so its `if abspath(PROGRAM_FILE) == @__FILE__`
# block fires and run_cli() executes. Spawn it as a subprocess so PROGRAM_FILE
# matches.
# Actually simpler: just call run_cli() — it lives in GrugBot420 module after include.
GrugBot420.run_cli()
