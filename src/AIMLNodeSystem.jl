# ==============================================================================
# AIMLNodeSystem.jl — GRUG Lobe-Specific Executive Node Tribes
# ==============================================================================
# GRUG say: old AIML one giant blob. Bad. Now each lobe gets own AIML tribe.
# GRUG say: AIML node has own strength. Can get stronger. Can get weaker. Can die.
# GRUG say: AIML globally activates. So cap at 1/3 parent lobe size. No bloat demon.
# GRUG say: ALL GROWTH DATA-DRIVEN. No data = no growth. Period.
# GRUG say: stochastic AIML growth ceiling = 1/3, but actual prob = data_warrant * 1/3.
# GRUG say: data_warrant comes from interaction / user / world. 0 warrant = 0 growth.
# GRUG say: /aimlRight and /aimlWrong update voted nodes this cycle ONLY.
# GRUG say: cycle memory mandatory. Without it, punishment not honest.
# GRUG say: dead AIML node becomes AIML_GRAVE. Remember executive failures.
# GRUG say: NO SILENT FAILURES. If invariant broken, scream loud.
# ==============================================================================

module AIMLNodeSystem

using Base.Threads: ReentrantLock
using Random

# GRUG: RelationalJitter — per-activation zero-mean nudge on strength values,
# strength deltas, and coin thresholds. Loaded at package level by
# GrugBot420.jl BEFORE this file, so the import here just binds the name.
# The isdefined guard keeps test files that include this module directly
# (without going through GrugBot420.jl) from exploding.
if !isdefined(@__MODULE__, :RelationalJitter)
    include(joinpath(@__DIR__, "RelationalJitter.jl"))
end
using .RelationalJitter

# ==============================================================================
# GRAVE SHADOW CONSTANTS — local copies with VoteOrchestrator fallback
# ==============================================================================
# GRUG BUG-010: These constants control the AIML global grave shadow.
# When running inside Main.jl (via GrugBot420.jl), they delegate to
# VoteOrchestrator's canonical values. When running standalone (tests),
# they fall back to local defaults. This avoids a hard dependency on
# VoteOrchestrator being loaded before AIMLNodeSystem.

function _grave_shadow_floor()::Float64
    try
        parent = parentmodule(@__MODULE__)
        if isdefined(parent, :VoteOrchestrator)
            vo = getfield(parent, :VoteOrchestrator)
            if isdefined(vo, :GRAVE_SHADOW_FLOOR)
                return getfield(vo, :GRAVE_SHADOW_FLOOR)
            end
        end
    catch; end
    return 0.70  # local fallback
end

function _grave_shadow_min_graves()::Int
    try
        parent = parentmodule(@__MODULE__)
        if isdefined(parent, :VoteOrchestrator)
            vo = getfield(parent, :VoteOrchestrator)
            if isdefined(vo, :GRAVE_SHADOW_MIN_GRAVES)
                return getfield(vo, :GRAVE_SHADOW_MIN_GRAVES)
            end
        end
    catch; end
    return 1  # local fallback
end

# ==============================================================================
# ERROR TYPES — GRUG hate silent failures!
# ==============================================================================

# GRUG: One error type for whole module. Carries message + context breadcrumb.
struct AIMLNodeError <: Exception
    message::String
    context::String
end

# GRUG: Helper that throws a properly-tagged error. Always use this, never bare error().
function throw_aiml_error(msg::String, ctx::String = "unknown")
    throw(AIMLNodeError(msg, ctx))
end

# ==============================================================================
# CONSTANTS — GRUG keep magic numbers in one place
# ==============================================================================

# GRUG: Strength bounds. Mirrors engine.jl STRENGTH_CAP so executive layer is not
# special-cased from main-node plasticity. Floor is 0.0 = AIML_GRAVE trigger.
const AIML_STRENGTH_CAP   = 10.0
const AIML_STRENGTH_FLOOR = 0.0

# GRUG: Population cap ratio. AIML per lobe <= floor(parent_lobe_cap / 3).
# Executive layer globally activates so it MUST be kept bounded. 1/3 is the rule.
const AIML_POPULATION_CAP_RATIO = 3

# GRUG: Strength delta per reward/penalty tick. Kept as named const so later
# tuning (or phagy pruning weights) has one place to touch.
const AIML_STRENGTH_DELTA = 1.0

# GRUG: Stochastic growth probability CEILING. When a main-node is planted
# in a lobe, we coinflip at probability = min(AIML_STOCHASTIC_GROWTH_PROB,
# data_warrant * AIML_STOCHASTIC_GROWTH_PROB). 1/3 ≈ 0.333 is the MAX —
# on average 3 main-node additions trigger ~1 AIML addition, but ONLY if
# there's enough data to justify it. No data = no growth. The 1/3 ceiling
# keeps the executive layer bounded to ~1/3 the main population in the
# long run. Stochasticity means it's approximate — no lockstep, no rigidity.
# Just moss growing on the cave wall at roughly 1/3 the speed of the rocks,
# but ONLY where there's moisture (data) to feed it.
const AIML_STOCHASTIC_GROWTH_PROB = 1.0 / 3.0

# GRUG: Grave reason strings. Short codes for downstream consumers.
const AIML_GRAVE_REASON_STRENGTH_ZERO = "AIML_STRENGTH_ZERO"

# ==============================================================================
# AIML NODE RECORD
# ==============================================================================

