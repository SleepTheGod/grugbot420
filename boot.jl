#!/usr/bin/env julia
# ==============================================================================
# boot.jl — GrugBot420 single-entry-point launcher
# ==============================================================================
# Usage:
#   julia boot.jl                          ← bare boot (no specimen)
#   julia boot.jl mybrain.specimen         ← boot + load specimen
#   julia boot.jl mybrain.specimen --save  ← boot + load + auto-save on exit
#
# That's it. No packagepath gymnastics, no "using .GrugBot420" rituals.
# This script handles the entire include/import chain internally.
# ==============================================================================

# ── 1. Load the engine ────────────────────────────────────────────────────────
const _GRUG_DIR = dirname(@__FILE__)
include(joinpath(_GRUG_DIR, "src", "GrugBot420.jl"))
using .GrugBot420

# ── 2. Import the functions the CLI needs ─────────────────────────────────────
import .GrugBot420:
    run_cli,
    process_mission,
    load_specimen_from_file!,
    save_specimen_to_file!,
    _LAST_VOICE_OUTPUT, _LAST_VOICE_OUTPUT_LOCK,
    _LAST_FIRED_NODE, _LAST_PRIMARY_ACTION, _LAST_CONFIDENCE,
    _LAST_SPECIMEN_PATH, _LAST_SPECIMEN_PATH_LOCK,
    LAST_VOTER_IDS, LAST_VOTER_LOCK,
    NODE_MAP, NODE_LOCK

# ── 3. Optional specimen load ──────────────────────────────────────────────────
const _SPEC_ARG  = something(try get(ARGS, 1); catch; nothing end, "")
const _SAVE_FLAG = "--save" in ARGS || "--save-on-exit" in ARGS

if _SPEC_ARG != "" && _SPEC_ARG != "--save" && _SPEC_ARG != "--save-on-exit"
    spec_path = _SPEC_ARG
    if !isfile(spec_path)
        # Try relative to script dir
        spec_path = joinpath(_GRUG_DIR, _SPEC_ARG)
    end
    if isfile(spec_path)
        println("[BOOT] Loading specimen: $spec_path")
        load_specimen_from_file!(spec_path)
        println("[BOOT] Specimen loaded ✓")
    else
        println("[BOOT] ⚠ Specimen not found: $(_SPEC_ARG) — starting bare")
    end
else
    println("[BOOT] No specimen specified — starting bare brain")
end

# ── 4. Auto-save hook (if --save flag) ────────────────────────────────────────
if _SAVE_FLAG
    atexit() do
        sp = lock(() -> _LAST_SPECIMEN_PATH[], _LAST_SPECIMEN_PATH_LOCK)
        if sp != "" && isfile(sp)
            try
                save_specimen_to_file!(sp)
                println("[EXIT] Auto-saved specimen: $sp ✓")
            catch e
                println("[EXIT] ⚠ Auto-save failed: $e")
            end
        else
            println("[EXIT] No specimen path recorded — skipping auto-save")
        end
    end
end

# ── 5. Launch CLI ─────────────────────────────────────────────────────────────
println("[BOOT] Launching GrugBot420 CLI...")
println()
run_cli()