# GRUG: One AIML node. Belongs to exactly one lobe. Has own strength, own grave,
# own cycle bookkeeping. Template text is the AIML "payload" the node owns.
#
# Cycle fields (voted_this_cycle, fired_this_cycle, gained_this_cycle,
# strength_delta_this_cycle, orchestration_contribution_this_cycle) are MANDATORY.
# BUG-011: fired/use alone never changes strength; only explicit orchestration
# contribution can make a node eligible for stochastic /aimlRight or /aimlWrong.
# These fields are reset by reset_cycle!() at the start of every cycle.
mutable struct AIMLNode
    id::String
    lobe_id::String
    template::String                 # GRUG: AIML rule text / executive payload
    strength::Float64                # GRUG: [0.0, AIML_STRENGTH_CAP]
    is_grave::Bool                   # GRUG: True when strength hit 0.0 once
    grave_reason::String             # GRUG: Code from AIML_GRAVE_REASON_* consts

    # GRUG: Per-cycle bookkeeping. Without this punishment is dishonest.
    voted_this_cycle::Bool           # GRUG: Did this node vote in current cycle?
    fired_this_cycle::Bool           # GRUG: Did this node fire/get used in cycle?
    gained_this_cycle::Bool          # GRUG: Did strength go UP from feedback this cycle?
    strength_delta_this_cycle::Float64  # GRUG: Net strength change this cycle
    orchestration_contribution_this_cycle::Float64  # BUG-011: explicit output contribution score

    created_at::Float64
end

# GRUG: Constructor. Clamps strength to legal range and zeroes cycle fields.
# Validates non-empty id/lobe_id/template loudly — no quiet coercion.
function AIMLNode(id::String, lobe_id::String, template::String;
                  initial_strength::Float64 = 5.0)
    if isempty(strip(id))
        throw_aiml_error("AIMLNode id cannot be empty", "AIMLNode constructor")
    end
    if isempty(strip(lobe_id))
        throw_aiml_error("AIMLNode lobe_id cannot be empty", "AIMLNode constructor")
    end
    if isempty(strip(template))
        throw_aiml_error("AIMLNode template cannot be empty", "AIMLNode constructor")
    end
    if initial_strength < AIML_STRENGTH_FLOOR || initial_strength > AIML_STRENGTH_CAP
        throw_aiml_error(
            "initial_strength=$initial_strength out of [$(AIML_STRENGTH_FLOOR), $(AIML_STRENGTH_CAP)]",
            "AIMLNode constructor"
        )
    end
    # GRUG: Initial strength gets a small zero-mean nudge so freshly-born
    # AIML nodes don't all start at the exact same bullseye. The nudge is
    # re-clamped into the legal strength range so a near-cap / near-floor
    # seed cannot escape its boundary through jitter alone. See RelationalJitter.jl.
    jittered_initial = clamp(
        RelationalJitter.jitter_strength(initial_strength),
        AIML_STRENGTH_FLOOR,
        AIML_STRENGTH_CAP,
    )
    return AIMLNode(
        id, lobe_id, template,
        jittered_initial,
        false, "",
        false, false, false, 0.0, 0.0,
        time()
    )
end

# ==============================================================================
# GLOBAL REGISTRY — per-lobe AIML node populations
# ==============================================================================

# GRUG: lobe_id -> Dict{aiml_node_id -> AIMLNode}. Per-lobe isolation is a
# hard rule: one lobe's tribe never touches another. The outer dict is the
# mechanism for that isolation — it also gives O(1) lookup by lobe.
const AIML_REGISTRY = Dict{String, Dict{String, AIMLNode}}()

# GRUG: lobe_id -> population cap (computed from parent lobe cap at registration).
# Stored so we never need to re-import Lobe.jl just to enforce the 1/3 rule.
const AIML_POPULATION_CAP = Dict{String, Int}()

# GRUG: One lock to rule them all. Protects AIML_REGISTRY,
# AIML_POPULATION_CAP, and the CURRENT_CYCLE counter below. Single lock keeps
# cycle updates and population writes sequentially consistent — simpler than
# fine-grained locking and no faster to break.
const AIML_LOCK = ReentrantLock()

# GRUG: Monotonic cycle counter. Bumped by begin_cycle!(). Each node tracks the
# last cycle it saw via its flags, and reset_cycle! zeroes those flags.
# Counter is diagnostic only — correctness comes from the reset, not the number.
const CURRENT_CYCLE = Ref{Int}(0)

# ==============================================================================
# LOBE POPULATION REGISTRATION
# ==============================================================================

"""
register_lobe!(lobe_id::String, parent_lobe_cap::Int)::Int

GRUG: Register a lobe so AIML nodes can live there. Computes the cap as
floor(parent_lobe_cap / 3). Returns the computed cap so caller can verify.
Re-registering an existing lobe updates the cap — it does NOT wipe nodes.

Hard rule: every AIML lobe must be registered before nodes can be added.
No silent fallback to "some default cap" — missing registration is a fatal error.
"""
function register_lobe!(lobe_id::String, parent_lobe_cap::Int)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "register_lobe!")
    end
    if parent_lobe_cap <= 0
        throw_aiml_error("parent_lobe_cap must be positive, got $parent_lobe_cap", "register_lobe!")
    end
    # GRUG: Integer floor division. Cap = 1/3 parent lobe population.
    aiml_cap = div(parent_lobe_cap, AIML_POPULATION_CAP_RATIO)
    if aiml_cap <= 0
        throw_aiml_error(
            "Computed AIML cap is non-positive for lobe '$lobe_id' (parent cap=$parent_lobe_cap). Lobe too small for AIML tribe.",
            "register_lobe!"
        )
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            AIML_REGISTRY[lobe_id] = Dict{String, AIMLNode}()
        end
        AIML_POPULATION_CAP[lobe_id] = aiml_cap
    end
    return aiml_cap
end

"""
unregister_lobe!(lobe_id::String)

GRUG: Remove a lobe's AIML tribe entirely. Wipes population + cap.
Used when the parent lobe itself is being torn down. Not for casual use.
"""
function unregister_lobe!(lobe_id::String)
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "unregister_lobe!")
    end
    lock(AIML_LOCK) do
        delete!(AIML_REGISTRY, lobe_id)
        delete!(AIML_POPULATION_CAP, lobe_id)
    end
end

"""
is_lobe_registered(lobe_id::String)::Bool

GRUG: True if lobe has been registered for AIML. Safe read — no throw.
"""
function is_lobe_registered(lobe_id::String)::Bool
    lock(AIML_LOCK) do
        return haskey(AIML_REGISTRY, lobe_id)
    end
end

"""
get_population_cap(lobe_id::String)::Int

GRUG: Return configured 1/3 cap for this lobe. Throws if lobe not registered.
"""
function get_population_cap(lobe_id::String)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "get_population_cap")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_POPULATION_CAP, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_population_cap")
        end
        return AIML_POPULATION_CAP[lobe_id]
    end
end

"""
get_population_size(lobe_id::String)::Int

GRUG: Total number of AIML nodes in this lobe (alive + grave).
For cap enforcement, use get_alive_population_size() instead.
"""
function get_population_size(lobe_id::String)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "get_population_size")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_population_size")
        end
        return length(AIML_REGISTRY[lobe_id])
    end
end

"""
get_alive_population_size(lobe_id::String)::Int

GRUG: Number of ALIVE AIML nodes in this lobe (excludes graves).
This is the number used for population cap enforcement.
GRUG say: graves are memory, not bloat. Dead nodes don't eat cap space.
"""
function get_alive_population_size(lobe_id::String)::Int
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "get_alive_population_size")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_alive_population_size")
        end
        tribe = AIML_REGISTRY[lobe_id]
        return count(n -> !n.is_grave, values(tribe))
    end
end

# ==============================================================================
# NODE LIFECYCLE — add, get, remove
# ==============================================================================

"""
add_aiml_node!(lobe_id::String, node_id::String, template::String; initial_strength=5.0)::AIMLNode

GRUG: Plant a new AIML node in a lobe's tribe. Enforces:
  1. Lobe must be registered.
  2. Population cap must NOT be exceeded (throws loudly — no silent overflow).
  3. Node id must not already exist in this lobe.

Returns the created AIMLNode. On any failure, throws AIMLNodeError.
"""
function add_aiml_node!(lobe_id::String, node_id::String, template::String;
                        initial_strength::Float64 = 5.0)::AIMLNode
    if isempty(strip(lobe_id))
        throw_aiml_error("lobe_id cannot be empty", "add_aiml_node!")
    end
    if isempty(strip(node_id))
        throw_aiml_error("node_id cannot be empty", "add_aiml_node!")
    end
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML. Call register_lobe! first.", "add_aiml_node!")
        end
        tribe = AIML_REGISTRY[lobe_id]
        cap = AIML_POPULATION_CAP[lobe_id]

        # GRUG: Hard cap check — ALIVE nodes only, graves don't count!
        # GRUG say: dead executive is memory, not bloat. Cap is for living.
        alive_count = count(n -> !n.is_grave, values(tribe))
        if alive_count >= cap
            throw_aiml_error(
                "AIML population cap exceeded for lobe '$lobe_id' (alive=$alive_count, grave=$(length(tribe)-alive_count), cap=$cap). Top brain not allowed to become big bloated demon.",
                "add_aiml_node!"
            )
        end
        if haskey(tribe, node_id)
            throw_aiml_error(
                "AIML node '$node_id' already exists in lobe '$lobe_id'. No duplicates.",
                "add_aiml_node!"
            )
        end

        node = AIMLNode(node_id, lobe_id, template; initial_strength=initial_strength)
        tribe[node_id] = node
        return node
    end
end

"""
stochastic_aiml_growth!(lobe_id::String, hint_pattern::String=""; data_warrant::Float64=1.0)::Union{AIMLNode, Nothing}

GRUG: When a main node is planted in a lobe, call this. Growth probability
is data_warrant * AIML_STOCHASTIC_GROWTH_PROB. The 1/3 ceiling is the MAX —
actual probability scales down with how much new data justifies it.

data_warrant (0.0–1.0): How much new information is available to justify
  growing an AIML executive node. 1.0 = full warrant (e.g. user explicitly
  planted via /grow, or mitosis found strong warrant). 0.0 = no data, no
  growth, period. This is NOT optional — growth without data is cancer.

The new AIML node's template is derived from hint_pattern if provided:
  "Executive scaffold for: {hint_pattern}"
If hint_pattern is empty, a generic template is used.

If the coinflip fails or the cap is full, returns nothing (silently — this
is stochastic, failure is normal). If the lobe isn't registered for AIML,
also returns nothing (the lobe may not have an AIML tribe yet).

Thread-safe: takes AIML_LOCK internally.
"""
function stochastic_aiml_growth!(lobe_id::String, hint_pattern::String="";
                                 data_warrant::Float64=1.0,
                                 thesaurus_fn::Union{Function, Nothing}=nothing)::Union{AIMLNode, Nothing}
    # GRUG: No data = no growth. Period. Growth without data is cancer.
    if data_warrant <= 0.0
        return nothing
    end

    # GRUG BUG-011: AIML inhibition is auto-growth-only and orchestration-focused.
    # If current-cycle orchestration contributors already cover this hint, do not
    # grow another executive scaffold for the same territory. Fired/voted-only AIML
    # nodes do not inhibit growth.
    if is_aiml_growth_inhibited(lobe_id, hint_pattern; thesaurus_fn=thesaurus_fn)
        return nothing
    end

    # GRUG: Effective probability = data_warrant * ceiling. The 1/3 ceiling
    # keeps the executive layer bounded. The warrant scales it down honestly.
    # If warrant is 0.5, effective prob = 0.5 * 0.333 ≈ 0.167. Sparse data
    # = sparse growth. Rich data = growth up to the 1/3 ceiling.
    effective_prob = min(data_warrant * AIML_STOCHASTIC_GROWTH_PROB, AIML_STOCHASTIC_GROWTH_PROB)

    # GRUG: Coinflip at the effective probability. Most calls with low warrant,
    # nothing happens. That's the point. Growth must be EARNED.
    if rand() >= effective_prob
        return nothing
    end

    # GRUG: Lock to check registration, cap, and add atomically.
    return lock(AIML_LOCK) do
        # Lobe not registered for AIML? Silent return — not every lobe needs a tribe.
        if !haskey(AIML_REGISTRY, lobe_id)
            return nothing
        end

        tribe = AIML_REGISTRY[lobe_id]
        cap = AIML_POPULATION_CAP[lobe_id]

        # GRUG: Cap check — alive nodes only, graves don't count.
        alive_count = count(n -> !n.is_grave, values(tribe))
        if alive_count >= cap
            # GRUG: Cap full. Can't grow. This is NOT an error — stochastic
            # growth just didn't land this time. Return silently.
            return nothing
        end

        # GRUG: Build the AIML node. Template is derived from the hint pattern
        # if available, otherwise generic. The template is the executive payload —
        # it's what the AIML node "knows" about. Not fancy, just honest scaffold.
        template = if !isempty(strip(hint_pattern))
            "Executive scaffold for: $(strip(hint_pattern))"
        else
            "Executive scaffold (auto-grown)"
        end

        # GRUG: Auto-grown AIML node ID. Use a counter so IDs are unique.
        # Format: aiml_auto_{lobe_id}_{counter}. Short, traceable, no mystery.
        auto_id = "aiml_auto_$(lobe_id)_$(alive_count + 1)_$(round(Int, time() * 1000) % 100000)"

        # GRUG: Already exists? Extremely unlikely with timestamp suffix, but
        # if it does, just skip. No duplicate AIML nodes, ever.
        if haskey(tribe, auto_id)
            return nothing
        end

        node = AIMLNode(auto_id, lobe_id, template; initial_strength=5.0)
        tribe[auto_id] = node

        println("[AIML] 🌱  Stochastic growth: auto-planted AIML node '$auto_id' in lobe '$lobe_id' (alive=$(alive_count + 1)/$cap, warrant=$(round(data_warrant, digits=2)), hint='$(hint_pattern[1:min(30, length(hint_pattern))])')")

        return node
    end
end

"""
get_aiml_node(lobe_id::String, node_id::String)::AIMLNode

GRUG: Fetch a node. Throws if lobe unregistered or node missing.
"""
function get_aiml_node(lobe_id::String, node_id::String)::AIMLNode
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "get_aiml_node")
        end
        tribe = AIML_REGISTRY[lobe_id]
        if !haskey(tribe, node_id)
            throw_aiml_error("AIML node '$node_id' not found in lobe '$lobe_id'", "get_aiml_node")
        end
        return tribe[node_id]
    end
end

"""
has_aiml_node(lobe_id::String, node_id::String)::Bool

GRUG: Cheap membership probe. No throw on missing lobe — just false.
"""
function has_aiml_node(lobe_id::String, node_id::String)::Bool
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            return false
        end
        return haskey(AIML_REGISTRY[lobe_id], node_id)
    end
end

"""
remove_aiml_node!(lobe_id::String, node_id::String)::Bool

GRUG: Delete a node entirely (e.g. future phagy cleanup). Returns true if removed,
false if it wasn't there. Missing lobe throws — phagy must know its lobes.
"""
function remove_aiml_node!(lobe_id::String, node_id::String)::Bool
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "remove_aiml_node!")
        end
        tribe = AIML_REGISTRY[lobe_id]
        if !haskey(tribe, node_id)
            return false
        end
        delete!(tribe, node_id)
        return true
    end
end

"""
list_aiml_nodes(lobe_id::String)::Vector{AIMLNode}

GRUG: Snapshot vector of AIML nodes in a lobe. Sorted by id for stable iteration.
"""
function list_aiml_nodes(lobe_id::String)::Vector{AIMLNode}
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            throw_aiml_error("Lobe '$lobe_id' not registered for AIML", "list_aiml_nodes")
        end
        nodes = collect(values(AIML_REGISTRY[lobe_id]))
        sort!(nodes; by = n -> n.id)
        return nodes
    end
end

"""
get_registered_lobes()::Vector{String}

GRUG: List every lobe that has an AIML tribe registered. Sorted for stability.
"""
function get_registered_lobes()::Vector{String}
    lock(AIML_LOCK) do
        return sort(collect(keys(AIML_REGISTRY)))
    end
end

# ==============================================================================
# CYCLE MANAGEMENT — mandatory per-cycle bookkeeping
# ==============================================================================

"""
begin_cycle!()

GRUG: Start a new cycle. Bumps CURRENT_CYCLE and resets all per-cycle flags
on every node in every registered lobe. Call this at the TOP of every mission
BEFORE any AIML firing / voting happens. Without this, cycle-aware reward/
punishment is meaningless.
"""
function begin_cycle!()
    lock(AIML_LOCK) do
        CURRENT_CYCLE[] += 1
        for (_lobe_id, tribe) in AIML_REGISTRY
            for (_nid, node) in tribe
                node.voted_this_cycle = false
                node.fired_this_cycle = false
                node.gained_this_cycle = false
                node.strength_delta_this_cycle = 0.0
                node.orchestration_contribution_this_cycle = 0.0
            end
        end
    end
end

"""
current_cycle()::Int

GRUG: The monotonic cycle counter. Diagnostic only.
"""
function current_cycle()::Int
    lock(AIML_LOCK) do
        return CURRENT_CYCLE[]
    end
end

# ==============================================================================
# BUG-011 AIML GROWTH INHIBITION — orchestration-focused, thesaurus-expanded
# ==============================================================================

function _aiml_inhibition_tokens_from_text(text::String; thesaurus_fn::Union{Function, Nothing}=nothing)::Set{String}
    tokens = Set{String}()
    for raw in split(lowercase(strip(text)), r"\s+")
        tok = strip(String(raw))
        isempty(tok) && continue
        push!(tokens, tok)
        if thesaurus_fn !== nothing
            try
                for syn in thesaurus_fn(tok)
                    syn_tok = lowercase(strip(String(syn)))
                    isempty(syn_tok) || push!(tokens, syn_tok)
                end
            catch
                # GRUG: thesaurus is advisory. Bad synonym provider must not break growth.
            end
        end
    end
    return tokens
end

function _aiml_orchestration_inhibition_tokens(lobe_id::String; thesaurus_fn::Union{Function, Nothing}=nothing)::Set{String}
    tokens = Set{String}()
    lock(AIML_LOCK) do
        tribe = get(AIML_REGISTRY, lobe_id, nothing)
        tribe === nothing && return tokens
        for node in values(tribe)
            node.is_grave && continue
            if node.orchestration_contribution_this_cycle >= AIML_ORCHESTRATION_CONTRIBUTION_THRESHOLD
                union!(tokens, _aiml_inhibition_tokens_from_text(node.template; thesaurus_fn=thesaurus_fn))
            end
        end
    end
    return tokens
end

"""
    is_aiml_growth_inhibited(lobe_id::String, hint_pattern::String; threshold=0.5, thesaurus_fn=nothing)::Bool

BUG-011: AIML auto-growth inhibition is based only on AIML nodes that materially
contributed to orchestration this cycle. Mere voting/firing does not create
inhibition. Tokens are expanded by the optional thesaurus function. This helper
is consulted by stochastic AIML growth only; reinforcement feedback does not use
it.
"""
function is_aiml_growth_inhibited(
    lobe_id::String,
    hint_pattern::String;
    threshold::Float64 = 0.5,
    thesaurus_fn::Union{Function, Nothing} = nothing,
)::Bool
    candidate_tokens = _aiml_inhibition_tokens_from_text(hint_pattern; thesaurus_fn=nothing)
    isempty(candidate_tokens) && return false

    active_tokens = _aiml_orchestration_inhibition_tokens(lobe_id; thesaurus_fn=thesaurus_fn)
    isempty(active_tokens) && return false

    overlap = length(intersect(candidate_tokens, active_tokens))
    ratio = Float64(overlap) / Float64(length(candidate_tokens))
    return ratio >= threshold
end

# ==============================================================================
# GRAVE SHADOW — Global AIML inhibition from dead executive knowledge
# ==============================================================================

"""
    compute_aiml_grave_shadow(lobe_id::String)::Float64

GRUG BUG-010: AIML nodes are globally active — grave shadow is tribe-wide,
not group-scoped. When many AIML nodes have died in a lobe's tribe, the
surviving nodes' strength feedback gets dampened. Dead executives cast
long shadows: a tribe that has lost many templates is a weaker responder.

Formula: shadow = 1.0 - (grave_ratio * (1.0 - GRAVE_SHADOW_FLOOR))
  - 0 graves → 1.0 (full strength feedback)
  - some graves → <1.0 (dampened)
  - all graves → GRAVE_SHADOW_FLOOR (maximum dampening)

Called from _apply_strength_delta! to modulate delta magnitude.
"""
function compute_aiml_grave_shadow(lobe_id::String)::Float64
    lock(AIML_LOCK) do
        if !haskey(AIML_REGISTRY, lobe_id)
            return 1.0  # no tribe — no shadow
        end
        tribe = AIML_REGISTRY[lobe_id]
        grave_count = 0
        alive_count = 0
        for (nid, node) in tribe
            if node.is_grave
                grave_count += 1
            else
                alive_count += 1
            end
        end
        if grave_count < _grave_shadow_min_graves()
            return 1.0  # not enough graves to cast a shadow
        end
        total = Float64(grave_count + alive_count)
        if total <= 0
            return 1.0
        end
        grave_ratio = Float64(grave_count) / total
        floor = _grave_shadow_floor()
        shadow = 1.0 - (grave_ratio * (1.0 - floor))
        return clamp(shadow, floor, 1.0)
    end
end

# ==============================================================================
# STRENGTH DYNAMICS — feedback-based change only
# ==============================================================================

# GRUG: Internal strength mutator. Clamps, updates cycle delta, and transitions
# the node to AIML_GRAVE if strength hits the floor. Caller holds AIML_LOCK.
# NOT exported — external callers must go through the feedback API.
function _apply_strength_delta!(node::AIMLNode, delta::Float64)
    if node.is_grave
        # GRUG: Grave nodes are permanent negative reinforcement. No resurrection
        # via passive strength nudges. Phagy or explicit revive would be needed.
        return
    end
    # GRUG BUG-010: AIML grave shadow — global inhibition from dead executives.
    # Positive deltas (rewards) are dampened by the shadow; negative deltas
    # (penalties) pass through unmodified. Dead knowledge weakens the tribe's
    # ability to benefit from reinforcement, but doesn't protect it from decay.
    if delta > 0.0
        shadow = compute_aiml_grave_shadow(node.lobe_id)
        delta = delta * shadow
    end
    # GRUG: Every strength delta gets a small zero-mean nudge at application
    # time. Sign is preserved (ratio < 1 so +1.0 stays positive, −1.0 stays
    # negative) and the caller-requested delta is preserved in expectation.
    # The downstream clamp to [FLOOR, CAP] still enforces the hard boundary,
    # so jitter cannot push strength out of legal range. The grave-trigger
    # condition (`strength <= FLOOR`) is checked on the clamped value, so a
    # jittered near-zero delta cannot cause a spurious grave transition.
    jittered_delta = RelationalJitter.jitter_delta(delta)
    old_strength = node.strength
    new_strength = clamp(node.strength + jittered_delta, AIML_STRENGTH_FLOOR, AIML_STRENGTH_CAP)
    applied_delta = new_strength - old_strength
    node.strength = new_strength
    node.strength_delta_this_cycle += applied_delta
    if applied_delta > 0.0
        node.gained_this_cycle = true
    end
    if node.strength <= AIML_STRENGTH_FLOOR
        # GRUG: Strength floor hit. Mark AIML_GRAVE. Dead executive pattern
        # becomes anti-pattern memory — it does NOT just vanish. Phagy may
        # later remove graves, but that is a separate idle-time event.
        node.is_grave = true
        node.grave_reason = AIML_GRAVE_REASON_STRENGTH_ZERO
        println("[AIML] ⚰  Node '$(node.id)' in lobe '$(node.lobe_id)' marked AIML_GRAVE (strength -> 0).")
    end
end

"""
record_fire!(node::AIMLNode)

GRUG BUG-011: Mark that an AIML node fired this cycle. Fire/use is NOT
reinforcement. Strength changes only happen later through explicit feedback
(/aimlRight or /aimlWrong), only for nodes with recorded orchestration
contribution, and still only on a stochastic coinflip.

Thread-safe: takes AIML_LOCK for cycle bookkeeping.
"""
function record_fire!(node::AIMLNode)
    lock(AIML_LOCK) do
        node.fired_this_cycle = true
    end
end

"""
record_orchestration_contribution!(node::AIMLNode; weight::Float64 = 1.0)

GRUG BUG-011: Mark that this AIML node materially contributed to output
orchestration this cycle. This is the AIML lock-in equivalent used by
/aimlRight and /aimlWrong. Mere voting or firing is not enough.

weight must be positive. Current callers can use the default 1.0 when a node
was selected into the final orchestration path; future orchestrators can add
larger weights for dominant contributors.
"""
function record_orchestration_contribution!(node::AIMLNode; weight::Float64 = 1.0)
    if weight <= 0.0
        throw_aiml_error("orchestration contribution weight must be positive, got $weight", "record_orchestration_contribution!")
    end
    lock(AIML_LOCK) do
        node.orchestration_contribution_this_cycle += weight
        node.fired_this_cycle = true
    end
end

"""
record_vote!(node::AIMLNode)

GRUG: Mark that an AIML node cast a vote this cycle. /aimlRight and /aimlWrong
apply ONLY to voters — not to the whole universe. This is how we keep feedback
targeted.
"""
function record_vote!(node::AIMLNode)
    lock(AIML_LOCK) do
        node.voted_this_cycle = true
    end
end

# ==============================================================================
# FEEDBACK COMMANDS — /aimlRight and /aimlWrong
# ==============================================================================

# GRUG: Shared helper to collect all voted-this-cycle AIML nodes across registered
# lobes. Used by legacy systems. New feedback uses _collect_contributors().
# Caller does NOT hold the lock — this function takes it internally and returns
# a plain vector for iteration outside.
function _collect_voters()::Vector{AIMLNode}
    voters = AIMLNode[]
    lock(AIML_LOCK) do
        for (_lobe_id, tribe) in AIML_REGISTRY
            for (_nid, node) in tribe
                if node.voted_this_cycle
                    push!(voters, node)
                end
            end
        end
    end
    return voters
end

# GRUG BUG-011: Shared helper to collect AIML orchestration contributors across
# registered lobes. ONLY nodes with explicit orchestration contribution are
# eligible for strength modifications from /aimlRight and /aimlWrong. Fired,
# voted, or merely considered nodes are not enough.
# Caller does NOT hold the lock — this function takes it internally and returns
# a plain vector for iteration outside.
const AIML_ORCHESTRATION_CONTRIBUTION_THRESHOLD = 1.0

function _collect_contributors()::Vector{AIMLNode}
    contributors = AIMLNode[]
    lock(AIML_LOCK) do
        for (_lobe_id, tribe) in AIML_REGISTRY
            for (_nid, node) in tribe
                if node.orchestration_contribution_this_cycle >= AIML_ORCHESTRATION_CONTRIBUTION_THRESHOLD
                    push!(contributors, node)
                end
            end
        end
    end
    return contributors
end

"""
apply_aiml_right!()::Dict{String, Any}

GRUG BUG-011: /aimlRight feedback — lock-in-equivalent reinforcement for
AIML orchestration contributors only.

CRITICAL RULE: ONLY nodes with explicit orchestration contribution this cycle
are eligible for reinforcement. Voters, fired nodes, and considered nodes that
were not selected into orchestration are ignored. Eligible nodes still gain
strength only on a jittered stochastic coinflip.

Returns a diagnostic dict for logging / test assertions.
"""
function apply_aiml_right!()::Dict{String, Any}
    contributors = _collect_contributors()
    rewarded = String[]
    coinflip_missed = String[]
    grave_skipped = String[]

    lock(AIML_LOCK) do
        for node in contributors
            if node.is_grave
                push!(grave_skipped, node.id)
                continue
            end
            if rand() < RelationalJitter.jitter_coin_threshold(0.5)
                _apply_strength_delta!(node, AIML_STRENGTH_DELTA)
                push!(rewarded, node.id)
            else
                push!(coinflip_missed, node.id)
            end
        end
    end

    result = Dict{String, Any}(
        "total_contributors"   => length(contributors),
        "rewarded"             => rewarded,
        "skipped_double_reward" => String[],  # compatibility: use-reward removed in BUG-011
        "coinflip_missed"      => coinflip_missed,
        "grave_skipped"        => grave_skipped,
    )
    println("[AIML] ✅ /aimlRight lock-in-only: contributors=$(length(contributors)) rewarded=$(length(rewarded)) coinflip_miss=$(length(coinflip_missed)) grave_skip=$(length(grave_skipped))")
    return result
end

"""
apply_aiml_wrong!()::Dict{String, Any}

GRUG BUG-011: /aimlWrong feedback — penalize AIML orchestration contributors
only.

CRITICAL RULE: ONLY nodes with explicit orchestration contribution this cycle
are eligible for penalty. Eligible nodes still lose strength only on a jittered
stochastic coinflip. record_fire! no longer creates prior same-cycle gains, so
there is no use-reward overcompensation path here.

Returns a diagnostic dict. If strength reaches 0.0, the node is transitioned
to AIML_GRAVE by _apply_strength_delta!.
"""
function apply_aiml_wrong!()::Dict{String, Any}
    contributors = _collect_contributors()
    penalized = String[]
    spared = String[]
    graved = String[]
    grave_skipped = String[]

    lock(AIML_LOCK) do
        for node in contributors
            if node.is_grave
                push!(grave_skipped, node.id)
                continue
            end
            if rand() < RelationalJitter.jitter_coin_threshold(0.5)
                was_grave_before = node.is_grave
                _apply_strength_delta!(node, -AIML_STRENGTH_DELTA)
                push!(penalized, node.id)
                if node.is_grave && !was_grave_before
                    push!(graved, node.id)
                end
            else
                push!(spared, node.id)
            end
        end
    end

    result = Dict{String, Any}(
        "total_contributors" => length(contributors),
        "penalized"         => penalized,
        "spared"            => spared,
        "newly_graved"      => graved,
        "grave_skipped"     => grave_skipped,
    )
    println("[AIML] ❌ /aimlWrong lock-in-only: contributors=$(length(contributors)) penalized=$(length(penalized)) spared=$(length(spared)) newly_graved=$(length(graved)) grave_skip=$(length(grave_skipped))")
    return result
end

# ==============================================================================
# PHAGY HOOK — future stochastic maintenance
# ==============================================================================

"""
aiml_phagy_sweep!(; prune_graves::Bool = true)::Dict{String, Any}

GRUG: Future stochastic idle-time AIML phagy. For now, minimal:
prune AIML_GRAVE nodes on request. Real phagy will coinflip weak nodes,
stale templates, etc. — but that is a later event. Signature is stable so
callers can schedule it now without breaking when the real body lands.

If prune_graves is true, every AIML_GRAVE node is removed from its tribe.
Grave-state negative-reinforcement semantics persist until phagy runs —
this is the idle-time garbage collection for the executive layer.
"""
function aiml_phagy_sweep!(; prune_graves::Bool = true)::Dict{String, Any}
    pruned = Tuple{String, String}[]  # (lobe_id, node_id)
    lock(AIML_LOCK) do
        if prune_graves
            for (lobe_id, tribe) in AIML_REGISTRY
                grave_ids = [nid for (nid, n) in tribe if n.is_grave]
                for nid in grave_ids
                    delete!(tribe, nid)
                    push!(pruned, (lobe_id, nid))
                end
            end
        end
    end
    result = Dict{String, Any}(
        "pruned_count" => length(pruned),
        "pruned"       => pruned,
    )
    println("[AIML] 🧹 phagy_sweep: pruned $(length(pruned)) grave node(s).")
    return result
end

# ==============================================================================
# DIAGNOSTICS — status summary for /status and tests
# ==============================================================================

"""
get_aiml_status_summary()::String

GRUG: Human-readable snapshot for /status. Shows population vs cap per lobe,
live/grave counts, and current cycle number.
"""
function get_aiml_status_summary()::String
    lines = String[]
    lock(AIML_LOCK) do
        push!(lines, "=== AIML NODE TRIBES (cycle=$(CURRENT_CYCLE[])) ===")
        push!(lines, "  Stochastic growth: ceiling=$(round(AIML_STOCHASTIC_GROWTH_PROB, digits=3)) (~1/3), data-driven (warrant modulates probability)")
        if isempty(AIML_REGISTRY)
            push!(lines, "  [no lobes registered]")
            return
        end
        for lobe_id in sort(collect(keys(AIML_REGISTRY)))
            tribe = AIML_REGISTRY[lobe_id]
            cap   = get(AIML_POPULATION_CAP, lobe_id, 0)
            live  = count(n -> !n.is_grave, values(tribe))
            grave = length(tribe) - live
            # GRUG: Count auto-grown nodes (aiml_auto_ prefix) for diagnostics
            auto_grown = count(n -> startswith(n.id, "aiml_auto_"), values(tribe))
            push!(lines, "  $lobe_id | pop=$(length(tribe))/$cap | live=$live | grave=$grave | auto=$auto_grown")
        end
    end
    return join(lines, "\n")
end

"""
reset_all!()

GRUG: Wipe the whole AIML registry + population caps + cycle counter.
For tests and clean-slate restarts only. In production this is a nuclear option.
"""
function reset_all!()
    lock(AIML_LOCK) do
        empty!(AIML_REGISTRY)
        empty!(AIML_POPULATION_CAP)
        CURRENT_CYCLE[] = 0
    end
end

# ==============================================================================
# SERIALIZATION — Save/Load Support for Specimen Files
# ==============================================================================
# GRUG: AIML nodes need to survive /saveSpecimen and /loadSpecimen.
# This module provides serialize/deserialize functions for the specimen file.
# NO SILENT FAILURES: All errors are loud and clear.

"""
    serialize_aiml_state()::Dict{String, Any}

GRUG: Serialize the entire AIML system state for specimen save file.
Returns a dict with:
  - "registry": All AIML nodes per lobe
  - "population_caps": Per-lobe caps
  - "cycle": Current cycle counter

Thread-safe: uses AIML_LOCK.
"""
function serialize_aiml_state()::Dict{String, Any}
    return lock(AIML_LOCK) do
        # GRUG: Serialize each lobe's tribe
        registry_data = Dict{String, Any}()
        for (lobe_id, tribe) in AIML_REGISTRY
            nodes_list = Dict{String, Any}[]
            for (node_id, node) in tribe
                push!(nodes_list, Dict{String, Any}(
                    "id" => node.id,
                    "lobe_id" => node.lobe_id,
                    "template" => node.template,
                    "strength" => node.strength,
                    "is_grave" => node.is_grave,
                    "grave_reason" => node.grave_reason,
                    "voted_this_cycle" => node.voted_this_cycle,
                    "fired_this_cycle" => node.fired_this_cycle,
                    "gained_this_cycle" => node.gained_this_cycle,
                    "strength_delta_this_cycle" => node.strength_delta_this_cycle,
                    "orchestration_contribution_this_cycle" => node.orchestration_contribution_this_cycle,
                    "created_at" => node.created_at
                ))
            end
            registry_data[lobe_id] = nodes_list
        end

        # GRUG: Copy population caps
        caps_data = Dict{String, Int}()
        for (lobe_id, cap) in AIML_POPULATION_CAP
            caps_data[lobe_id] = cap
        end

        return Dict{String, Any}(
            "registry" => registry_data,
            "population_caps" => caps_data,
            "cycle" => CURRENT_CYCLE[],
            "stochastic_growth_prob" => AIML_STOCHASTIC_GROWTH_PROB
        )
    end
end

"""
    deserialize_aiml_state!(data)

GRUG: Restore AIML system state from specimen save file.
Wipes existing state and replaces with loaded data.
NO SILENT FAILURES: Validates all data before applying.

Expects data with keys:
  - "registry": Dict mapping lobe_id -> list of node dicts
  - "population_caps": Dict mapping lobe_id -> cap
  - "cycle": Integer cycle counter
"""
function deserialize_aiml_state!(data)
    # GRUG: Validate input structure
    if !haskey(data, "registry")
        error("!!! FATAL: deserialize_aiml_state! missing 'registry' key !!!")
    end
    if !haskey(data, "population_caps")
        error("!!! FATAL: deserialize_aiml_state! missing 'population_caps' key !!!")
    end
    if !haskey(data, "cycle")
        error("!!! FATAL: deserialize_aiml_state! missing 'cycle' key !!!")
    end

    lock(AIML_LOCK) do
        # GRUG: Wipe existing state
        empty!(AIML_REGISTRY)
        empty!(AIML_POPULATION_CAP)

        # GRUG: Restore population caps first (needed for node validation)
        caps_data = data["population_caps"]
        if !isa(caps_data, AbstractDict)
            error("!!! FATAL: deserialize_aiml_state! population_caps is not a Dict !!!")
        end
        for (lobe_id, cap) in caps_data
            if !isa(cap, Int) && !isa(cap, Number)
                error("!!! FATAL: deserialize_aiml_state! cap for '$lobe_id' is not an integer: $cap !!!")
            end
            AIML_POPULATION_CAP[string(lobe_id)] = Int(cap)
        end

        # GRUG: Restore registry
        registry_data = data["registry"]
        if !isa(registry_data, AbstractDict)
            error("!!! FATAL: deserialize_aiml_state! registry is not a Dict !!!")
        end
        for (lobe_id, nodes_list) in registry_data
            lobe_id_str = string(lobe_id)
            AIML_REGISTRY[lobe_id_str] = Dict{String, AIMLNode}()

            if !isa(nodes_list, AbstractVector)
                @warn "[AIML] deserialize: nodes for lobe '$lobe_id_str' is not a list, skipping"
                continue
            end

            for node_data in nodes_list
                if !isa(node_data, AbstractDict)
                    @warn "[AIML] deserialize: node entry is not a Dict, skipping"
                    continue
                end

                # GRUG: Validate required fields
                required_fields = ["id", "lobe_id", "template", "strength"]
                for field in required_fields
                    if !haskey(node_data, field)
                        @warn "[AIML] deserialize: node missing '$field', skipping"
                        continue
                    end
                end

                # GRUG: Reconstruct the AIMLNode
                node_id = string(node_data["id"])
                node_lobe_id = string(node_data["lobe_id"])
                template = string(node_data["template"])
                strength = Float64(node_data["strength"])

                # GRUG: Create node with proper validation
                try
                    node = AIMLNode(node_id, node_lobe_id, template; initial_strength=strength)
                    
                    # GRUG: Restore other fields
                    node.is_grave = get(node_data, "is_grave", false)
                    node.grave_reason = get(node_data, "grave_reason", "")
                    node.voted_this_cycle = get(node_data, "voted_this_cycle", false)
                    node.fired_this_cycle = get(node_data, "fired_this_cycle", false)
                    node.gained_this_cycle = get(node_data, "gained_this_cycle", false)
                    node.strength_delta_this_cycle = get(node_data, "strength_delta_this_cycle", 0.0)
                    node.orchestration_contribution_this_cycle = get(node_data, "orchestration_contribution_this_cycle", 0.0)
                    node.created_at = get(node_data, "created_at", time())

                    AIML_REGISTRY[lobe_id_str][node_id] = node
                catch e
                    @warn "[AIML] deserialize: failed to create node '$node_id': $e"
                end
            end
        end

        # GRUG: Restore cycle counter
        cycle_val = data["cycle"]
        if !isa(cycle_val, Int) && !isa(cycle_val, Number)
            @warn "[AIML] deserialize: cycle is not an integer, defaulting to 0"
            CURRENT_CYCLE[] = 0
        else
            CURRENT_CYCLE[] = Int(cycle_val)
        end
    end

    # GRUG: Return summary for diagnostics
    total_nodes = 0
    total_live = 0
    for (lobe_id, tribe) in AIML_REGISTRY
        total_nodes += length(tribe)
        total_live += count(n -> !n.is_grave, values(tribe))
    end
    return "AIML state restored: $(length(AIML_REGISTRY)) lobes, $total_nodes nodes ($total_live alive)"
end

# ==============================================================================
# EXPORTS
# ==============================================================================

export AIMLNode, AIMLNodeError
export AIML_STRENGTH_CAP, AIML_STRENGTH_FLOOR, AIML_POPULATION_CAP_RATIO, AIML_STRENGTH_DELTA
export AIML_STOCHASTIC_GROWTH_PROB
export AIML_GRAVE_REASON_STRENGTH_ZERO
export register_lobe!, unregister_lobe!, is_lobe_registered
export get_population_cap, get_population_size, get_alive_population_size
export add_aiml_node!, get_aiml_node, has_aiml_node, remove_aiml_node!
export list_aiml_nodes, get_registered_lobes
export stochastic_aiml_growth!, is_aiml_growth_inhibited
export begin_cycle!, current_cycle
export record_fire!, record_vote!, record_orchestration_contribution!
export apply_aiml_right!, apply_aiml_wrong!
export aiml_phagy_sweep!
export compute_aiml_grave_shadow
export get_aiml_status_summary, reset_all!
export serialize_aiml_state, deserialize_aiml_state!

# GRUG say: AIML node tribes ready. Executive layer is now nodes, not blob.

end # module AIMLNodeSystem