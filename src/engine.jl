# Engine.jl
using Base.Threads: Atomic, atomic_add!, ReentrantLock
using JSON
using Random # GRUG: Need random to roll active node limits and scan modes!

# GRUG: Bring the Pattern Scanner into the cave!
# GRUG: Guard against double-include if PatternScanner already loaded by caller (e.g. test runner).
if !isdefined(@__MODULE__, :PatternScanner)
    include("patternscanner.jl")
    using .PatternScanner
end

# GRUG: Bring the Image SDF converter (JIT GPU-style image processing)!
# GRUG: Guard against double-include if ImageSDF already loaded by caller.
if !isdefined(@__MODULE__, :ImageSDF)
    include("ImageSDF.jl")
    using .ImageSDF
end

# GRUG: Bring the Eye System (edge blur, attention modulation, arousal)!
# GRUG: Guard against double-include if EyeSystem already loaded by caller.
if !isdefined(@__MODULE__, :EyeSystem)
    include("EyeSystem.jl")
    using .EyeSystem
end

# GRUG: Bring the live mutable Verb Registry (user can add verbs + synonyms at runtime)!
# GRUG: Guard against double-include if SemanticVerbs already loaded by caller.
if !isdefined(@__MODULE__, :SemanticVerbs)
    include("SemanticVerbs.jl")
    using .SemanticVerbs
end

# GRUG: Bring the AIML Node System for pattern-based responses.
# GRUG: Guard against double-include if AIMLNodeSystem already loaded by caller.
if !isdefined(@__MODULE__, :AIMLNodeSystem)
    include("AIMLNodeSystem.jl")
    using .AIMLNodeSystem
end

# GRUG: Bring the Action+Tone Predictor (pre-vote arousal tuning and confidence weighting)!
# GRUG: Guard against double-include if ActionTonePredictor already loaded by caller.
if !isdefined(@__MODULE__, :ActionTonePredictor)
    include("ActionTonePredictor.jl")
    using .ActionTonePredictor
end

# GRUG v7.21b-2: TonalJudge — token bag + common-sense judge that picks
# scaffold frame hints. Sits between predictor and scaffold. b-2 is
# plumbing-only (judge runs and surfaces [FRAME=...] but does not yet
# alter generate_aiml_payload — that's b-3).
if !isdefined(@__MODULE__, :TonalJudge)
    include("TonalJudge.jl")
    using .TonalJudge
end

# GRUG: Bring the Vote Orchestrator (parallel 1000-cap fire + unique Task dispatch + threshold vote picker).
# GRUG: Guard against double-include if VoteOrchestrator already loaded by caller.
if !isdefined(@__MODULE__, :VoteOrchestrator)
    include("VoteOrchestrator.jl")
    using .VoteOrchestrator
end

# GRUG: RelationalJitter — per-activation zero-mean nudge on match score
# components. Loaded at package level by GrugBot420.jl; this guard lets
# engine.jl also run standalone in tests (same pattern as VoteOrchestrator).
if !isdefined(@__MODULE__, :RelationalJitter)
    include("RelationalJitter.jl")
    using .RelationalJitter
end

# GRUG: SigilRegistry — Stage 1 sigil kernel. Same defensive include pattern
# as siblings above so engine.jl runs standalone (test_comprehensive etc.)
# AND inside GrugBot420.jl (where it's already loaded by the package init).
if !isdefined(@__MODULE__, :SigilRegistry)
    include("SigilRegistry.jl")
    using .SigilRegistry
end

# GRUG: SigilPromoter — Stage 1.5a front-door input promoter. Two-layer:
# Layer 1 thesaurus canonicalization ("two plus two" -> "2 + 2"), Layer 2
# registry shape promotion ("2 + 2" -> "&n &op &n"). MUST come after
# SigilRegistry because it does `using ..SigilRegistry`.
if !isdefined(@__MODULE__, :SigilPromoter)
    include("SigilPromoter.jl")
    using .SigilPromoter
end

# GRUG: ArithmeticEngine — Stage 2 arithmetic evaluator. Reads the bindings
# that SigilPromoter stashed in task-local storage and actually COMPUTES the
# result (2+2=4, not "Execute the calculation"). MUST come after SigilPromoter
# because it does `using ..SigilPromoter`.
if !isdefined(@__MODULE__, :ArithmeticEngine)
    include("ArithmeticEngine.jl")
    using .ArithmeticEngine
end

# GRUG: InputDecomposer — v7.23 compound-query decomposition. Engine.jl
# references InputDecomposer.InputChunk in _match_to_chunks signatures, so it
# MUST be loaded before those function definitions are compiled. Same defensive
# include pattern as siblings above.
if !isdefined(@__MODULE__, :InputDecomposer)
    include("InputDecomposer.jl")
    using .InputDecomposer
end

# ==============================================================================
# FRONT-DOOR SIGIL TABLE (Stage 1.5a)
# ==============================================================================
# GRUG: One stable engine-default SigilTable shared by every scan_and_expand
# call. Built once at module init and held const so per-call promotion never
# re-allocates the table. Specimens that want to extend the registry merge
# their entries in via merge_registry! at specimen-load time; the front-door
# promoter still consults THIS table for shape predicates because it is the
# union of engine defaults plus any specimen extensions registered later.
#
# IMPORTANT: this is a SigilTable, which is mutable internally (its dicts
# grow when register_sigil! / merge_registry! is called). We treat the
# binding as const because we never reassign the variable; we only mutate
# the table in place. That matches how the matcher already treats other
# global lobe registries.
const _ENGINE_SIGIL_TABLE::SigilRegistry.SigilTable = SigilRegistry.default_registry()

# GRUG: Promotion bindings handoff. Originally task-local storage, but
# scan_and_expand runs inside a @spawn'd Task (VoteOrchestrator) while
# generate_aiml_payload runs in a DIFFERENT @spawn'd Task. Julia task-local
# storage does NOT propagate across Task boundaries, so the arithmetic
# engine could never see the bindings — it always got an empty vector.
#
# FIX: Store bindings in a module-level Ref (locked) IN ADDITION to
# task-local storage. The module-level Ref survives task boundaries.
# Task-local storage is still written for backward compat with any code
# that runs in the same task as scan_and_expand.
#
# Stage 1.5a-fix-1 adds _PROMOTION_RAW_KEY: the ORIGINAL user input string,
# preserved verbatim. ATP needs it for tone signals (caps, written-out vs
# symbolic). AIML render needs it to echo back in the user's register.
const _PROMOTION_BINDINGS_KEY::Symbol  = :grugbot420_sigil_promotion_bindings
const _PROMOTION_REWRITTEN_KEY::Symbol = :grugbot420_sigil_promotion_rewritten
const _PROMOTION_RAW_KEY::Symbol       = :grugbot420_sigil_promotion_raw

# GRUG v7.24-BUG5: Module-level promotion bindings that survive Task boundaries.
# scan_and_expand writes these; generate_aiml_payload reads them. The
# task-local path is a dead end because the orchestrator runs in a
# different @spawn'd Task than the scanner.
const _GLOBAL_PROMOTION_BINDINGS::Base.RefValue{Vector{SigilPromoter.SigilBinding}} = Ref(SigilPromoter.SigilBinding[])
const _GLOBAL_PROMOTION_REWRITTEN::Base.RefValue{String} = Ref("")
const _GLOBAL_PROMOTION_RAW::Base.RefValue{String} = Ref("")
const _GLOBAL_PROMOTION_LOCK::ReentrantLock = ReentrantLock()

# GRUG v8.1: Time orientation — same pattern as promotion bindings.
# scan_and_expand writes; generate_aiml_payload reads across Task boundaries.
const _TIME_ORIENTATION_KEY::Symbol = :grugbot420_time_orientation
const _GLOBAL_TIME_ORIENTATION::Base.RefValue{Tuple{String,Dict{String,Any}}} = Ref(("none", Dict{String,Any}()))

"""
    current_promotion_bindings() -> Vector{SigilPromoter.SigilBinding}

Return the bindings produced by the most recent `scan_and_expand` call.
Reads from the module-level Ref first (survives Task boundaries), then
falls back to task-local storage for backward compat.
"""
function current_promotion_bindings()::Vector{SigilPromoter.SigilBinding}
    # GRUG v7.24-BUG5: Prefer module-level Ref — it survives @spawn.
    global_bindings = lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_PROMOTION_BINDINGS[]
    end
    if !isempty(global_bindings)
        return global_bindings
    end
    # Fallback: task-local (for code running in same task as scan_and_expand)
    val = get(task_local_storage(), _PROMOTION_BINDINGS_KEY, nothing)
    isnothing(val) && return SigilPromoter.SigilBinding[]
    if !(val isa Vector{SigilPromoter.SigilBinding})
        error("FATAL: task-local promotion bindings have wrong type: $(typeof(val))")
    end
    return val
end

"""
    current_promotion_rewritten() -> Union{String,Nothing}

Return the rewritten input string from the most recent `scan_and_expand`
call. Reads from the module-level Ref first, then falls back to task-local.
"""
function current_promotion_rewritten()::Union{String,Nothing}
    global_rewritten = lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_PROMOTION_REWRITTEN[]
    end
    if !isempty(global_rewritten)
        return global_rewritten
    end
    return get(task_local_storage(), _PROMOTION_REWRITTEN_KEY, nothing)
end

"""
    current_promotion_raw() -> Union{String,Nothing}

Return the ORIGINAL user input string from the most recent
`scan_and_expand` call on the current task, or `nothing` if no promotion
has run on this task. This is the verbatim input — caps, whitespace,
word-vs-digit, all preserved.

Stage 1.5a-fix-1 added this so:
  - ATP can read user tone signals that promotion strips ("WHAT IS 2+2"
    is angrier than "what is two plus two").
  - AIML render can echo back in the user's register ("two plus two" vs
    "2 + 2"), making replies feel coherent rather than alien.
  - Telemetry can show before/after for diff'ing promotion behaviour.

Pair with `current_promotion_bindings()`: each binding's `.surface` field
gives you the user's raw token for that capture, and `.raw_position`
indexes into the raw token stream.
"""
function current_promotion_raw()::Union{String,Nothing}
    return get(task_local_storage(), _PROMOTION_RAW_KEY, nothing)
end

"""
    current_time_orientation() -> Tuple{String,Dict{String,Any}}

Return the time orientation extracted from the most recent `scan_and_expand`
call. Returns (orientation_string, metadata_dict). Orientation is one of
"past", "present", "future", or "none" when no time sigil was detected.

Reads from module-level Ref first (survives Task boundaries), then falls
back to task-local storage.
"""
function current_time_orientation()::Tuple{String,Dict{String,Any}}
    global_orient = lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_TIME_ORIENTATION[]
    end
    if global_orient[1] != "none"
        return global_orient
    end
    return get(task_local_storage(), _TIME_ORIENTATION_KEY, ("none", Dict{String,Any}()))
end

# ==============================================================================
# SENSORY CONVERSION (TEXT TO SIGNAL)
# ==============================================================================

"""
Converts text into a bounded vector of floats for pattern matching.
"""
function words_to_signal(text::String)::Vector{Float64}
    tokens = split(lowercase(strip(text)))
    if isempty(tokens)
        error("!!! FATAL: Grug cannot turn empty wind into number rocks! !!!")
    end
    
    signal = Float64[]
    for tok in tokens
        # GRUG FIX 2.1: Hash Normalization!
        # hash() returns UInt64. If Grug divide by Int max, Grug lose half the numbers!
        # Grug divide by UInt64 max to get full [0.0 to 1.0] range. 
        # No abs() needed, UInt64 rock is always positive!
        val = Float64(hash(tok)) / Float64(typemax(UInt64))
        push!(signal, val)
    end
    
    return signal
end

# ==============================================================================
# RELATIONAL CHUNKER & DIALECTICAL MATCHER
# ==============================================================================

struct RelationalTriple
    subject::String
    relation::String
    object::String
end

# GRUG: Verb sets are now LIVE and mutable! They live in SemanticVerbs module.
# Old static const rocks are gone. Grug call get_all_verbs() on every extraction loop.
# User can /addVerb, /addRelationClass, /addSynonym at runtime — takes effect immediately.
#
# GRUG: LOAD-TIME SNAPSHOTS — These three const sets capture the DEFAULT verbs at startup.
# They are NOT live. External code (tests, diagnostics) may read them for the initial defaults.
# For live verb matching inside extract_relational_triples(), always call get_all_verbs()!
# These exist only so downstream code that imported them before the live registry existed
# does not break. Do NOT use them for new matching logic.
const CAUSAL_VERBS   = SemanticVerbs.get_verbs_in_class("causal")    # snapshot at load time
const SPATIAL_VERBS  = SemanticVerbs.get_verbs_in_class("spatial")   # snapshot at load time
const TEMPORAL_VERBS = SemanticVerbs.get_verbs_in_class("temporal")  # snapshot at load time

"""
rewrite_passive_mission(input::String)::String

GRUG: Rewrite passive voice constructs to active voice.
"X was Y by Z" → "Z Y X". Used to normalize mission text before scanning.
Throws on empty input — NO SILENT FAILURES.
"""
function rewrite_passive_mission(input::String)::String
    if strip(input) == ""
        error("!!! FATAL: rewrite_passive_mission got empty input! Cannot rewrite empty air! !!!")
    end
    return replace(input, r"\b(\w+)\s+was\s+(\w+)\s+by\s+(\w+)\b"i => s"\3 \2 \1")
end

"""
# GRUG DOC 2.2: Adjacency Assumption Limitation!
# Grug look only at rocks right next to the verb (tokens[i-1], tokens[i+1]).
# This breaks if user uses big compound nouns or punctuation! 
# Future Grug need better chunker, but for now, we just skip bad boundary rocks safely.
"""
function extract_relational_triples(input::String)::Vector{RelationalTriple}
    # GRUG: Step 1 - Normalize synonyms BEFORE any other processing.
    # "triggers" -> "causes", "precede" -> "precedes", etc. User-defined at runtime.
    # This runs on token boundaries so partial words are never corrupted.
    synonym_normalized = SemanticVerbs.normalize_synonyms(input)

    clean_input = rewrite_passive_mission(synonym_normalized)
    tokens = split(lowercase(clean_input))
    
    if isempty(tokens)
        error("!!! FATAL: Grug found no tokens after split. Something wrong with input! !!!")
    end

    triples = RelationalTriple[]

    # GRUG v7.21c-5: noun-question surface forms.
    # `what is fire` already works because `is` is a relational verb. But
    # `tell me about fire` previously produced User Triples: None: `tell` is a
    # query/tone marker, not a semantic relation, and `about` is a preposition.
    # That let the built-in generic `tell me` node beat noun-specific aliases.
    # Preserve the simple adjacency extractor, but first add explicit query
    # relations for common noun-question surfaces so noun-description nodes get
    # the same lock-in as `what is <noun>`.
    for i in 1:length(tokens)
        tok = String(tokens[i])
        if tok == "tell"
            # tell me about fire / tell about fire
            if i + 3 <= length(tokens) && String(tokens[i+1]) == "me" && String(tokens[i+2]) == "about"
                obj = String(tokens[i+3])
                !isempty(obj) && push!(triples, RelationalTriple("tell", "about", obj))
            elseif i + 2 <= length(tokens) && String(tokens[i+1]) == "about"
                obj = String(tokens[i+2])
                !isempty(obj) && push!(triples, RelationalTriple("tell", "about", obj))
            end
        elseif tok == "describe" && i + 1 <= length(tokens)
            obj = String(tokens[i+1])
            !isempty(obj) && push!(triples, RelationalTriple("describe", "targets", obj))
        elseif tok == "about" && i > 1 && i < length(tokens) && String(tokens[i-1]) == "what"
            obj = String(tokens[i+1])
            !isempty(obj) && push!(triples, RelationalTriple("what", "about", obj))
        end
    end

    # GRUG QoL FIX: Need at least 3 rocks to make a (Subject, Verb, Object) gear!
    if length(tokens) < 3
        return triples
    end

    try
        for (i, tok) in enumerate(tokens)
            if tok in SemanticVerbs.get_all_verbs()
                # GRUG: Boundary check so Grug does not reach out of cave and crash.
                if i > 1 && i < length(tokens)
                    subj = String(tokens[i-1])
                    obj  = String(tokens[i+1])
                    
                    # GRUG FIX 2.2: Make sure subject and object are real rocks, not empty wind!
                    if !isempty(subj) && !isempty(obj)
                        push!(triples, RelationalTriple(subj, tok, obj))
                    end
                end
            end
        end
    catch e
        rethrow(e)
    end

    if isempty(triples)
        # GRUG QoL FIX: User speaking without relational verbs is not a machine failure!
        # It just means no dialectical gears to align. Return empty basket safely!
        return triples
    end

    return triples
end

"""
extract_dynamic_relational_triples(input::String, scan_mode::Int)::Vector{RelationalTriple}

GRUG: Dynamic relational extraction for complex inputs (high-res scan mode).
When scan_mode >= 3 (high-res), this performs more sophisticated extraction:
  - Captures compound subjects/objects across multiple tokens
  - Handles nested relations (e.g., "A causes B which causes C")
  - Detects implicit relations through conjunctions and prepositions
  - Extracts causal chains and temporal sequences
  - Handles multiple clauses with proper scope

This follows the "wave" of complexity - if pattern scan goes high-res,
relational extraction should too. For simple inputs (scan_mode < 3),
falls back to basic extract_relational_triples() for efficiency.

Throws on empty input - NO SILENT FAILURES.
"""
function extract_dynamic_relational_triples(input::String, scan_mode::Int)::Vector{RelationalTriple}
    if strip(input) == ""
        error("!!! FATAL: extract_dynamic_relational_triples got empty input! Cannot extract relations from empty air! !!!")
    end
    
    # GRUG: For simple inputs, use basic extraction (efficiency)
    if scan_mode < 3
        return extract_relational_triples(input)
    end
    
    # GRUG: High-res mode - perform sophisticated extraction
    triples = RelationalTriple[]
    
    # Step 1: Normalize synonyms first
    synonym_normalized = SemanticVerbs.normalize_synonyms(input)
    clean_input = rewrite_passive_mission(synonym_normalized)
    tokens = split(lowercase(clean_input))
    
    if isempty(tokens)
        error("!!! FATAL: Grug found no tokens after split. Something wrong with input! !!!")
    end
    
    if length(tokens) < 3
        return triples
    end
    
    try
        # GRUG: Get all live verbs for matching
        all_verbs = SemanticVerbs.get_all_verbs()
        
        # GRUG: Track for compound subject/object construction
        i = 1
        while i <= length(tokens)
            tok = tokens[i]
            
            if tok in all_verbs
                # GRUG: Extract compound subject (look backward)
                subj_parts = String[]
                j = i - 1
                while j >= 1
                    candidate = String(tokens[j])
                    # Stop at verb or conjunction boundary
                    if candidate in all_verbs || candidate in ["and", "or", "but", "which", "that", "who", "whose"]
                        break
                    end
                    pushfirst!(subj_parts, candidate)
                    j -= 1
                end
                subject = join(subj_parts, " ")
                
                # GRUG: Extract compound object (look forward)
                obj_parts = String[]
                j = i + 1
                while j <= length(tokens)
                    candidate = String(tokens[j])
                    # Stop at verb boundary
                    if candidate in all_verbs
                        break
                    end
                    push!(obj_parts, candidate)
                    j += 1
                end
                object = join(obj_parts, " ")
                
                # GRUG: Add triple if valid
                if !isempty(subject) && !isempty(object)
                    push!(triples, RelationalTriple(subject, tok, object))
                    
                    # GRUG: High-res feature - detect nested relations via "which" clause
                    # e.g., "A causes B which causes C" -> extract (A causes B) and (B causes C)
                    if "which" in obj_parts || "that" in obj_parts
                        which_idx = findfirst(x -> x in ["which", "that"], obj_parts)
                        if !isnothing(which_idx) && which_idx < length(obj_parts)
                            # Look for verb after "which/that"
                            for k in (which_idx + 1):length(obj_parts)
                                if obj_parts[k] in all_verbs && k < length(obj_parts)
                                    nested_obj = join(obj_parts[(k+1):end], " ")
                                    if !isempty(nested_obj)
                                        # Create nested relation: subject of clause verb -> object
                                        # The clause subject is the compound object minus the which/that part
                                        clause_subj = join(obj_parts[1:(which_idx-1)], " ")
                                        if !isempty(clause_subj)
                                            push!(triples, RelationalTriple(clause_subj, obj_parts[k], nested_obj))
                                        end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
                
                # Skip tokens we've already processed
                i += max(1, length(obj_parts))
            else
                i += 1
            end
        end
        
    catch e
        rethrow(e)
    end
    
    if isempty(triples)
        # GRUG QoL FIX: No relations found is not a failure
        return triples
    end
    
    return triples
end

"""
# GRUG DOC 2.3 & 2.7: Match Score expectations!
# If node demands a relation user doesn't have, Grug return Sentinel -9999.0!
# Normal match scores add up! Score can easily exceed 1.0 (sometimes 2.0+). 
# When added to PatternScanner confidence, total confidence can be 3.0+. 
# This is expected! High score means BIG ROCK.
"""
function evaluate_relational_dialectics(
    user_triples::Vector{RelationalTriple}, 
    node_triples::Vector{RelationalTriple},
    required_relations::Vector{String},
    relation_weights::Dict{String, Float64}
)::Tuple{Float64, Bool}

    if isempty(node_triples)
        return (0.0, false)
    end

    is_antimatch = false
    match_score = 0.0
    orthogonal_penalty = 0.0

    # GRUG v7.21: Check NONJITTER tag ONCE up front. The tag lives in
    # required_relations (see src/engine.jl §"PER-NODE NONJITTER TAG"), so
    # we already have it in hand — no extra field, no extra lookup, no lock.
    # If set, every RelationalJitter.jitter_* call below collapses into the
    # identity function so the node returns bit-stable relational scores.
    # NOTE: we do NOT check required_relations against user_rels for the
    # NONJITTER tag — it's a behavioral flag, not a required semantic relation,
    # so the user never needs to "supply" it. The hard-requirement loop below
    # already scans required_relations for user-rel membership; we MUST make
    # sure the NONJITTER string is not treated as a missing semantic relation.
    # Implementation: skip the tag inside the membership check.
    nonjitter = NONJITTER_TAG in required_relations

    # GRUG v7.55: Expand any relation sigils in required_relations before
    # checking. If a required relation is "&causes" and the sigil expands to
    # ["causes","produces","creates"], then the user supplying ANY of those
    # satisfies the requirement.
    if !isempty(required_relations)
        user_rels = Set([t.relation for t in user_triples])
        for req in required_relations
            req == NONJITTER_TAG && continue
            # GRUG v7.55: Expand relation sigil if present.
            req_alternatives = SigilRegistry.expand_relation_if_sigil(_ENGINE_SIGIL_TABLE, req)
            satisfied = any(alt -> alt in user_rels, req_alternatives)
            if !satisfied
                return (-9999.0, false)
            end
        end
    end

    # GRUG: Per-activation jitter — each contribution below gets a tiny
    # zero-mean nudge via RelationalJitter.jitter_score. The jitter is
    # symmetric so repeated activations snap back to the deterministic
    # match score in expectation; any single activation just sees a nudge
    # that can tip exact ties toward weaker neighbors. See RelationalJitter.jl.
    #
    # v7.21 NONJITTER HONOR: if the incoming required_relations carries the
    # NONJITTER tag, every jitter_* call becomes identity. We pre-select the
    # callable once instead of branching inside the hot double-loop so the
    # branch-predictor sees a single stable pattern per activation.
    jitter_w = nonjitter ? identity : RelationalJitter.jitter_weight
    jitter_s = nonjitter ? identity : RelationalJitter.jitter_score

    for ut in user_triples
        for nt in node_triples
            # GRUG v7.55: Expand node triple's relation if it's a sigil reference.
            # Dynamic relational: (subj, &causes, obj) matches (subj, causes, obj)
            # OR (subj, produces, obj) OR any alternative in the sigil's expansion.
            nt_rel_alternatives = SigilRegistry.expand_relation_if_sigil(_ENGINE_SIGIL_TABLE, nt.relation)
            relation_match = any(alt -> ut.relation == alt, nt_rel_alternatives)

            # GRUG: Weight itself gets the first nudge — same bullseye every
            # activation otherwise. jitter_weight is the sign-preserving wrapper.
            # For dynamic relationals, look up weight by:
            #   1. User's actual relation verb (always concrete)
            #   2. The sigil reference name (e.g. "&causes")
            #   3. Any expansion alternative that has a weight
            #   4. Default 1.0
            weight = if !isempty(nt_rel_alternatives) && nt_rel_alternatives[1] != nt.relation
                # Dynamic relational — nt.relation is "&name" form
                w = get(relation_weights, ut.relation, nothing)
                if !isnothing(w)
                    jitter_w(w)
                else
                    # Try the sigil name itself as a weight key (e.g. "&causes")
                    w2 = get(relation_weights, nt.relation, nothing)
                    if !isnothing(w2)
                        jitter_w(w2)
                    else
                        # Try each alternative until one has a weight
                        found = nothing
                        for alt in nt_rel_alternatives
                            w3 = get(relation_weights, alt, nothing)
                            if !isnothing(w3)
                                found = w3
                                break
                            end
                        end
                        jitter_w(something(found, 1.0))
                    end
                end
            else
                jitter_w(get(relation_weights, ut.relation, 1.0))
            end

            if relation_match
                if ut.subject == nt.object && ut.object == nt.subject
                    match_score -= jitter_s(2.0 * weight)
                    is_antimatch = true
                elseif ut.subject == nt.subject && ut.object == nt.object
                    match_score += jitter_s(2.0 * weight)
                elseif ut.subject == nt.subject || ut.object == nt.object
                    match_score += jitter_s(1.0 * weight)
                elseif ut.object == nt.subject || ut.subject == nt.object
                    # GRUG v7.57: Cross-field partial match. When the user says
                    # "i make fire" and the node triple is (fire, &causal, warmth),
                    # the user's object "fire" matches the node's subject "fire".
                    # This is a meaningful semantic overlap — the user's query is
                    # ABOUT the same concept the node relates from. Use a lower
                    # weight (0.7) than same-field partial (1.0) to differentiate
                    # direct ownership from associative overlap, but high enough
                    # to disambiguate cross-lobe confusion (e.g. fire vs music).
                    match_score += jitter_s(0.7 * weight)
                else
                    orthogonal_penalty += jitter_s(0.5 * weight)
                end
            end
        end
    end

    # GRUG COHERENCE FIX: Don't let large user paragraphs nuke perfectly matched triples!
    # GRUG: Final dampener also gets a jitter so the 0.1 floor and the 0.1
    # penalty multiplier aren't deterministic constants. Sentinel (-9999.0)
    # and true zero are handled internally by jitter_value and pass through
    # untouched — the hard-requirement-miss contract is preserved.
    # v7.21: NONJITTER collapses this final jitter to identity as well.
    if match_score > 0
        final_score = max(0.1, match_score - jitter_s(orthogonal_penalty * 0.1))
    else
        final_score = match_score - orthogonal_penalty
    end

    return (final_score, is_antimatch)
end

# ==============================================================================
# STRENGTH CAP & APOPTOSIS CONSTANTS
# ==============================================================================

# GRUG: Strength lives in [0.0, STRENGTH_CAP]. At 0.0, node is marked grave.
# At STRENGTH_CAP, node cannot grow stronger (apoptosis ceiling / stratification).
const STRENGTH_CAP   = 10.0
const STRENGTH_FLOOR = 0.0

# GRUG: Slow-response telemetry threshold. v7.21c-5 side-process isolation:
# exceeding this threshold logs diagnostics only; it does not grave voters.
# 24-hour ledger clears daily. Time in seconds.
const SLOW_NODE_THRESHOLD_SECONDS = 5.0
const LEDGER_CLEAR_INTERVAL       = 86400.0  # GRUG: 24 hours in seconds

# GRUG: Max neighbors before node is UNLINKABLE (apoptosis of link capacity).
# DEPRECATED as a hard cap — kept as a fallback default. The real cap is rolled
# per-node at construction time in [LATCH_PARTNER_CAP_MIN, LATCH_PARTNER_CAP_MAX]
# and stored on Node.max_neighbors. This randomized cap stops every node from
# saturating at the same uniform link count and lets dense hubs / sparse satellites
# emerge organically.
const MAX_NEIGHBORS = 4
const LATCH_PARTNER_CAP_MIN = 8
const LATCH_PARTNER_CAP_MAX = 16

# GRUG: Minimum map size before automatic neighbor latching is allowed.
# Below this threshold, the map is too small for token overlap similarity to be
# statistically meaningful. Latching on a tiny map creates junk topology — two
# unrelated nodes link just because they're the only ones available.
# Above NODE_LATCH_THRESHOLD, the specimen has enough diversity that overlap
# similarity actually reflects semantic proximity. THEN latch kicks in.
const NODE_LATCH_THRESHOLD = 1000

# ==============================================================================
# CORE ENGINE STRUCTURES
# ==============================================================================

mutable struct Node
    id::String
    pattern::String
    signal::Vector{Float64}          # GRUG: Number rocks for Pattern Scanner!
    action_packet::String 
    json_data::Dict{String, Any}
    drop_table::Vector{String}
    throttle::Float64
    relational_patterns::Vector{RelationalTriple}
    required_relations::Vector{String}
    relation_weights::Dict{String, Float64}

    # GRUG NEW: Strength system (apoptosis + stratification)
    strength::Float64                # GRUG: Node power [0.0, STRENGTH_CAP]

    # GRUG NEW: Is this node an image node? (pattern is SDF binary, not text)
    is_image_node::Bool

    # GRUG v7.49: Is this node an anti-match node? (pattern-activated confidence drain,
    # never enters vote pool, no strength dynamics, no stage competition)
    is_antimatch_node::Bool

    # GRUG NEW: Neighbor linking (max neighbors rolled per-node 8-16 before UNLINKABLE)
    neighbor_ids::Vector{String}
    is_unlinkable::Bool              # GRUG: True when neighbor_ids reaches max_neighbors
    max_neighbors::Int               # GRUG: Per-node cap, rolled in [LATCH_PARTNER_CAP_MIN, LATCH_PARTNER_CAP_MAX]

    # GRUG NEW: Grave tracking (strength hits 0 OR slow response average)
    is_grave::Bool
    grave_reason::String             # GRUG: "STRENGTH_ZERO", "GRAVED-SLOW", or ""

    # GRUG NEW: Big-O response time ledger (clears every 24 hours)
    response_times::Vector{Float64}  # GRUG: Rolling list of response times (seconds)
    ledger_last_cleared::Float64     # GRUG: Unix timestamp of last 24hr clear

    # GRUG NEW: Hopfield cache key (hash of pattern, used for familiar input lookup)
    hopfield_key::UInt64

    # GRUG NEW: Contributed to output this cycle (for /right and /wrong feedback)
    fired_this_cycle::Bool           # GRUG: True if node's vote was used by AIML orchestrator
    voted_this_cycle::Bool           # GRUG: True if node voted (may or may not have contributed)
    gained_this_cycle::Bool          # GRUG: True if node gained strength this cycle
    strength_delta_this_cycle::Float64  # GRUG: Strength change this cycle (for over-compensation penalty)
end

struct Vote
    node_id::String
    action::String
    confidence::Float64
    negatives::Vector{String}
    user_triples::Vector{RelationalTriple}
    node_triples::Vector{RelationalTriple}
    antimatch::Bool
    # ---- v7.23 multipart fields (additive, default-safe) ------------------
    # GRUG: empty group_id means "this vote is on its own". Same node may emit
    # several votes that all carry the SAME non-empty group_id; AIML treats
    # them as one objective. Role distinguishes the locked-in claim
    # (:primary) from the supports (:support). :singleton is the default
    # marker for the historical case (no multipart).
    multipart_group::String
    multipart_role::Symbol
    # ---- v7.23 chunked affinity field -------------------------------------
    # GRUG: which input chunks this vote resolved. Empty = old behavior
    # (unchunked input, or vote was created before chunk-aware pipeline).
    # When chunked affinities are active, each vote knows which part(s)
    # of the input it matched — like a place cell that fires for a specific
    # location, not "the environment." MultipartOrchestrator uses this for
    # grouping instead of the multipart_group tag when available.
    input_chunks::Vector{Int}
end

# GRUG: 7-arg outer constructor preserves every existing call site.
# Supplies "" / :singleton / empty Int[] for the new fields. Old code is bit-exact.
function Vote(node_id::String,
              action::String,
              confidence::Float64,
              negatives::Vector{String},
              user_triples::Vector{RelationalTriple},
              node_triples::Vector{RelationalTriple},
              antimatch::Bool)
    return Vote(node_id, action, confidence, negatives,
                user_triples, node_triples, antimatch,
                "", :singleton, Int[])
end

# GRUG: 9-arg constructor for multipart_group + multipart_role (pre-chunked-affinity).
# Supplies empty Int[] for input_chunks. Preserves existing cast_vote_with_group sites.
function Vote(node_id::String,
              action::String,
              confidence::Float64,
              negatives::Vector{String},
              user_triples::Vector{RelationalTriple},
              node_triples::Vector{RelationalTriple},
              antimatch::Bool,
              multipart_group::String,
              multipart_role::Symbol)
    return Vote(node_id, action, confidence, negatives,
                user_triples, node_triples, antimatch,
                multipart_group, multipart_role, Int[])
end

const NODE_MAP  = Dict{String, Node}()
const COMMANDS  = Dict{String, Function}()
const NODE_LOCK = ReentrantLock()
const ID_COUNTER = Atomic{Int}(0)

# ==============================================================================
# HOPFIELD FAMILIAR INPUT CACHE
# ==============================================================================

# GRUG: When a highly familiar input comes in, skip the full scan.
# Map: input_hash -> Vector of node_ids that fired at high confidence for this input.
# This is the Hopfield precache: known inputs get precached node IDs fired directly.
const HOPFIELD_CACHE      = Dict{UInt64, Vector{String}}()
const HOPFIELD_CACHE_LOCK = ReentrantLock()

# GRUG: Confidence threshold above which a result gets stored in Hopfield cache.
const HOPFIELD_STORE_THRESHOLD   = 1.5
# GRUG: How many times an input must repeat before it's considered "familiar" enough
# to use the Hopfield cache instead of a full scan.
const HOPFIELD_HIT_COUNT_MIN     = 2
const HOPFIELD_HIT_COUNTS        = Dict{UInt64, Int}()

# ============================================================================
# HOPFIELD CACHE FUNCTIONS - RE-ENABLED for test compatibility
# ============================================================================
"""
hopfield_input_hash(input_text::String)::UInt64

GRUG: Compute a stable hash for a normalized input string.
Used as the key for Hopfield cache lookups.
"""
function hopfield_input_hash(input_text::String)::UInt64
    if strip(input_text) == ""
        error("!!! FATAL: hopfield_input_hash got empty input! !!!")
    end
    # GRUG: Normalize before hashing (lowercase, strip, collapse spaces)
    normalized = join(split(lowercase(strip(input_text))), " ")
    return hash(normalized)
end

"""
hopfield_lookup(input_hash::UInt64)::Union{Vector{String}, Nothing}

GRUG: Check if this input hash is familiar enough for Hopfield fast-path.
Returns cached node_ids if familiar, Nothing if not cached or not yet familiar.
"""
function hopfield_lookup(input_hash::UInt64)::Union{Vector{String}, Nothing}
    return lock(HOPFIELD_CACHE_LOCK) do
        hit_count = get(HOPFIELD_HIT_COUNTS, input_hash, 0)
        if hit_count >= HOPFIELD_HIT_COUNT_MIN && haskey(HOPFIELD_CACHE, input_hash)
            return HOPFIELD_CACHE[input_hash]
        end
        return nothing
    end
end

"""
hopfield_record!(input_hash::UInt64, node_ids::Vector{String})

GRUG: Record that these node_ids fired for this input hash at high confidence.
Increment hit counter. Once hit count reaches HOPFIELD_HIT_COUNT_MIN, future
lookups will use the cache instead of doing a full scan.
"""
function hopfield_record!(input_hash::UInt64, node_ids::Vector{String})
    if isempty(node_ids)
        # GRUG: Nothing to cache. Not a failure, just skip.
        return
    end
    lock(HOPFIELD_CACHE_LOCK) do
        HOPFIELD_CACHE[input_hash] = node_ids
        HOPFIELD_HIT_COUNTS[input_hash] = get(HOPFIELD_HIT_COUNTS, input_hash, 0) + 1
    end
end

# ==============================================================================
# v7.20 — PER-NODE NONJITTER TAG
# ==============================================================================
# GRUG: Some rocks must stay still. Jitter good for most rocks (snap-back breath
# keeps system alive and adaptive), but anchor rocks, calibration rocks, and
# canonical-form rocks get broken if they wiggle. So grug give those rocks a tag.
# If node carries NONJITTER tag in its required_relations, jitter systems skip it.
#
# Storage: tag lives as the string "NONJITTER" inside node.required_relations.
# This means:
#   - No struct change needed.
#   - Tag survives specimen save/restore for free (required_relations already serialized).
#   - Node creation kwarg `required_relations=["NONJITTER"]` just works.
#   - Runtime tag add/remove is a plain Vector{String} push/filter operation.
#
# Honoring: helpers that apply bounded-snap-back jitter check is_nonjitter(node)
# and skip the jitter call when the tag is present. The tag is orthogonal to the
# global _JITTER_ENABLED toggle in RelationalJitter — a NONJITTER node is silent
# even when global jitter is on.
# ==============================================================================

const NONJITTER_TAG = "NONJITTER"

"""
    is_nonjitter(node::Node)::Bool

GRUG: Rock carry NONJITTER tag? If yes, jitter systems must leave rock alone.
Pure check, no mutation, no allocation. Safe to call from hot paths.
"""
function is_nonjitter(node::Node)::Bool
    # GRUG: required_relations is a plain Vector{String}. `in` is O(n) but
    # required_relations is almost always small (≤ 4 entries), so this is
    # effectively constant-time. No lock needed — node.required_relations
    # is a direct field read and this function is nominally called from the
    # same thread that holds a reference to the node.
    return NONJITTER_TAG in node.required_relations
end

"""
    is_time_node(node::Node)::Bool

GRUG v7.56a: Returns true if this node is a time node. Time nodes are regular
nodes that carry `time_node=true` in their json_data. They cluster into
time-node-only groups. No special code path — pure label gate.
"""
function is_time_node(node::Node)::Bool
    return get(node.json_data, "time_node", false) === true
end

# ── GRUG v8.1: TIME COHERENCE SIGNALING ──────────────────────────────
# Time sigils (&now, &before, &next) are :macro/:tone entries in the
# sigil registry. When the promoter rewrites a temporal word (e.g. "now"
# → "&now"), the resulting SigilBinding carries the sigil entry's params
# dict, which includes :orientation and :vote_flags. These functions
# extract that orientation from the current promotion bindings and make
# it available to the AIML payload generator and hippocampal lever.
#
# The three orientations and their vote flags:
#   past    → reflect=true,  assess=false, project=false
#   present → reflect=false, assess=true,  project=false
#   future  → reflect=false, assess=false, project=true
#
# Time nodes that fire during a cascade read these flags to determine
# which AIML reasoning mode to activate. The hippocampal lever uses
# orientation to decide whether to pull past context (reflect), assess
# current state (assess), or project forward (project).

const TIME_SIGIL_NAMES = Set{String}(["now", "before", "next"])

"""
    extract_time_orientation(bindings) -> (orientation::String, vote_flags::Dict)

GRUG v8.1: Scan promotion bindings for time sigil entries. Returns the
orientation and vote_flags from the FIRST time sigil binding found. If no
time sigil binding is present, returns ("none", empty Dict). Multiple time
sigils in one input are possible but the first one wins (the system orients
toward the first temporal signal the user sends).
"""
function extract_time_orientation(bindings::Vector{SigilPromoter.SigilBinding})::Tuple{String,Dict{String,Any}}
    for b in bindings
        if b.name in TIME_SIGIL_NAMES
            # Look up the sigil entry to read params
            entry = SigilRegistry.lookup_sigil(_ENGINE_SIGIL_TABLE, b.name)
            if entry.params !== nothing
                orientation = get(entry.params, "orientation", "none")
                vote_flags  = get(entry.params, "vote_flags", Dict{String,Any}())
                signal_list = get(entry.params, "signal", String[])
                return (orientation, Dict{String,Any}(
                    "orientation" => orientation,
                    "vote_flags"  => vote_flags,
                    "signal"      => signal_list,
                    "sigil_name"  => b.name,
                    "surface"     => b.surface
                ))
            end
        end
    end
    return ("none", Dict{String,Any}())
end

"""
    has_time_orientation(bindings) -> Bool

GRUG v8.1: Returns true if any binding in the list is a time sigil.
"""
function has_time_orientation(bindings::Vector{SigilPromoter.SigilBinding})::Bool
    return any(b -> b.name in TIME_SIGIL_NAMES, bindings)
end

"""
    time_vote_flags(orientation_data) -> Dict

GRUG v8.1: Extract just the vote_flags from time orientation data.
Returns empty Dict if no time orientation is present.
"""
function time_vote_flags(orientation_data::Dict{String,Any})::Dict{String,Any}
    return get(orientation_data, "vote_flags", Dict{String,Any}())
end

"""
    set_nonjitter!(node::Node)

GRUG: Tag rock as NONJITTER. Idempotent — calling twice leaves the vector
with exactly one tag, not two. NO SILENT FAILURE: if node is nothing, caller
gets a MethodError from Julia's dispatch, not a quiet no-op.
"""
function set_nonjitter!(node::Node)
    if !is_nonjitter(node)
        push!(node.required_relations, NONJITTER_TAG)
    end
    return node
end

"""
    clear_nonjitter!(node::Node)

GRUG: Remove NONJITTER tag from rock. If rock did not carry the tag, this is
a no-op — but NOT a silent failure, because the function contract is
"after this call, the tag is absent", which is true either way. Returns the
node for chaining.
"""
function clear_nonjitter!(node::Node)
    if is_nonjitter(node)
        filter!(r -> r != NONJITTER_TAG, node.required_relations)
    end
    return node
end

"""
    collect_nonjitter_ids()::Set{String}

GRUG v7.21: Walk NODE_MAP under lock and return the Set of ids whose node
carries the NONJITTER tag. This is the bridge between the engine-layer tag
store (each Node's required_relations) and subsystems that only speak in
node ids — notably FullLobeScanner, which operates on a
`Dict{String, Vector{Float64}}` of features and has no access to Node
objects.

Typical usage at an orchestrator call site:

    nj_ids = collect_nonjitter_ids()
    gather_candidates!(scanner, features; nonjitter_ids=nj_ids)
    activate_candidates!(scanner, features; nonjitter_ids=nj_ids)

RETURNS: a fresh Set{String} (never nothing). Empty set if no nodes carry
the tag. Always safe to pass directly to FullLobeScanner.

PERFORMANCE: O(N) over NODE_MAP, where N is the total node count. Call
once per mission (not per candidate) and cache the result for the duration
of the scan — the tag set is stable across a single scan because NONJITTER
is not mutated from inside the scan hot path.

NO SILENT FAILURES: a missing NODE_MAP or corrupted required_relations
would surface as a normal Julia error from the iteration, not a quiet empty
set.
"""
function collect_nonjitter_ids()::Set{String}
    ids = Set{String}()
    lock(NODE_LOCK) do
        for (id, node) in NODE_MAP
            # GRUG: is_nonjitter is cheap (≤4-element membership). Whole walk
            # is O(N * avg_rels) ≈ O(N) with tiny constant.
            if is_nonjitter(node)
                push!(ids, id)
            end
        end
    end
    return ids
end

# ==============================================================================
# v7.20 — VOTE-LEVEL NONJITTER OVERRIDE
# ==============================================================================
# GRUG: Old NONJITTER was an absolute lifetime tag — once a node solidified,
# every vote it cast was bit-stable forever. New rule: the tag is a
# *baseline*, not an absolute. A solidified node's high-confidence votes stay
# bit-stable (still a "crystallized rock"), but a *low-confidence* firing
# from the same node still jitters. Why? "The solid rock is guessing" —
# you don't want to ossify a guess just because the rock is usually right.
#
# Plumbing:
#   - JITTER_CONFIDENCE_FLOOR : confidence below this forces jitter through.
#   - jitter_allowed_for(node, conf) : single point of truth; both the node
#     tag and the per-firing confidence are consulted.
#
# Callsite contract:
#   * Node-only check (no confidence available yet, e.g. relational weight
#     jitter at growth time): keep using is_nonjitter(node).
#   * Confidence-bearing check (scan output, vote relay): use
#     jitter_allowed_for(node, conf).
#
# Why a constant, not a config? The floor lives at the "this is a guess"
# threshold — same conceptual line that CONTEXT_TRUST_FLOOR draws for memory
# pulls. Both should move together if at all. A constant in the engine is
# the right home; if it ever needs runtime tuning we expose a setter.
# ==============================================================================

# GRUG: A vote firing below this confidence is treated as a guess. Even on a
# solidified (NONJITTER) node, jitter still runs to avoid ossifying the
# guess. 0.50 is "I'm 50/50 on this" — anything below that is honestly
# uncertain and deserves substrate noise.
const JITTER_CONFIDENCE_FLOOR = 0.50

"""
    jitter_allowed_for(node::Node, confidence::Float64)::Bool

GRUG v7.20: Single point of truth for "should jitter run for this firing?"
Combines the node-level NONJITTER baseline with a per-firing confidence
override.

RETURNS:
  - `true`  → jitter SHOULD run (default for unsolid nodes; also for solid
              nodes when the current vote is low-confidence)
  - `false` → jitter is suppressed (solid node firing a high-confidence vote)

LOGIC:
  - Unsolid node (no NONJITTER tag): jitter always runs → return true
  - Solid node + confidence ≥ JITTER_CONFIDENCE_FLOOR: bit-stable → return false
  - Solid node + confidence < JITTER_CONFIDENCE_FLOOR: low-conf override fires
    → return true (rock is guessing, don't ossify the guess)

CONTRACT: this function is pure (no mutation, no allocation, no I/O). Safe
to call from hot paths.
"""
function jitter_allowed_for(node::Node, confidence::Float64)::Bool
    # GRUG: Fast path — unsolid nodes always jitter.
    if !is_nonjitter(node)
        return true
    end
    # GRUG: Solid node — honor the per-firing confidence override.
    return confidence < JITTER_CONFIDENCE_FLOOR
end

# ==============================================================================
# v7.22 — STRENGTH-DRIVEN SOLIDIFICATION
# ==============================================================================
# GRUG: Nodes that prove themselves stop wiggling. Simple rule:
#
#   strength >= STRENGTH_SOLIDIFY_THRESHOLD   ->  NONJITTER tag ON
#   strength <  STRENGTH_SOLIDIFY_THRESHOLD   ->  NONJITTER tag OFF
#
# The tag is the ONLY effect. All the heavy lifting for "what does NONJITTER
# do" already happened in v7.21 — every node-scoped jitter site honors the
# tag system-wide. v7.22 just automates the tag, system-wide, for all node
# types based on strength.
#
# Lifecycle:
#   - Node earns strength (bump_strength! via /right, fire-success, etc.)
#     Crosses threshold upward -> auto-solidify (NONJITTER on, logged 💎)
#   - Node loses strength (penalize_strength! via /wrong, etc.)
#     Crosses threshold downward -> auto-desolidify (NONJITTER off, logged 💧)
#   - Node climbs back up later -> re-solidifies. No frozen state — confidence
#     is always computed fresh from pattern scan, same as any other node.
#     NONJITTER only silences jitter; it does not freeze computation inputs.
#
# Why no frozen confidence? Confidence is a scan-time output derived from
# the user input against the node's pattern/triples. Freezing it would make
# the node return the same answer for DIFFERENT queries, which is wrong —
# the node should always reflect the current query. NONJITTER gives us
# repeatable, bit-stable answers for the SAME query without breaking
# responsiveness to different queries.
# ==============================================================================

const STRENGTH_SOLIDIFY_THRESHOLD = 9.0       # GRUG: 90% of STRENGTH_CAP

"""
    is_solidified(node::Node)::Bool

GRUG: Is this rock solid? A node is solidified iff it carries the NONJITTER
tag. v7.22 makes that tag a pure function of strength; callers that want
the strength predicate directly should use
`node.strength >= STRENGTH_SOLIDIFY_THRESHOLD`.

Kept separate from is_nonjitter so that future manual tag uses (e.g. a
calibration node that is tagged regardless of strength) still answer TRUE
to is_solidified — solidified just means "locked from jitter", regardless
of how the lock got there.
"""
function is_solidified(node::Node)::Bool
    return is_nonjitter(node)
end

"""
    check_solidify_threshold!(node::Node)

GRUG: Called after any strength change. Keeps the NONJITTER tag in sync
with the strength threshold:

  - strength >= threshold AND not tagged -> apply tag (solidify)
  - strength <  threshold AND tagged     -> remove tag (desolidify)

Both transitions log a line so we can see nodes crystallize and soften in
real time. No-op if already in the correct state.

NOTE: This function does NOT lock NODE_LOCK itself. Callers already hold
the lock (see bump_strength! and penalize_strength!); calling from outside
a lock is also safe because we only touch the node's required_relations
via the set/clear helpers, which are O(1) and don't race on unrelated
fields.
"""
function check_solidify_threshold!(node::Node)
    if node.strength >= STRENGTH_SOLIDIFY_THRESHOLD
        if !is_nonjitter(node)
            set_nonjitter!(node)
            println("[ENGINE] 💎 Node $(node.id) solidified (strength=$(round(node.strength, digits=2)) ≥ $(STRENGTH_SOLIDIFY_THRESHOLD)) — NONJITTER tag applied.")
        end
    else
        if is_nonjitter(node)
            clear_nonjitter!(node)
            println("[ENGINE] 💧 Node $(node.id) softened (strength=$(round(node.strength, digits=2)) < $(STRENGTH_SOLIDIFY_THRESHOLD)) — NONJITTER tag removed, jitter resumed.")
        end
    end
    return node
end

# ==============================================================================
# STRENGTH & GRAVE MANAGEMENT
# ==============================================================================

"""
bump_strength!(node::Node)

GRUG: On a coinflip, node gains strength when used. Capped at STRENGTH_CAP (apoptosis).
Coinflip means NOT every use rewards strength - only lucky ones!
"""
function bump_strength!(node::Node)
    # GRUG: 50/50 coinflip. Only winners get stronger.
    if rand() < 0.5
        lock(NODE_LOCK) do
            node.strength = min(node.strength + 1.0, STRENGTH_CAP)
        end
        # GRUG v7.22: if the bump just pushed strength across the
        # SOLIDIFY threshold, auto-apply the NONJITTER tag. Node starts
        # answering bit-stable for the same query from now on. If the
        # node was already solid, this is a no-op.
        check_solidify_threshold!(node)
    end
end

"""
penalize_strength!(node::Node)

GRUG: On /wrong feedback, node does a coinflip. If it loses, strength drops.
At 0.0, node is marked grave (negative reinforcement during generative phase).
"""
function penalize_strength!(node::Node)
    # GRUG: Coinflip. Losers get penalized. Winners escape unscathed this round.
    if rand() < 0.5
        lock(NODE_LOCK) do
            node.strength = max(node.strength - 1.0, STRENGTH_FLOOR)
            if node.strength <= STRENGTH_FLOOR && !node.is_grave
                node.is_grave    = true
                node.grave_reason = "STRENGTH_ZERO"
                println("[ENGINE] ⚰  Node $(node.id) marked GRAVE (strength -> 0).")
                # GRUG (v7.19): tell the group bookkeeper a slot opened up.
                try mark_group_grave_slot!(node.id) catch e; @warn "group slot update failed for $(node.id): $e"; end
            end
        end
        # GRUG v7.22: if the penalty just dropped strength below the
        # SOLIDIFY threshold, auto-remove the NONJITTER tag. Node resumes
        # jittering. If strength climbs back above the threshold later
        # (via future bump_strength! calls), the tag is automatically
        # re-applied. No frozen state to carry — confidence is always
        # computed fresh from pattern scan.
        check_solidify_threshold!(node)
    end
end

"""
mark_node_grave!(node::Node, reason::String)

GRUG: Explicitly mark a node as grave with a reason string.
Used for GRAVED-SLOW (big-O ledger) and STRENGTH_ZERO cases.
"""
function mark_node_grave!(node::Node, reason::String)
    if strip(reason) == ""
        error("!!! FATAL: mark_node_grave! requires a non-empty reason string! !!!")
    end
    lock(NODE_LOCK) do
        node.is_grave     = true
        node.grave_reason = reason
    end
    # GRUG (v7.19): tell the group bookkeeper a slot opened up.
    try mark_group_grave_slot!(node.id) catch e; @warn "group slot update failed for $(node.id): $e"; end
    println("[ENGINE] ⚰  Node $(node.id) marked GRAVE: [$reason].")
end

# ==============================================================================
# BIG-O RESPONSE TIME LEDGER
# ==============================================================================

"""
record_response_time!(node::Node, elapsed_seconds::Float64)

GRUG: Record a response time for this node in its big-O ledger.
Side-process isolation rule: timing telemetry must not change vote confidence
or future vote eligibility. Slow averages are logged, not auto-graved.
Ledger clears every 24 hours (LEDGER_CLEAR_INTERVAL).
"""
function mark_node_contributor!(node::Node)
    """
    Mark a node as having contributed to output this cycle.
    This enables the node for reinforcement/penalty via /right and /wrong.
    """
    node.fired_this_cycle = true
    node.voted_this_cycle = true  # Contributors also voted
end

function reset_cycle_flags!(node::Node)
    """
    Reset cycle tracking flags at the start of a new cycle.
    """
    node.fired_this_cycle = false
    node.voted_this_cycle = false
    node.gained_this_cycle = false
    node.strength_delta_this_cycle = 0.0
end

function reset_all_cycle_flags!()
    """
    Reset cycle flags for all nodes at the start of a new mission.
    """
    lock(NODE_LOCK) do
        for node in values(NODE_MAP)
            reset_cycle_flags!(node)
        end
    end
end

function record_response_time!(node::Node, elapsed_seconds::Float64)
    if elapsed_seconds < 0.0
        error("!!! FATAL: record_response_time! got negative elapsed time: $elapsed_seconds! !!!")
    end

    lock(NODE_LOCK) do
        # GRUG: Check if 24-hour window has passed. If so, wipe the ledger clean.
        now_t = time()
        if now_t - node.ledger_last_cleared >= LEDGER_CLEAR_INTERVAL
            empty!(node.response_times)
            node.ledger_last_cleared = now_t
            println("[ENGINE] 🕐  Node $(node.id) big-O ledger cleared (24hr reset).")
        end

        push!(node.response_times, elapsed_seconds)

        # GRUG: Check average response time for telemetry only.
        # v7.21c-5 side-process isolation: response-time side effects must not
        # grave nodes or alter future vote eligibility. Keep the ledger useful
        # for diagnostics, but never convert slowness into GRAVED-SLOW here.
        if !isempty(node.response_times)
            avg_time = sum(node.response_times) / length(node.response_times)
            if avg_time > SLOW_NODE_THRESHOLD_SECONDS
                println("[ENGINE] 🐢  Node $(node.id) slow telemetry only (avg: $(round(avg_time, digits=2))s > $(SLOW_NODE_THRESHOLD_SECONDS)s); not graving.")
            end
        end
    end
end

# ==============================================================================
# NEIGHBOR LINKING (MAX 4 NEIGHBORS = UNLINKABLE)
# ==============================================================================

"""
try_link_nodes!(node_a::Node, node_b::Node)::Bool

GRUG: Attempt to link two nodes as neighbors.
Fails (returns false) if either node already has its per-node max_neighbors cap
(is UNLINKABLE). Each node rolls its own cap in [LATCH_PARTNER_CAP_MIN, LATCH_PARTNER_CAP_MAX]
at construction so connectivity is heterogeneous (hub vs. satellite emergence).
On success, both nodes gain each other as neighbors.
"""
function try_link_nodes!(node_a::Node, node_b::Node)::Bool
    if node_a.id == node_b.id
        # GRUG: Node cannot be its own neighbor. That's just a mirror, not a friend!
        return false
    end

    lock(NODE_LOCK) do
        # GRUG: Check both nodes can accept new neighbors
        # GRUG (v7.19): UNLINKABLE override for grave-slot replacement.
        # If a node is UNLINKABLE but its group has has_grave_slot=true (a
        # member was just graved), allow ONE extra link to fill the empty
        # slot. The slot flag is cleared by add_to_group! when the new
        # member joins downstream of try_link_nodes! \u2014 here we only honor
        # the override at the link layer.
        a_locked = node_a.is_unlinkable
        b_locked = node_b.is_unlinkable
        if a_locked
            ga = group_for(node_a.id)
            if !isnothing(ga) && ga.has_grave_slot
                a_locked = false
            end
        end
        if b_locked
            gb = group_for(node_b.id)
            if !isnothing(gb) && gb.has_grave_slot
                b_locked = false
            end
        end
        if a_locked || b_locked
            return false
        end
        if node_a.id in node_b.neighbor_ids || node_b.id in node_a.neighbor_ids
            # GRUG: Already linked! Don't double-link.
            return false
        end

        push!(node_a.neighbor_ids, node_b.id)
        push!(node_b.neighbor_ids, node_a.id)

        # GRUG: Check if either node just hit its per-node UNLINKABLE threshold
        if length(node_a.neighbor_ids) >= node_a.max_neighbors
            node_a.is_unlinkable = true
            println("[ENGINE] 🔒  Node $(node_a.id) is now UNLINKABLE ($(node_a.max_neighbors) neighbors reached).")
        end
        if length(node_b.neighbor_ids) >= node_b.max_neighbors
            node_b.is_unlinkable = true
            println("[ENGINE] 🔒  Node $(node_b.id) is now UNLINKABLE ($(node_b.max_neighbors) neighbors reached).")
        end

        return true
    end
end

"""
find_best_latch_target(new_node::Node)::Union{String, Nothing}

GRUG: When a new node grows, it wants to latch onto the strongest similar neighbor.
Scan existing nodes for the best candidate:
  - Must NOT be UNLINKABLE (has room for another neighbor)
  - Must NOT be GRAVE
  - Must be pattern-similar (token overlap > 0)
  - Among eligible, pick the strongest one

Returns node_id of best candidate, or Nothing if no eligible nodes found.
"""
function find_best_latch_target(new_node::Node)::Union{String, Nothing}
    best_id       = nothing
    best_score    = -Inf

    lock(NODE_LOCK) do
        for (id, candidate) in NODE_MAP
            id == new_node.id  && continue  # GRUG: Skip self
            candidate.is_grave              && continue  # GRUG: No latching onto graves
            candidate.is_unlinkable         && continue  # GRUG: No room for new neighbor

            # GRUG: Compute rough token similarity between patterns
            sim = _token_overlap_similarity(new_node.pattern, candidate.pattern)
            if sim <= 0.0
                continue  # GRUG: No similarity, not a good latch target
            end

            # GRUG: Score = strength * similarity. Strongly similar nodes rank highest.
            score = candidate.strength * sim
            if score > best_score
                best_score = score
                best_id    = id
            end
        end
    end

    return best_id
end

"""
_token_overlap_similarity(p1::String, p2::String)::Float64

GRUG: Internal Jaccard-like token overlap similarity [0.0, 1.0].
Used for neighbor latching and chatter gossip decisions.
"""
function _token_overlap_similarity(p1::String, p2::String)::Float64
    if strip(p1) == "" || strip(p2) == ""
        return 0.0
    end
    t1 = Set(split(lowercase(strip(p1))))
    t2 = Set(split(lowercase(strip(p2))))
    union_size = length(union(t1, t2))
    return union_size > 0 ? Float64(length(intersect(t1, t2))) / Float64(union_size) : 0.0
end

# ==============================================================================
# RELATIONAL FIRE SYSTEM (NODE ATTACHMENTS)
# ==============================================================================

# GRUG: /nodeAttach lets user bolt up to 4 nodes onto a target node.
# When the target fires (selected for voting), each attached node does a
# strength-biased coinflip. Winners fire too with a pre-baked confidence.
# This is RELATIONAL FIRE: nodes ride on the coattails of a parent node's
# activation, gated by coinflip and the biological attention bottleneck.
#
# JIT CONFIDENCE BAKING: The connector pattern (middleman) is scanned against
# the ATTACHED NODE's own pattern ONCE at attach time (in attach_node!).
# The resulting base_confidence is stored in the AttachedNode struct. At fire
# time, only stochastic jitter is applied — no re-scanning needed. This is
# the JIT optimization: expensive work happens when the user issues the
# /nodeAttach command, not every relay activation cycle.
#
# The connector pattern is still stored for:
#   1. AIML reference: the middleman reason WHY these nodes are related
#   2. Generative context: surfaces as a RelationalTriple downstream so the
#      pipeline knows WHY these nodes were co-activated
#
# /imgnodeAttach does the same for image nodes: SDF conversion happens at
# attach time (JIT GPU accel), base_confidence is baked from SDF similarity.
#
# GRUG v8.0: CASCADE BRIDGE — Match-Cascade Handoff System
# OLD: nodeattach was ASYMMETRIC one-way (target fires → attached MAY fire).
#      Dumb middle-man connector pattern that didn't use the scanner's natural
#      match boundary. Cross-lobe suppression was a hack. AttachedNode was
#      direction-locked — B→A never knew A→B existed.
# NEW: CascadeBridge is BIDIRECTIONAL. When a node fires, the scanner's
#      unmatched tail (the match boundary cutoff) IS the handoff payload to
#      the bridged node. The receiving lobe's scanner processes that fragment
#      directly — no middle-man connector pattern needed. Two-way because
#      the bridge entry exists under BOTH node IDs in BRIDGE_MAP.
#      Cross-lobe works NATURALLY: the unmatched tail carries provenance
#      (which lobe matched last, which node, seam verb) so the receiving
#      lobe knows exactly where the handoff came from.
# Crystallize preserved: crystalized bridges skip the handoff coinflip
#      and always fire. Same :user/:auto/:none origin system.

mutable struct CascadeBridge
    partner_id::String       # GRUG: ID of the bridged partner node (must exist in NODE_MAP)
    seam_tokens::Vector{String}  # GRUG: Tokens at the match boundary — the seam where one lobe's
                              #       scanner cut off and the handoff begins. These are the ACTUAL
                              #       unmatched tokens from the source lobe's scan, not a fabricated
                              #       connector pattern. Replaced the dumb middle-man.
    base_confidence::Float64 # GRUG: JIT-baked confidence computed at bridge time.
                             #       Formula: token_overlap_similarity(node_A.pattern, node_B.pattern)
                             #                 + (partner.strength / STRENGTH_CAP) * 0.5
                             #       At fire time, only jitter is applied: max(0.1, base_confidence + jitter)
    source_lobe::String      # GRUG: Lobe ID of the node that created this bridge entry.
                             #       For bidirectional entries, each side records the OTHER node's lobe.
                             #       This is the provenance — the receiving lobe knows who sent the handoff.
    is_crystalized::Bool     # GRUG (CRYSTALIZE spec): if true, skip the handoff coinflip —
                             #       this bridge ALWAYS fires when its partner fires. Set by user
                             #       via /crystalize, or auto-set when the partner node has high
                             #       strength AND high semantic-truth on its relational triples.
                             #       Auto-revoked if strength drops below the crystalization floor.
    crystal_origin::Symbol   # GRUG: :user (manual /crystalize), :auto (semantic-truth triggered),
                             #       or :none (not crystalized). Lets the auto-revoker only touch
                             #       nodes it crystalized itself — manual marks stay sticky.
end

# Backwards-compat constructor: old 4-arg attach sites still work (seam_tokens
# defaults to empty, source_lobe defaults to ""). Full bridge creation uses 6-arg form.
CascadeBridge(partner_id::String, seam_tokens::Vector{String}, base_confidence::Float64) =
    CascadeBridge(partner_id, seam_tokens, base_confidence, "", false, :none)

# GRUG v8.0: BRIDGE_MAP is BIDIRECTIONAL. When A↔B is bridged, BOTH
# BRIDGE_MAP[A] and BRIDGE_MAP[B] get an entry. Each side's entry points
# to the other. This makes handoff two-way: when A fires, it checks
# BRIDGE_MAP[A] and hands off unmatched tail to B. When B fires, it
# checks BRIDGE_MAP[B] and hands off to A. No more one-way derp.
const BRIDGE_MAP   = Dict{String, Vector{CascadeBridge}}()
const BRIDGE_LOCK  = ReentrantLock()

# GRUG: Backward compat aliases so existing code doesn't break during migration
const ATTACHMENT_MAP  = BRIDGE_MAP
const ATTACHMENT_LOCK = BRIDGE_LOCK

# ==============================================================================
# CHATTER GROUPS (v7.19)
# ==============================================================================
#
# GRUG: A NodeGroup is a named bundle of similar-pattern nodes that chatter
# together. When a new node grows and finds a strength-biased latch target,
# the new node JOINS the latch target's group (or creates a fresh group if
# the target has none). Each group has a stable id ("group_<n>") so chatter
# can address whole bundles without recomputing similarity every cycle.
#
# Membership rules:
#   - A node belongs to exactly one group at a time (its primary group_id).
#   - A node CAN appear in multiple groups via its neighbor_ids \u2014 those are
#     symmetric latches \u2014 but for chatter purposes we use the primary group.
#   - When a member is graved, we strip UNLINKABLE from the group so a
#     replacement can come in (per spec: "if a node within a group gets
#     graved the unlinkable tag is removed for that group until another
#     node replaces it").
#   - Phagy idle role organizes/cleans groups: drops graves, prunes empty
#     groups, merges duplicates if any drift in.
#
# Persistence:
#   GROUP_MAP serializes into the specimen JSON so groups survive save/load.
#   See save_specimen / load_specimen in Main.jl.

const GROUP_MAX_OCCUPANCY = 32  # GRUG: Max members per group. New nodes can't join full groups.
const NOCHAT_GRADUATE_MIN_NEIGHBORS = 4  # GRUG v7.39: Min connected members for NOCHAT graduation. Groups with <4 connected members are invisible to ChatterMode to prevent whacky remixes on under-populated groups.

mutable struct NodeGroup
    id::String                       # GRUG: Stable group id ("group_0", "group_1", ...)
    members::Vector{String}          # GRUG: Node ids \u2014 ORDER PRESERVED for cursor walks
    centroid_pattern::String         # GRUG: Pattern of the founding/seed node (similarity anchor)
    created_at::Float64              # GRUG: Unix timestamp at creation
    last_chatter_at::Float64         # GRUG: 0.0 = never chattered. Updated when group participates.
    chatter_count::Int               # GRUG: How many times this group has chattered (lifetime)
    has_grave_slot::Bool             # GRUG: True after a member is graved \u2014 grants UNLINKABLE override
                                     #       so a fresh node can fill the empty slot. Cleared when
                                     #       the slot is filled.
    grave_count::Int                 # GRUG BUG-010: Number of currently-vacant grave slots in this
                                     #       group. Incremented when a member is graved, decremented
                                     #       when a replacement fills the slot. Used by grave_shadow
                                     #       to compute local inhibition from dead knowledge.
    max_occupancy::Int               # GRUG: Cap on members. Graved nodes create vacancies below this.
                                     #       New nodes can join if length(members) < max_occupancy.
    is_time_node_group::Bool         # GRUG v7.56a: True when seed node is a time node. Time nodes
                                     #       can ONLY pair into groups with other time nodes. Non-time
                                     #       nodes can only join non-time-node groups. Pure label gate.
    is_chatter_eligible::Bool        # GRUG v7.39: False = NOCHAT — group is invisible to ChatterMode.
                                     #       Singleton groups with <4 connected members start as NOCHAT
                                     #       to prevent whacky remixes on under-populated groups.
                                     #       Automatically graduates to true when group reaches 4+
                                     #       connected members (checked in add_to_group!). Replaces
                                     #       the old chatter_count=-1 sentinel hack which was fragile
                                     #       and never enforced.
end

# GRUG: Backwards-friendly constructor. Most callers only know id+seed.
# Calls the default inner constructor (11 positional fields) provided by Julia.
NodeGroup(id::String, seed_node_id::String, centroid_pattern::String; is_time_node_group::Bool=false, is_chatter_eligible::Bool=true) =
    NodeGroup(id, [seed_node_id], centroid_pattern, time(), 0.0, 0, false, 0, GROUP_MAX_OCCUPANCY, is_time_node_group, is_chatter_eligible)

# NOTE: No explicit 12-arg outer constructor needed — Julia's default inner
# constructor already provides NodeGroup(id, members, centroid_pattern,
# created_at, last_chatter_at, chatter_count, has_grave_slot, grave_count, max_occupancy,
# is_time_node_group, is_chatter_eligible).
# Defining an outer constructor with the same signature as the inner one
# replaces it and causes infinite recursion (StackOverflowError).

# GRUG: All groups, by stable id. Phagy organizes this map at idle.
const GROUP_MAP    = Dict{String, NodeGroup}()
const GROUP_LOCK   = ReentrantLock()
const GROUP_COUNTER = Atomic{Int}(0)

# GRUG: Reverse index node_id -> group_id (primary group only). Built lazily;
# always check GROUP_MAP for ground truth. Speeds up "what group is this node
# in?" lookups during chatter without a full scan.
const NODE_TO_GROUP = Dict{String, String}()

# GRUG: Per-node 1-hour chatter cooldown. Distinct from MORPH_COOLDOWN_MAP
# in ChatterMode.jl (which gated the old pattern-morph path). The vote-swap
# chatter has its own short cooldown because swaps are reversible noise,
# not the irreversible identity drift of pattern morphing.
# Map: node_id -> last chatter epoch seconds.
const CHATTER_NODE_COOLDOWN      = Dict{String, Float64}()
const CHATTER_NODE_COOLDOWN_LOCK = ReentrantLock()
const CHATTER_NODE_COOLDOWN_SECONDS = 3600.0   # GRUG: 1 hour, per spec

"""
    next_group_id() -> String

GRUG: Atomic group id minter. Always returns a unique "group_<n>" string.
Underlying counter is reset only by full engine reset (reset_engine!).
"""
function next_group_id()::String
    n = atomic_add!(GROUP_COUNTER, 1)
    return "group_$n"
end

"""
    register_group!(seed_node::Node) -> NodeGroup

GRUG: Create a fresh group seeded by a single node. The node becomes the
group's centroid \u2014 future joiners are evaluated against this pattern. Idempotent
when the seed already belongs to a group: returns the existing group.
NO SILENT FAILURES: errors if seed_node has empty pattern.
"""
function register_group!(seed_node::Node)::NodeGroup
    if strip(seed_node.pattern) == ""
        error("!!! FATAL: register_group! seed node $(seed_node.id) has empty pattern! !!!")
    end
    return lock(GROUP_LOCK) do
        # GRUG: If seed already in a group, just return that one. No duplicate seeding.
        existing = get(NODE_TO_GROUP, seed_node.id, nothing)
        if !isnothing(existing) && haskey(GROUP_MAP, existing)
            return GROUP_MAP[existing]
        end

        gid = next_group_id()
        # GRUG v7.56a: If seed is a time node, this group is a time-node group.
        # Time nodes can ONLY pair into groups with other time nodes.
        is_tng = is_time_node(seed_node)
        grp = NodeGroup(gid, seed_node.id, seed_node.pattern; is_time_node_group=is_tng)
        GROUP_MAP[gid] = grp
        NODE_TO_GROUP[seed_node.id] = gid
        return grp
    end
end

"""
    add_to_group!(group::NodeGroup, node_id::String)::Bool

GRUG: Append `node_id` to the group's member list. Returns true on success,
false if already a member. Updates the NODE_TO_GROUP reverse index. Clears
`has_grave_slot` if the join fills a graved slot (count back to known size).
v7.39: Also graduates NOCHAT groups to chatter-eligible when enough connected
members are present (NOCHAT_GRADUATE_MIN_NEIGHBORS = 4).
"""
function add_to_group!(group::NodeGroup, node_id::String)::Bool
    if isempty(strip(node_id))
        error("!!! FATAL: add_to_group! got empty node_id! !!!")
    end
    return lock(GROUP_LOCK) do
        if node_id in group.members
            return false
        end
        # GRUG: Enforce max_occupancy cap. Full group = no join.
        # Exception: has_grave_slot means a vacancy exists, so one extra can fill it.
        if length(group.members) >= group.max_occupancy && !group.has_grave_slot
            return false
        end
        # GRUG v7.56a: Time-node group isolation. Time nodes can ONLY pair
        # into groups with other time nodes. Non-time nodes can only join
        # non-time-node groups. Cross-type join = silent reject (returns false).
        # This is the core grouping constraint for time nodes — they cluster
        # together and never mix with regular nodes in groups.
        joining_node = get(NODE_MAP, node_id, nothing)
        if !isnothing(joining_node)
            node_is_time = is_time_node(joining_node)
            grp_is_time = group.is_time_node_group
            if node_is_time != grp_is_time
                return false
            end
        end
        push!(group.members, node_id)
        NODE_TO_GROUP[node_id] = group.id
        # GRUG: Filling a graved slot clears the override and decrements grave_count.
        if group.has_grave_slot
            group.has_grave_slot = false
            group.grave_count = max(0, group.grave_count - 1)
            # GRUG: If grave_count dropped to zero, no more vacant slots.
            # If still > 0, there are more graves to fill — re-enable slot flag
            # so the next join also gets the override.
            if group.grave_count > 0
                group.has_grave_slot = true
            end
        end

        # GRUG v7.39: NOCHAT graduation. When a NOCHAT group (is_chatter_eligible=false)
        # grows to have enough connected members, it automatically graduates to
        # chatter-eligible. The threshold is NOCHAT_GRADUATE_MIN_NEIGHBORS (4).
        # This replaces the old chatter_count=-1 sentinel which had no graduation path.
        if !group.is_chatter_eligible
            _connected = 0
            for mid in group.members
                mn = get(NODE_MAP, mid, nothing)
                if mn !== nothing && !mn.is_grave && length(mn.neighbor_ids) > 0
                    _connected += 1
                end
            end
            if _connected >= NOCHAT_GRADUATE_MIN_NEIGHBORS
                group.is_chatter_eligible = true
            end
        end

        return true
    end
end

"""
    mark_group_grave_slot!(node_id::String)

GRUG: When a node is graved, find its primary group and flip has_grave_slot
to true. This grants temporary UNLINKABLE override on members of the group
so a fresh node can replace the graved one. No-op if node was not in any group.
"""
function mark_group_grave_slot!(node_id::String)
    if isempty(strip(node_id))
        error("!!! FATAL: mark_group_grave_slot! got empty node_id! !!!")
    end
    lock(GROUP_LOCK) do
        gid = get(NODE_TO_GROUP, node_id, nothing)
        isnothing(gid) && return
        if !haskey(GROUP_MAP, gid)
            # GRUG: Reverse index pointed nowhere \u2014 self-heal.
            delete!(NODE_TO_GROUP, node_id)
            return
        end
        grp = GROUP_MAP[gid]
        # GRUG: Drop the dead member from the visible list but remember the slot is open.
        filter!(m -> m != node_id, grp.members)
        delete!(NODE_TO_GROUP, node_id)
        grp.has_grave_slot = true
        # GRUG BUG-010: Track how many grave vacancies this group has.
        # Each grave increments the count; add_to_group! decrements when
        # a replacement fills the slot. Used by grave_shadow_multiplier.
        grp.grave_count += 1
    end
end

"""
    group_for(node_id::String)::Union{NodeGroup, Nothing}

GRUG: Cheap lookup. Returns the NodeGroup whose primary membership contains
`node_id`, or nothing.
"""
function group_for(node_id::String)::Union{NodeGroup, Nothing}
    return lock(GROUP_LOCK) do
        gid = get(NODE_TO_GROUP, node_id, nothing)
        isnothing(gid) && return nothing
        return get(GROUP_MAP, gid, nothing)
    end
end

"""
    group_avg_strength(group::NodeGroup; node_map, node_lock)::Float64

GRUG: Compute the average strength of alive (non-grave, non-unlinkable) members
in a group. Used by mitosis coinflip to bias group latching probability.
Returns 0.0 if the group has no alive members (empty or all graved).
"""
function group_avg_strength(group::NodeGroup; node_map, node_lock)::Float64
    total = 0.0
    count = 0
    lock(node_lock) do
        for mid in group.members
            member = get(node_map, mid, nothing)
            isnothing(member) && continue
            member.is_grave && continue
            total += member.strength
            count += 1
        end
    end
    return count > 0 ? total / Float64(count) : 0.0
end

"""
    compute_grave_shadow(node_id::String; node_map=NODE_MAP, node_lock=NODE_LOCK,
                         group_map=GROUP_MAP, group_lock=GROUP_LOCK,
                         aiml_tribe=nothing)::Float64

GRUG BUG-010: Compute the grave shadow multiplier for a voting node.
Dead knowledge casts shadows on surviving neighbors — the more graves in
a node's scope, the deeper the shadow. This is a multiplicative penalty
applied in composite_vote_score() after frame_match_multiplier.

Scoping rules:
  - Antimatch nodes → 1.0 (suppressors don't die, don't cast shadows)
  - AIML nodes → GLOBAL: grave ratio across the entire AIML tribe
  - Regular nodes → LOCAL GROUP: grave ratio within the node's NodeGroup

Formula: shadow = 1.0 - (grave_ratio * (1.0 - GRAVE_SHADOW_FLOOR))
  where grave_ratio = grave_count / max(grave_count + alive_count, 1)
  - 0 graves → shadow = 1.0 (no penalty)
  - some graves → shadow < 1.0 (inhibited)
  - all graves → shadow = GRAVE_SHADOW_FLOOR (maximum inhibition)

If the node has no group (orphan), grave_shadow = 1.0 (no local shadow).
"""
function compute_grave_shadow(node_id::String;
                              node_map = NODE_MAP,
                              node_lock = NODE_LOCK,
                              group_map = GROUP_MAP,
                              group_lock = GROUP_LOCK,
                              aiml_tribe = nothing)::Float64
    # GRUG: Antimatch nodes don't die. No shadows on suppressors.
    node = lock(node_lock) do
        get(node_map, node_id, nothing)
    end
    if isnothing(node)
        return 1.0  # vanished node — no opinion
    end
    if node.is_antimatch_node
        return 1.0  # suppressors don't die, don't cast shadows
    end
    if node.is_grave
        return 1.0  # already dead — no self-shadow (grave nodes don't vote anyway)
    end

    # GRUG: AIML nodes are globally active — use tribe-level grave ratio.
    if !isnothing(aiml_tribe)
        # aiml_tribe is the Dict{String, AIMLNode} for this lobe
        grave_count = 0
        alive_count = 0
        for (nid, an) in aiml_tribe
            if an.is_grave
                grave_count += 1
            else
                alive_count += 1
            end
        end
        if grave_count < VoteOrchestrator.GRAVE_SHADOW_MIN_GRAVES
            return 1.0  # not enough graves to cast a shadow
        end
        total = grave_count + alive_count
        if total <= 0
            return 1.0  # empty tribe — no opinion
        end
        grave_ratio = Float64(grave_count) / Float64(total)
        floor = VoteOrchestrator.GRAVE_SHADOW_FLOOR
        shadow = 1.0 - (grave_ratio * (1.0 - floor))
        return clamp(shadow, floor, 1.0)
    end

    # GRUG: Regular nodes are sparse — use group-scoped grave ratio.
    grp = lock(group_lock) do
        gid = get(NODE_TO_GROUP, node_id, nothing)
        isnothing(gid) ? nothing : get(group_map, gid, nothing)
    end

    if isnothing(grp)
        return 1.0  # orphan node — no local shadow
    end

    grave_cnt = grp.grave_count
    alive_cnt = length(grp.members)  # graved members already removed from members list

    if grave_cnt < VoteOrchestrator.GRAVE_SHADOW_MIN_GRAVES
        return 1.0  # not enough graves to cast a shadow
    end
    if alive_cnt <= 0 && grave_cnt <= 0
        return 1.0  # empty group — no opinion
    end

    total = Float64(grave_cnt + alive_cnt)
    grave_ratio = Float64(grave_cnt) / total
    floor = VoteOrchestrator.GRAVE_SHADOW_FLOOR
    shadow = 1.0 - (grave_ratio * (1.0 - floor))
    return clamp(shadow, floor, 1.0)
end

"""
    GroupLatchCandidate

GRUG: A candidate group for mitosis latching. Carries the group,
its pattern-similarity score (with grave-slot boost), and its pre-computed
average alive-member strength. The caller (MitosisMode) filters by strength
floor then picks one at random from the list. Analog coherence as digital
selection — the list IS the distribution, random pick IS the event.
"""
struct GroupLatchCandidate
    group::NodeGroup
    similarity_score::Float64   # GRUG: centroid pattern similarity + grave boost
    avg_strength::Float64       # GRUG: average alive-member strength
end

"""
    find_group_latch_candidates(pattern::String; node_map, node_lock, requesting_node_is_time::Bool=false)::Vector{GroupLatchCandidate}

GRUG: For mitosis autogrowth: find ALL related groups for a new node to join.
Each candidate carries pre-computed avg_strength. The caller picks one at
RANDOM from the filtered list — no ranking, no "pick best", no coinflip.
The list IS the probability distribution. Analog coherence as digital
selection. Events go where they are best used.

Criteria:
  - Group must NOT be at max_occupancy (length(members) < max_occupancy)
  - has_grave_slot groups get a +0.5 similarity boost (vacancy to fill)
  - Group centroid must have some token overlap with the new node's pattern
  - avg_strength is pre-computed for the caller's strength floor filter
  - v7.56a: time-node isolation — time nodes only see time-node groups,
    non-time nodes only see non-time-node groups (requesting_node_is_time gate)
  - Empty vector = no related group found
"""
function find_group_latch_candidates(pattern::String; node_map, node_lock, requesting_node_is_time::Bool=false)::Vector{GroupLatchCandidate}
    candidates = GroupLatchCandidate[]

    lock(GROUP_LOCK) do
        for (gid, grp) in GROUP_MAP
            # GRUG: Full group = no room. Skip.
            if length(grp.members) >= grp.max_occupancy
                continue
            end

            # GRUG v7.56a: Time-node group isolation. Time nodes only see
            # time-node groups, non-time nodes only see non-time-node groups.
            if grp.is_time_node_group != requesting_node_is_time
                continue
            end

            # GRUG: Compute similarity between new node pattern and group centroid
            sim = _token_overlap_similarity(pattern, grp.centroid_pattern)

            # GRUG: Grave-slot groups get a big boost — they have a vacancy
            # that a new node should fill (replacing the lost member).
            if grp.has_grave_slot
                sim += 0.5
            end

            # GRUG: Don't include totally unrelated groups (sim must be > 0)
            if sim <= 0.0
                continue
            end

            # GRUG: Pre-compute average alive-member strength.
            # Caller filters by floor then picks at random.
            avg_s = group_avg_strength(grp; node_map=node_map, node_lock=node_lock)

            push!(candidates, GroupLatchCandidate(grp, sim, avg_s))
        end
    end

    return candidates
end


"""
    link_to_group_member(new_node::Node, group::NodeGroup)::Union{String, Nothing}

GRUG: For mitosis autogrowth: within a group, find the best member to link
the new node to. The member must pass BOTH similarity thresholds:
  1. Pattern similarity: Jaccard token overlap > MITOSIS_PATTERN_SIM_FLOOR (0.15)
  2. Vote (action_packet) similarity: shared action names > MITOSIS_VOTE_SIM_FLOOR (0.25)

Among members passing both thresholds, pick the strongest non-grave,
non-unlinkable one. Returns the linked member's id, or nothing.

This ensures mitosis nodes attach to genuinely related neighbors — not just
any node in the group, but one that shares both what it knows (pattern)
and how it acts (vote).
"""
const MITOSIS_PATTERN_SIM_FLOOR = 0.15   # GRUG: Min pattern Jaccard for group member link
const MITOSIS_VOTE_SIM_FLOOR   = 0.25   # GRUG: Min vote overlap for group member link

# GRUG (v9.2): Relational+thesaurus-guided latching — pattern-bind minus votes.
# Used by _scan_latch_candidates() for the autonomous growth path.
const LATCH_SCAN_CONFIDENCE_FLOOR = 0.60  # GRUG: Min high_res_scan confidence for latch candidate
const THES_LATCH_WEIGHT           = 0.30  # GRUG: Thesaurus proximity bonus weight in candidate score
const LATCH_CANDIDATE_TOP_N       = 5     # GRUG: How many top candidates to consider

function _action_names_from_packet(packet::String)::Set{String}
    names = Set{String}()
    for part in split(packet, '|')
        p = strip(part)
        isempty(p) && continue
        # Strip inline negatives and weight: action_name[negs]^weight -> action_name
        m = match(r"^(.+?)\[[^\]]*\]", p)
        if !isnothing(m)
            name = strip(m.captures[1])
            !isempty(name) && push!(names, name)
        else
            # Strip weight suffix: action_name^weight -> action_name
            m2 = match(r"^(.+?)\^", p)
            if !isnothing(m2)
                name = strip(m2.captures[1])
                !isempty(name) && push!(names, name)
            else
                !isempty(p) && push!(names, p)
            end
        end
    end
    return names
end

function link_to_group_member(new_node::Node, group::NodeGroup)::Union{String, Nothing}
    new_pattern = lowercase(strip(new_node.pattern))
    new_actions = _action_names_from_packet(new_node.action_packet)

    best_id    = nothing
    best_score = -1.0

    lock(NODE_LOCK) do
        for mid in group.members
            member = get(NODE_MAP, mid, nothing)
            isnothing(member) && continue
            member.is_grave && continue
            member.is_unlinkable && continue
            mid == new_node.id && continue

            # GRUG: Threshold 1 — Pattern similarity (Jaccard token overlap)
            pat_sim = _token_overlap_similarity(new_node.pattern, member.pattern)
            if pat_sim < MITOSIS_PATTERN_SIM_FLOOR
                continue
            end

            # GRUG: Threshold 2 — Vote similarity (shared action names)
            member_actions = _action_names_from_packet(member.action_packet)
            if !isempty(new_actions) && !isempty(member_actions)
                shared = length(intersect(new_actions, member_actions))
                total = length(union(new_actions, member_actions))
                vote_sim = total > 0 ? Float64(shared) / Float64(total) : 0.0
            else
                # GRUG: No actions to compare = assume unrelated
                vote_sim = 0.0
            end
            if vote_sim < MITOSIS_VOTE_SIM_FLOOR
                continue
            end

            # GRUG: Score = strength * pattern_sim * (1 + vote_sim)
            # Stronger, more similar members rank higher.
            score = member.strength * pat_sim * (1.0 + vote_sim)
            if score > best_score
                best_score = score
                best_id = mid
            end
        end
    end

    # GRUG: Link the nodes if we found a match
    if best_id !== nothing
        member = lock(NODE_LOCK) do
            get(NODE_MAP, best_id, nothing)
        end
        if member !== nothing
            linked = try_link_nodes!(new_node, member)
            if linked
                return best_id
            end
        end
    end

    return nothing
end

# ==============================================================================
# RELATIONAL+THESAURUS-GUIDED LATCH SCAN (v9.2 — pattern-bind minus votes)
# ==============================================================================
# GRUG: This replaces find_group_latch_candidates() in the autonomous growth
# path. Instead of Jaccard token overlap on group centroids, it uses the full
# pattern-bind pipeline: SigilPromoter canonicalization → relational triple
# extraction → high_res_scan confidence → evaluate_relational_dialectics →
# thesaurus proximity bonus → action_packet vote overlap gate.
#
# Three gates must ALL pass for a candidate node:
#   1. scan_conf > LATCH_SCAN_CONFIDENCE_FLOOR   (float-hash pattern match)
#   2. rel_score >= 0                             (relational overlap, -9999.0 = hard reject)
#   3. vote_overlap > MITOSIS_VOTE_SIM_FLOOR      (action_packet name overlap)
#
# Candidate score = scan_conf + rel_score + thes_bonus
# NO VOTE ACTIVATION — candidates are never fired, never enter VoteOrchestrator.
#
# Only non-grave, non-UNLINKABLE, non-image, non-antimatch nodes in groups
# qualify. Time nodes and match nodes participate. Batch size limited to 1000
# (same as ACTIVE_FIRE_CAP) to keep scan bounded on large specimens.

# GRUG: Latch candidate struct for the relational+thesaurus pipeline.
# Carries more signal than the old GroupLatchCandidate (which only had
# similarity_score + avg_strength). This one carries the composite score
# and all three gate results for debug visibility.
struct LatchCandidate
    node_id::String                     # GRUG: The candidate node's ID
    group::NodeGroup                    # GRUG: The group this node belongs to
    scan_conf::Float64                  # GRUG: high_res_scan confidence (gate 1)
    rel_score::Float64                  # GRUG: evaluate_relational_dialectics score (gate 2)
    vote_overlap::Float64               # GRUG: action_packet name overlap (gate 3)
    thes_bonus::Float64                 # GRUG: thesaurus proximity bonus
    composite_score::Float64            # GRUG: scan_conf + rel_score + thes_bonus
    avg_strength::Float64               # GRUG: pre-computed group avg strength
end

"""
    _scan_latch_candidates(pattern, action_packet; kwargs...) -> Vector{LatchCandidate}

GRUG: Find candidate nodes for group latching using the relational+thesaurus
pipeline. This is the pattern-bind phase minus vote activation. Returns scored
candidates sorted by composite_score (descending). Caller picks from top-N.

When pipeline functions (sigil_promote_fn, extract_triples_fn, etc.) are not
provided, falls back to simpler checks — still better than Jaccard-only.
"""
function _scan_latch_candidates(
    pattern::String,
    action_packet::String;
    node_map,
    node_lock,
    lobe_id::String = "",
    thesaurus_fn::Union{Function, Nothing} = nothing,
    sigil_promote_fn::Union{Function, Nothing} = nothing,
    extract_triples_fn::Union{Function, Nothing} = nothing,
    evaluate_dialectics_fn::Union{Function, Nothing} = nothing,
    words_to_signal_fn::Union{Function, Nothing} = nothing,
    batch_size::Int = 1000,
)::Vector{LatchCandidate}
    candidates = LatchCandidate[]

    # GRUG: Step 1 — Canonicalize the pattern via SigilPromoter if available.
    # Thesaurus canonicalization rewrites surface variants ("two plus two" → "2 + 2")
    # so a new node with pattern "calculate sum" can match "compute addition".
    canonical_pattern = pattern
    if sigil_promote_fn !== nothing
        try
            promoted = sigil_promote_fn(pattern)
            # GRUG: promote_input returns (rewritten, bindings). We just need the text.
            if isa(promoted, Tuple) && length(promoted) >= 1 && !isempty(promoted[1])
                canonical_pattern = String(promoted[1])
            elseif isa(promoted, AbstractString) && !isempty(promoted)
                canonical_pattern = String(promoted)
            end
        catch
            # GRUG: SigilPromoter failure = use raw pattern. Not fatal.
        end
    end

    # GRUG: Step 2 — Extract relational triples from the canonical pattern.
    # These (subject, relation, object) triples are compared against each
    # candidate node's relational_patterns via evaluate_relational_dialectics.
    new_triples = if extract_triples_fn !== nothing
        try
            extract_triples_fn(canonical_pattern)
        catch
            # GRUG: Triple extraction failure = empty triples. Pipeline continues
            # without relational gating — relies on scan_conf + vote_overlap only.
            []
        end
    else
        []
    end

    # GRUG: Step 3 — Build the new node's float-hash signal for pattern scanning.
    # high_res_scan needs a Vector{Float64} target signal.
    new_signal = if words_to_signal_fn !== nothing
        try
            words_to_signal_fn(canonical_pattern)
        catch
            Float64[]
        end
    else
        Float64[]
    end

    # GRUG: Extract action names from the new node's action_packet for vote overlap.
    new_action_names = _action_names_from_packet(action_packet)

    # GRUG: Step 4 — Scan candidate nodes. Batch-limited.
    # Collect nodes that are: not grave, not UNLINKABLE, not image, not antimatch,
    # in a group, and (optionally) in the same lobe or connected lobes.
    # GRUG: Three-phase lock strategy to avoid deadlock AND avoid reading
    # NODE_TO_GROUP under the wrong lock. NODE_TO_GROUP is written under
    # GROUP_LOCK, so we must read it under GROUP_LOCK too.
    #
    # Phase 1 (node_lock): Collect candidate node IDs and hard-filter flags.
    #   No NODE_TO_GROUP access here — just node_map reads.
    # Phase 2 (GROUP_LOCK): Look up NODE_TO_GROUP + GROUP_MAP, filter to
    #   groups with room. Returns (node_id, group) pairs.
    # Phase 3 (node_lock): Fetch actual node objects for scoring.
    _candidate_nids = lock(node_lock) do
        nids = String[]
        for node in values(node_map)
            # GRUG: Hard filters — these never participate in latching
            node.is_grave && continue
            node.is_unlinkable && continue
            node.is_image_node && continue
            node.is_antimatch_node && continue
            push!(nids, node.id)
            length(nids) >= batch_size && break
        end
        return nids
    end

    # GRUG: Phase 2 — under GROUP_LOCK, look up group membership + room.
    _eligible_pairs = lock(GROUP_LOCK) do
        eligible = Tuple{String, NodeGroup}[]  # (node_id, group)
        for nid in _candidate_nids
            gid = get(NODE_TO_GROUP, nid, nothing)
            isnothing(gid) && continue
            grp = get(GROUP_MAP, gid, nothing)
            isnothing(grp) && continue
            if length(grp.members) >= grp.max_occupancy && !grp.has_grave_slot
                continue
            end
            push!(eligible, (nid, grp))
        end
        return eligible
    end

    # GRUG: Phase 3 — back under node_lock, fetch the actual node objects.
    candidate_nodes = lock(node_lock) do
        result = Tuple{Any, Any}[]  # (node, group)
        for (nid, grp) in _eligible_pairs
            node = get(node_map, nid, nothing)
            isnothing(node) && continue
            push!(result, (node, grp))
        end
        return result
    end

    if isempty(candidate_nodes)
        return candidates
    end

    # GRUG: Step 5 — Score each candidate through the three-gate pipeline.
    for (node, grp) in candidate_nodes
        try
            # ── GATE 1: Pattern scan confidence ────────────────────────────
            scan_conf = 0.0
            if !isempty(new_signal) && words_to_signal_fn !== nothing
                try
                    node_signal = words_to_signal_fn(node.pattern)
                    if !isempty(node_signal) && !isempty(new_signal)
                        # GRUG: high_res_scan needs target >= pattern length.
                        # The longer signal is the target; the shorter is the pattern.
                        if length(node_signal) >= length(new_signal) && length(new_signal) >= 2
                            try
                                # GRUG: high_res_scan throws PatternNotFoundError when no match.
                                # We catch that and treat it as scan_conf = 0 (below threshold).
                                (_, conf) = PatternScanner.high_res_scan(
                                    node_signal, new_signal;
                                    tolerance=0.05, threshold=LATCH_SCAN_CONFIDENCE_FLOOR
                                )
                                scan_conf = conf
                            catch
                                # GRUG: PatternNotFoundError or other scan error = no match.
                                # Fall back to token overlap as a cheaper check.
                                scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                            end
                        elseif length(new_signal) >= length(node_signal) && length(node_signal) >= 2
                            try
                                # GRUG: Reversed — new node signal is longer, it's the target.
                                (_, conf) = PatternScanner.high_res_scan(
                                    new_signal, node_signal;
                                    tolerance=0.05, threshold=LATCH_SCAN_CONFIDENCE_FLOOR
                                )
                                scan_conf = conf
                            catch
                                scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                            end
                        else
                            # GRUG: Signal too short for high_res_scan. Use token overlap.
                            scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                        end
                    else
                        scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                    end
                catch
                    # GRUG: Signal computation failed. Use token overlap fallback.
                    scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
                end
            else
                # GRUG: No signal function available. Use token overlap.
                scan_conf = _token_overlap_similarity(canonical_pattern, node.pattern)
            end

            # GRUG: Gate 1 check — scan confidence must exceed floor.
            if scan_conf < LATCH_SCAN_CONFIDENCE_FLOOR
                continue
            end

            # ── GATE 2: Relational dialectics ──────────────────────────────
            rel_score = 0.0
            if evaluate_dialectics_fn !== nothing && !isempty(new_triples)
                try
                    (score, is_anti) = evaluate_dialectics_fn(
                        new_triples,
                        node.relational_patterns,
                        node.required_relations,
                        node.relation_weights
                    )
                    # GRUG: -9999.0 sentinel = hard reject (missing required relation).
                    # is_anti = true = antimatch detected (inverse subject/object).
                    if score == -9999.0 || is_anti
                        continue  # GRUG: Hard reject — skip this candidate entirely.
                    end
                    rel_score = score
                catch
                    # GRUG: Dialectics evaluation failed. Neutral score (0.0).
                    # Pipeline continues with scan_conf + vote_overlap only.
                    rel_score = 0.0
                end
            end

            # GRUG: Gate 2 check — rel_score must be >= 0 (not hard-rejected).
            # (Already handled by the continue above for -9999.0 and antimatch.)
            if rel_score < 0.0
                continue
            end

            # ── GATE 3: Vote (action_packet) overlap ───────────────────────
            vote_overlap = 0.0
            if !isempty(new_action_names)
                member_actions = _action_names_from_packet(node.action_packet)
                if !isempty(member_actions)
                    shared = length(intersect(new_action_names, member_actions))
                    total = length(union(new_action_names, member_actions))
                    vote_overlap = total > 0 ? Float64(shared) / Float64(total) : 0.0
                end
            end

            # GRUG: Gate 3 check — vote overlap must exceed floor.
            if vote_overlap < MITOSIS_VOTE_SIM_FLOOR
                continue
            end

            # ── THESAURUS PROXIMITY BONUS ──────────────────────────────────
            # GRUG: Near-synonyms expand reach beyond exact token match.
            # "calculate" is close to "compute" in thesaurus space.
            thes_bonus = 0.0
            if thesaurus_fn !== nothing
                try
                    pat_tokens = split(lowercase(strip(canonical_pattern)))
                    node_tokens = split(lowercase(strip(node.pattern)))
                    best_thes = 0.0
                    for pt in pat_tokens
                        for nt in node_tokens
                            try
                                sim = thesaurus_fn(String(pt), String(nt))
                                if sim > best_thes
                                    best_thes = sim
                                end
                            catch; end
                            # GRUG: Early exit if we already have a strong match
                            best_thes >= 0.8 && break
                        end
                        best_thes >= 0.8 && break
                    end
                    thes_bonus = best_thes * THES_LATCH_WEIGHT
                catch
                    # GRUG: Thesaurus failure = no bonus. Not fatal.
                end
            end

            # ── COMPOSITE SCORE ─────────────────────────────────────────────
            composite = scan_conf + rel_score + thes_bonus

            # GRUG: Grave-slot boost — group with a vacancy gets a bonus
            # because a new node fills a meaningful gap.
            if grp.has_grave_slot
                composite += 0.5
            end

            # GRUG: Pre-compute avg_strength for the caller's coinflip.
            avg_str = group_avg_strength(grp; node_map=node_map, node_lock=node_lock)

            push!(candidates, LatchCandidate(
                node.id, grp, scan_conf, rel_score, vote_overlap,
                thes_bonus, composite, avg_str
            ))
        catch
            # GRUG: Per-candidate failure doesn't kill the whole scan.
            # Skip this node and continue with the rest.
            continue
        end
    end

    # GRUG: Sort by composite score descending. Caller picks from top-N.
    sort!(candidates, by = c -> -c.composite_score)

    return candidates
end

"""
    chatter_cooldown_remaining(node_id::String)::Float64

GRUG: Seconds until the node may chatter again. 0.0 means "go ahead".
Negative-safe: clamps at 0.0.
"""
function chatter_cooldown_remaining(node_id::String)::Float64
    return lock(CHATTER_NODE_COOLDOWN_LOCK) do
        last = get(CHATTER_NODE_COOLDOWN, node_id, 0.0)
        last == 0.0 && return 0.0
        elapsed = time() - last
        return max(0.0, CHATTER_NODE_COOLDOWN_SECONDS - elapsed)
    end
end

"""
    stamp_chatter!(node_id::String)

GRUG: Record that this node just participated in chatter. Resets its
1-hour cooldown clock.
"""
function stamp_chatter!(node_id::String)
    lock(CHATTER_NODE_COOLDOWN_LOCK) do
        CHATTER_NODE_COOLDOWN[node_id] = time()
    end
end

# GRUG: Handoff slot so scan_and_expand relay pass can reuse the FireCounter
# built by scan_specimens for this cycle. All fire paths share one counter so
# the 1000 cap is enforced GLOBALLY — attachments, drop-table, and cascade all
# count toward the same limit. Protected by NODE_LOCK implicitly (only written
# by scan_specimens under its own flow).
const _LAST_FIRE_COUNTER = Ref{Union{Nothing, VoteOrchestrator.FireCounter}}(nothing)
const _FIRE_COUNTER_LOCK = ReentrantLock()

"""
    get_fire_counter() -> Union{Nothing, VoteOrchestrator.FireCounter}

Thread-safe read of _LAST_FIRE_COUNTER. Used by Main.jl scan telemetry.
"""
get_fire_counter() = lock(_FIRE_COUNTER_LOCK) do; _LAST_FIRE_COUNTER[] end

# GRUG: Hard cap on how many bridges a node can have. User said 4.
# Each bridge is bidirectional, so MAX_BRIDGES=4 means 4 partners per node.
const MAX_BRIDGES = 4
# GRUG: Backward compat alias
const MAX_ATTACHMENTS = MAX_BRIDGES

# GRUG: Small stochastic jitter applied to co-fired node confidence.
# Biologically motivated — synaptic relay is noisy. Same neuron doesn't fire
# with identical strength every time it gets woken by a relay. Keeps the vote
# pool from collapsing to the same winner every cycle when attachments fire.
# Magnitude is small (sigma=0.05) so it nudges but never dominates.
const RELAY_CONF_JITTER_SIGMA = 0.05

# v10-coherence-fix: CASCADE-RELAY CONFIDENCE DISCOUNT.
# Applied to bridge-handoff (cascade) node confidence at injection time, BEFORE
# score_lobes runs. Bridges are context co-activations, not direct answers — a
# bridged partner must never out-rank the genuine primary content match. At 0.35
# a bridge node carrying base_confidence 0.4 enters the pool at ~0.14, well below
# any real primary content match (which scores 0.6+ on exact-pattern overlap),
# so it can co-activate for generative context without stealing the winner crown.
const CASCADE_RELAY_CONF_DISCOUNT = 0.35


# SMELL-004: Pattern-scan acceptance thresholds. These were inline magic
# numbers at the cheap/medium/high scan dispatch site. Promoted to named
# constants so tuning is centralized and meaning is documented.
#
#   CHEAP_SCAN_THRESHOLD  — bidirectional scan for short signals (≤3 tokens).
#                            High because short patterns have LOW discrimination
#                            on overlap math — a 0.3 floor lets a single fuzzy
#                            character span trigger a "match," which causes
#                            unrelated lobes to all fire on short inputs and
#                            produces routing-by-coinflip on the resulting
#                            0.55-0.57 plateau. 0.6 means the cheap scan only
#                            says "yes" when most of the short pattern is
#                            actually present in the input. Cheap stays cheap;
#                            it just stops rubber-stamping non-matches.
#   MEDIUM_SCAN_THRESHOLD — standard medium-resolution scan.
#   HIGH_SCAN_THRESHOLD   — full high-resolution scan; strict acceptance.
const CHEAP_SCAN_THRESHOLD  = 0.6
const MEDIUM_SCAN_THRESHOLD = 0.4
const HIGH_SCAN_THRESHOLD   = 0.5

# BUG-004 PENALTY: When pattern tokens > input tokens, the cheap bidirectional
# scan with swapped arguments is inherently less reliable. This penalty fraction
# is subtracted from token_conf to downrank these matches vs properly-sized ones.
const BUG_004_PENALTY = 0.25

# GRUG v7.49: Anti-match drain constants.
# ANTIMATCH_DRAIN_FIXED: fixed confidence drain per activation for NONJITTER anti-match nodes.
# ANTIMATCH_DRAIN_MAX_JITTER: upper bound for random (jittered) confidence drain per activation.
# Actual jitter drain = rand() * ANTIMATCH_DRAIN_MAX_JITTER.
const ANTIMATCH_DRAIN_FIXED      = 0.03   # GRUG: fixed tick for NONJITTER anti-match
const ANTIMATCH_DRAIN_MAX_JITTER = 0.05   # GRUG: max random tick drain per activation

# GRUG: STOPWORDS — closed-class function words that overlap nearly everything.
# Used by the literal-token pre-gate in fire_one() to distinguish "shared
# content word" (real lexical hit) from "shared stop-word" (noise). A pattern
# that overlaps the input only on tokens like `the`, `for`, `a` is not a real
# lexical hit and should not bypass the coinflip — those overlaps are statistical
# noise, not semantic signal. Compact list focused on grug-tier prose; keep
# function-only (no nouns or verbs).
const STOPWORDS = Set([
    "a", "an", "the",
    "i", "you", "we", "he", "she", "it", "they", "me", "us", "him", "her", "them",
    "my", "your", "our", "his", "their", "its",
    "is", "am", "are", "was", "were", "be", "been", "being",
    "do", "does", "did", "have", "has", "had",
    "to", "of", "in", "on", "at", "for", "with", "by", "from", "as",
    "and", "or", "but", "if", "so", "than", "then",
    "this", "that", "these", "those",
    "not", "no",
    "up", "down",
    # GRUG: Question words — "what", "who", "how" etc. are closed-class
    # function words that match nearly everything. Without them in STOPWORDS,
    # "what" counts as a content token in the literal pre-gate, giving
    # conversation nodes a literal_hit on "What is the quadratic formula"
    # even though "what" carries zero domain signal.
    "what", "who", "how", "why", "when", "where", "which",
])


"""
    bridge_nodes!(node_a::String, node_b::String; seam_tokens::Vector{String}=String[])::String

GRUG v8.0: MATCH-CASCADE BRIDGE! Replace the dumb one-way middle-man nodeattach
with a two-way bridge. When node A fires, the scanner's unmatched tail (the
match boundary cutoff) is handed off to node B's lobe. Vice versa from B→A.
No more fabricated connector pattern — the ACTUAL unmatched tokens at the seam
become the bridge payload. Both sides know about each other (bidirectional).

JIT CONFIDENCE BAKING: Same as old attach_node! but now symmetric:
  base_confidence_AB = token_overlap(node_A.pattern, node_B.pattern) + (B.strength/CAP)*0.5
  base_confidence_BA = token_overlap(node_A.pattern, node_B.pattern) + (A.strength/CAP)*0.5
Each side's base_confidence includes the PARTNER's strength bonus, so the
stronger your partner, the more likely the handoff succeeds. Symmetric overlap
but asymmetric strength bonus = asymmetric confidence (correct! the node with
more provenance should fire more readily).

SEAM TOKENS: The tokens at the match boundary where the source lobe's scanner
cut off. These become the handoff payload — the receiving lobe's scanner
processes these tokens directly. If empty at bridge time, they'll be populated
at fire time from the actual scanner match boundary. For manual /nodeBridge
commands, seam_tokens come from the user's pattern argument (backward compat).

Validation (error-first, NO silent failures):
  - Both nodes must exist in NODE_MAP and not be grave
  - node_a ≠ node_b (no self-bridging, that's a loop not a bridge)
  - Neither node can already have MAX_BRIDGES (4) bridges
  - node_a and node_b cannot already be bridged (no duplicate bridges)

Returns confirmation string on success.
"""

# GRUG: Safe Lobe access — Lobe module may not be loaded when engine runs standalone
_safe_find_lobe(node_id::String) = isdefined(@__MODULE__, :Lobe) ? something(Lobe.find_lobe_for_node(node_id), "") : ""
_safe_lobe_registry_has(lobe_id::String) = isdefined(@__MODULE__, :Lobe) && haskey(Lobe.LOBE_REGISTRY, lobe_id)

function bridge_nodes!(node_a::String, node_b::String;
                       seam_tokens::Vector{String}=String[])::String
    if strip(node_a) == ""
        error("!!! FATAL: bridge_nodes! got empty node_a! Grug needs a real node! !!!")
    end
    if strip(node_b) == ""
        error("!!! FATAL: bridge_nodes! got empty node_b! Grug needs a real partner! !!!")
    end
    if node_a == node_b
        error("!!! FATAL: bridge_nodes! '$node_a' cannot bridge to itself! That's a loop, not a bridge! !!!")
    end

    # GRUG: Validate both nodes exist and are alive
    lobe_a = ""
    lobe_b = ""
    lock(NODE_LOCK) do
        if !haskey(NODE_MAP, node_a)
            error("!!! FATAL: bridge_nodes! node '$node_a' does not exist on the map! !!!")
        end
        if !haskey(NODE_MAP, node_b)
            error("!!! FATAL: bridge_nodes! node '$node_b' does not exist on the map! !!!")
        end
        na = NODE_MAP[node_a]
        nb = NODE_MAP[node_b]
        if na.is_grave
            error("!!! FATAL: bridge_nodes! node '$node_a' is GRAVE [$(na.grave_reason)]! Cannot bridge dead nodes! !!!")
        end
        if nb.is_grave
            error("!!! FATAL: bridge_nodes! node '$node_b' is GRAVE [$(nb.grave_reason)]! Cannot bridge dead nodes! !!!")
        end
    end

    # GRUG: Resolve lobe provenance for both sides of the bridge
    lobe_a = _safe_find_lobe(node_a)
    lobe_b = _safe_find_lobe(node_b)

    # GRUG: JIT CONFIDENCE BAKING — symmetric overlap, asymmetric strength bonus.
    # Each side's base_confidence includes the PARTNER's strength so a strong
    # partner = easier handoff. This is the match-cascade analog of the old
    # connector-pattern JIT baking, but without the dumb middle-man.
    overlap = lock(NODE_LOCK) do
        na = NODE_MAP[node_a]
        nb = NODE_MAP[node_b]
        return _token_overlap_similarity(na.pattern, nb.pattern)
    end
    jit_conf_a_to_b = lock(NODE_LOCK) do
        nb = NODE_MAP[node_b]
        return overlap + (nb.strength / STRENGTH_CAP) * 0.5
    end
    jit_conf_b_to_a = lock(NODE_LOCK) do
        na = NODE_MAP[node_a]
        return overlap + (na.strength / STRENGTH_CAP) * 0.5
    end

    lock(BRIDGE_LOCK) do
        # GRUG: Check bridge caps on BOTH sides (bidirectional = both must have room)
        existing_a = get(BRIDGE_MAP, node_a, CascadeBridge[])
        if length(existing_a) >= MAX_BRIDGES
            error("!!! FATAL: bridge_nodes! node '$node_a' already has $(length(existing_a)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end
        existing_b = get(BRIDGE_MAP, node_b, CascadeBridge[])
        if length(existing_b) >= MAX_BRIDGES
            error("!!! FATAL: bridge_nodes! node '$node_b' already has $(length(existing_b)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end

        # GRUG: Check for duplicate bridge (either direction)
        for br in existing_a
            if br.partner_id == node_b
                error("!!! FATAL: bridge_nodes! '$node_a' is already bridged to '$node_b'! No duplicate bridges! !!!")
            end
        end
        for br in existing_b
            if br.partner_id == node_a
                error("!!! FATAL: bridge_nodes! '$node_b' is already bridged to '$node_a'! Bidirectional bridge already exists! !!!")
            end
        end

        # GRUG: All checks passed. Create bidirectional bridge entries!
        # A→B entry: partner is B, source_lobe is B's lobe (provenance = "came from B's lobe")
        # B→A entry: partner is A, source_lobe is A's lobe (provenance = "came from A's lobe")
        bridge_a_to_b = CascadeBridge(node_b, seam_tokens, jit_conf_a_to_b, lobe_b, false, :none)
        bridge_b_to_a = CascadeBridge(node_a, seam_tokens, jit_conf_b_to_a, lobe_a, false, :none)

        push!(existing_a, bridge_a_to_b)
        BRIDGE_MAP[node_a] = existing_a
        push!(existing_b, bridge_b_to_a)
        BRIDGE_MAP[node_b] = existing_b
    end

    n_bridged_a = lock(() -> length(get(BRIDGE_MAP, node_a, CascadeBridge[])), BRIDGE_LOCK)
    n_bridged_b = lock(() -> length(get(BRIDGE_MAP, node_b, CascadeBridge[])), BRIDGE_LOCK)
    cross_lobe_tag = lobe_a != lobe_b ? " [CROSS-LOBE: $lobe_a ↔ $lobe_b]" : ""
    seam_preview = isempty(seam_tokens) ? "(seam tokens populated at fire time)" : "\"$(join(seam_tokens, " "))\""
    println("[ENGINE] 🌉  Bridge: '$node_a' ↔ '$node_b'$cross_lobe_tag | seam=$seam_preview | conf_A→B=$(round(jit_conf_a_to_b, digits=3)), conf_B→A=$(round(jit_conf_b_to_a, digits=3)) | A: $n_bridged_a/$MAX_BRIDGES, B: $n_bridged_b/$MAX_BRIDGES")
    return "Bridged '$node_a' ↔ '$node_b'$cross_lobe_tag | seam=$seam_preview | conf_A→B=$(round(jit_conf_a_to_b, digits=3)), B→A=$(round(jit_conf_b_to_a, digits=3)) | A: $n_bridged_a/$MAX_BRIDGES, B: $n_bridged_b/$MAX_BRIDGES"
end

# GRUG: Backward-compat wrapper — old /nodeAttach calls still work.
# Converts the old (target_id, attach_id, pattern) signature into the new
# bidirectional bridge. The pattern becomes seam_tokens (split on whitespace).
function attach_node!(target_id::String, attach_id::String, pattern::String)::String
    if isempty(strip(pattern))
        error("!!! FATAL: attach_node! got empty pattern! Grug needs a real relay pattern! !!!")
    end
    seam = String.(split(strip(pattern)))
    return bridge_nodes!(target_id, attach_id; seam_tokens=seam)
end

"""
    unbridge_nodes!(node_a::String, node_b::String)::String

GRUG v8.0: Remove a bidirectional bridge between two nodes. Both sides of
the bridge entry are removed — BRIDGE_MAP[node_a] loses the B entry AND
BRIDGE_MAP[node_b] loses the A entry. No half-bridges allowed.

Returns confirmation string. Errors if bridge doesn't exist.
"""
function unbridge_nodes!(node_a::String, node_b::String)::String
    if strip(node_a) == ""
        error("!!! FATAL: unbridge_nodes! got empty node_a! !!!")
    end
    if strip(node_b) == ""
        error("!!! FATAL: unbridge_nodes! got empty node_b! !!!")
    end

    lock(BRIDGE_LOCK) do
        # GRUG: Remove node_b from node_a's bridge list
        found_a = false
        if haskey(BRIDGE_MAP, node_a)
            existing_a = BRIDGE_MAP[node_a]
            idx_a = findfirst(br -> br.partner_id == node_b, existing_a)
            if !isnothing(idx_a)
                deleteat!(existing_a, idx_a)
                found_a = true
                if isempty(existing_a)
                    delete!(BRIDGE_MAP, node_a)
                end
            end
        end

        # GRUG: Remove node_a from node_b's bridge list (bidirectional!)
        found_b = false
        if haskey(BRIDGE_MAP, node_b)
            existing_b = BRIDGE_MAP[node_b]
            idx_b = findfirst(br -> br.partner_id == node_a, existing_b)
            if !isnothing(idx_b)
                deleteat!(existing_b, idx_b)
                found_b = true
                if isempty(existing_b)
                    delete!(BRIDGE_MAP, node_b)
                end
            end
        end

        if !found_a && !found_b
            error("!!! FATAL: unbridge_nodes! no bridge exists between '$node_a' and '$node_b'! !!!")
        end
    end

    println("[ENGINE] 🌉💨  Bridge removed: '$node_a' ↔ '$node_b'.")
    return "Unbridged '$node_a' ↔ '$node_b'"
end

# GRUG: Backward-compat wrapper — old /nodeDetach still works
function detach_node!(target_id::String, attach_id::String)::String
    return unbridge_nodes!(target_id, attach_id)
end

"""
    fire_cascades!(source_id::String, active_count::Int, active_cap::Int;
                  unmatched_tail::Vector{String}=String[])::Vector{Tuple{String, Float64, String}}

GRUG v8.0: MATCH-CASCADE HANDOFF! Replaces the old dumb fire_attachments!.
When a node fires, its bridge partners get the unmatched tail of the input —
the tokens the scanner DIDN'T match. This is the match-boundary cutoff, and
it IS the natural cross-lobe bridge. No more fabricated connector pattern
middle-man. The receiving lobe's scanner processes these tokens directly.

Bidirectional: When A fires and checks BRIDGE_MAP[A], it finds B. When B fires
and checks BRIDGE_MAP[B], it finds A. Both directions work. No more one-way derp.

CRYSTALIZE: Crystalized bridges skip the coinflip and always fire. Same
:user/:auto/:none system as before. The auto-crystallizer still works.

JIT CONFIDENCE: base_confidence was baked at bridge time using symmetric
pattern overlap + partner strength bonus. At fire time, only stochastic
jitter is applied: max(0.1, base_confidence + randn() * RELAY_CONF_JITTER_SIGMA)
Same as before but without the dumb connector pattern.

MATCH-BOUNDARY HANDOFF: The unmatched_tail parameter carries the tokens that
the source lobe's scanner couldn't match. These are the seam tokens — the
bridge payload. When the partner node is in a different lobe, this tail gets
handed to that lobe's scanner for processing. Same-lobe bridges also benefit
because the tail carries context the primary scan missed.

active_count = how many nodes have already fired this scan cycle
active_cap   = the biological attention bottleneck limit for this cycle

Returns: Vector of (partner_id, confidence, seam_text) triples.
         seam_text is the join of seam_tokens for generative context.
"""
function fire_cascades!(source_id::String, active_count::Int, active_cap::Int;
                        unmatched_tail::Vector{String}=String[])::Vector{Tuple{String, Float64, String}}
    fired = Tuple{String, Float64, String}[]

    # GRUG v8.0 FIX: Copy the bridge vector under BRIDGE_LOCK so we have an
    # immutable snapshot. Without copy, we hold a reference to the live vector
    # inside BRIDGE_MAP — another task could push!/filter! it after we release
    # BRIDGE_LOCK, causing a concurrent modification race during NODE_LOCK iteration.
    bridges = lock(() -> copy(get(BRIDGE_MAP, source_id, CascadeBridge[])), BRIDGE_LOCK)
    if isempty(bridges)
        return fired
    end

    lock(NODE_LOCK) do
        # GRUG: Verify source still exists. Non-fatal if gone.
        source_node = get(NODE_MAP, source_id, nothing)
        if isnothing(source_node)
            @warn "[ENGINE] ⚠ fire_cascades!: source '$source_id' vanished from NODE_MAP."
            return
        end

        source_lobe = _safe_find_lobe(source_id)
        current_active = active_count

        for br in bridges
            # GRUG: ACTIVE CAP GATE! Biological attention limit.
            if current_active >= active_cap
                println("[ENGINE] 🧠  Cascade handoff halted for '$source_id' — active cap ($active_cap) reached.")
                break
            end

            # GRUG: Check partner node still exists and is alive
            partner_ref = get(NODE_MAP, br.partner_id, nothing)
            if isnothing(partner_ref)
                # Partner was deleted/graved. Stale bridge. Skip.
                continue
            end
            if partner_ref.is_grave
                # Dead nodes don't fire. Skip.
                continue
            end

            # GRUG v8.0: NO MORE CROSS-LOBE SUPPRESSION! The old system had a
            # hack that suppressed cross-lobe attachments and redirected to cascade
            # PASS 2. That's gone now. The match-cascade handoff IS the cross-lobe
            # bridge. When source is in lobe A and partner is in lobe B, the
            # unmatched tail carries provenance (which lobe, which node, seam tokens)
            # so lobe B's scanner knows exactly where the handoff came from.
            # This is the whole point of the rework — cross-lobe works NATURALLY.
            partner_lobe = _safe_find_lobe(br.partner_id)
            is_cross_lobe = source_lobe != "" && partner_lobe != "" && source_lobe != partner_lobe

            # GRUG v8.0: CONFIDENCE-BIASED BRIDGE COINFLIP! Not the same as scan
            # coinflip anymore. Bridge relays now bias by BOTH partner strength AND
            # the bridge's base_confidence relative to AIML_CONFIDENCE_THRESHOLD.
            # High-confidence bridges fire more reliably. Weak ones still get a chance.
            # CRYSTALIZE: crystalized bridges with high-confidence votes SKIP the
            # coinflip entirely (deterministic pass-through). Crystalized bridges with
            # LOW-confidence votes still flip — confidence must be earned.
            # NON-CRYSTALIZE: always flip, biased by strength + confidence.
            if br.is_crystalized
                # Crystalized bridge: skip coinflip ONLY for high-confidence votes.
                # Low-confidence crystalized votes still flip (must earn certainty).
                if br.base_confidence < VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD &&
                   !confidence_biased_bridge_coinflip(partner_ref, br.base_confidence)
                    continue
                end
            else
                # Non-crystalized bridge: always flip, biased by strength + confidence.
                if !confidence_biased_bridge_coinflip(partner_ref, br.base_confidence)
                    continue
                end
            end

            # GRUG: JIT CONFIDENCE — pre-baked at bridge time, just apply jitter now!
            # Same as old fire_attachments! but using CascadeBridge.base_confidence.
            # Floor of 0.1 so bridged nodes always have SOME voice.
            # NONJITTER honor and VOTE-LEVEL OVERRIDE still apply — same single-source-of-truth.
            jitter = jitter_allowed_for(partner_ref, br.base_confidence) ?
                     randn() * RELAY_CONF_JITTER_SIGMA :
                     0.0
            confidence = max(0.1, br.base_confidence + jitter)

            # GRUG: MATCH-BOUNDARY HANDOFF! The seam tokens are the bridge payload.
            # At fire time, if we have an unmatched_tail from the scanner, those
            # tokens are the seam. If the bridge already has seam_tokens from
            # bridge creation time, those are used instead (backward compat).
            # For generative context, we return the seam as a text string.
            actual_seam = isempty(unmatched_tail) ? br.seam_tokens : unmatched_tail
            seam_text = join(actual_seam, " ")

            # GRUG: For cross-lobe bridges, log the handoff with provenance.
            # This is the key diagnostic — you can see exactly which lobe sent
            # what to which lobe through which seam.
            if is_cross_lobe
                println("[ENGINE] 🌉  Cross-lobe cascade: '$source_id' ($source_lobe) → '$(br.partner_id)' ($partner_lobe) | seam=\"$seam_text\" | conf=$(round(confidence, digits=3))")
            end

            push!(fired, (br.partner_id, confidence, seam_text))
            current_active += 1

            # GRUG: Bump strength on the partner node (it got used!)
            bump_strength!(partner_ref)

            println("[ENGINE] ⚡  Cascade handoff: '$(br.partner_id)' fired via bridge from '$source_id' (conf=$(round(confidence, digits=3)), seam=\"$(first(seam_text, 40))\")")
        end
    end

    return fired
end

# GRUG: Backward-compat wrapper — old fire_attachments! calls still work.
# Without unmatched_tail, uses the bridge's stored seam_tokens.
function fire_attachments!(target_id::String, active_count::Int, active_cap::Int)::Vector{Tuple{String, Float64, String}}
    return fire_cascades!(target_id, active_count, active_cap)
end

"""
    get_bridge_summary()::String

GRUG v8.0: Return human-readable summary of all node bridges for /nodes or /status.
Shows bidirectional bridges with provenance, seam tokens, and crystalize status.
"""
function get_bridge_summary()::String
    lines = String[]
    # GRUG v8.0 FIX: Acquire locks in consistent order (BRIDGE_LOCK → NODE_LOCK is wrong,
    # can deadlock against bridge_nodes! which does NODE_LOCK → BRIDGE_LOCK).
    # Fix: snapshot bridge data under BRIDGE_LOCK, then read nodes under NODE_LOCK separately.
    bridge_data = lock(BRIDGE_LOCK) do
        if isempty(BRIDGE_MAP)
            return Tuple{String, Vector{CascadeBridge}}[]
        end
        collect(BRIDGE_MAP)
    end
    if isempty(bridge_data)
        return "[BRIDGE MAP EMPTY]"
    end
    push!(lines, "=== BRIDGE MAP ($(length(bridge_data)) nodes with bridges) ===")
    # GRUG: Read partner status under NODE_LOCK only
    partner_status_map = Dict{String, String}()
    lock(NODE_LOCK) do
        for (node_id, bridges) in bridge_data
            for br in bridges
                if !haskey(partner_status_map, br.partner_id)
                    n = get(NODE_MAP, br.partner_id, nothing)
                    partner_status_map[br.partner_id] = isnothing(n) ? "[MISSING]" : (n.is_grave ? "[GRAVE]" : "[ALIVE str=$(round(n.strength, digits=1))]")
                end
            end
        end
    end
    # GRUG: Now format output without holding any lock (using snapshots)
    shown_pairs = Set{Tuple{String,String}}()
    for (node_id, bridges) in sort(bridge_data, by=x->x[1])
        push!(lines, "  🌉 $node_id ($(length(bridges))/$MAX_BRIDGES bridges):")
        for br in bridges
            partner_status = get(partner_status_map, br.partner_id, "[UNKNOWN]")
            crystal_tag = br.is_crystalized ? " 💎[CRYSTAL:$(br.crystal_origin)]" : ""
            cross_tag = br.source_lobe != "" ? " [from_lobe=$(br.source_lobe)]" : ""
            seam_preview = isempty(br.seam_tokens) ? "(dynamic)" : "\"$(join(br.seam_tokens[1:min(5, length(br.seam_tokens))], " "))$(length(br.seam_tokens) > 5 ? "..." : "")\""
            push!(lines, "      ↔ $(br.partner_id) $partner_status$crystal_tag$cross_tag | base_conf=$(round(br.base_confidence, digits=3)) | seam=$seam_preview")
        end
    end
    return join(lines, "\n")
end

# GRUG: Backward compat alias
get_attachment_summary() = get_bridge_summary()

"""
    get_bridges_for_node(node_id::String)::Vector{CascadeBridge}

GRUG v8.0: Get the list of bridges for a specific node.
Returns empty vector if no bridges exist.
"""
function get_bridges_for_node(node_id::String)::Vector{CascadeBridge}
    return lock(() -> get(BRIDGE_MAP, node_id, CascadeBridge[]), BRIDGE_LOCK)
end

# GRUG: Backward compat alias
get_attachments_for_target(target_id::String) = get_bridges_for_node(target_id)

# ==============================================================================
# CRYSTALIZE — manual + auto crystalization of attached nodes
# ==============================================================================
# GRUG: A crystalized attached node SKIPS the strength-biased coinflip in
# fire_attachments! and ALWAYS fires when its target fires. Two ways to
# crystalize:
#   1. Manual:  user calls /crystalize <target_id> <attach_id>     (origin=:user)
#   2. Auto:    background sweep marks high-strength + high-semantic-truth
#               attachments as crystalized. Auto-marks are revoked when the
#               attached node's strength drops below CRYSTAL_AUTO_STRENGTH_FLOOR.
# Manual marks are sticky — only /decrystalize removes them.

# GRUG: Tunables for auto-crystalization. Tuned conservative so only nodes
# that have proven themselves get the always-fire privilege.
const CRYSTAL_AUTO_STRENGTH_FLOOR  = 5.0   # node.strength >= this to auto-crystallize
const CRYSTAL_AUTO_SEMANTIC_FLOOR  = 0.7   # mean relational-truth score >= this
const CRYSTAL_AUTO_REVOKE_FLOOR    = 3.0   # auto-crystal revoked if strength drops below this

"""
    crystalize_bridge!(node_a::String, node_b::String; origin::Symbol=:user)::String

GRUG v8.0: Mark the bridge between node_a and node_b as crystalized so it
fires unconditionally on partner activation. Crystallizes BOTH sides of the
bidirectional bridge (both A→B and B→A entries). Returns a status string.
Errors if no such bridge exists.

`origin` should be `:user` for manual marks (sticky) or `:auto` for
auto-crystallizer marks (revocable when strength drops).
"""
function crystalize_bridge!(node_a::String, node_b::String;
                            origin::Symbol = :user)::String
    if origin ∉ (:user, :auto)
        error("!!! FATAL: crystalize_bridge! origin must be :user or :auto, got :$origin !!!")
    end
    found_a = false
    found_b = false
    msg = ""
    lock(BRIDGE_LOCK) do
        # GRUG: Crystalize A→B entry
        bridges_a = get(BRIDGE_MAP, node_a, CascadeBridge[])
        for br in bridges_a
            if br.partner_id == node_b
                if br.is_crystalized && br.crystal_origin == origin
                    msg = "Bridge $node_a→$node_b already crystalized (origin=:$(origin))."
                else
                    br.is_crystalized = true
                    br.crystal_origin = origin
                    msg = "💎 Bridge $node_a↔$node_b CRYSTALIZED (origin=:$(origin)). Always fires."
                end
                found_a = true
                break
            end
        end

        # GRUG: Crystalize B→A entry (bidirectional!)
        bridges_b = get(BRIDGE_MAP, node_b, CascadeBridge[])
        for br in bridges_b
            if br.partner_id == node_a
                if br.is_crystalized && br.crystal_origin != origin
                    # Already crystalized from different origin — upgrade if :user overrides :auto
                    if origin == :user
                        br.is_crystalized = true
                        br.crystal_origin = origin
                    end
                else
                    br.is_crystalized = true
                    br.crystal_origin = origin
                end
                found_b = true
                break
            end
        end
    end
    if !found_a && !found_b
        error("!!! FATAL: crystalize_bridge! found no bridge between '$node_a' and '$node_b' !!!")
    end
    return msg
end

# GRUG: Backward compat wrapper — old crystalize_attachment! calls still work
function crystalize_attachment!(target_id::String, attach_id::String;
                                origin::Symbol = :user)::String
    return crystalize_bridge!(target_id, attach_id; origin=origin)
end

"""
    decrystalize_bridge!(node_a::String, node_b::String; force::Bool=false)::String

GRUG v8.0: Clear the crystalize tag on both sides of a bidirectional bridge.
By default this only clears `:auto` marks (so the auto-revoker can't
accidentally remove a manual mark). Pass `force=true` to also clear `:user`
marks (used by /decrystalize). Both sides are decrystalized.
"""
function decrystalize_bridge!(node_a::String, node_b::String;
                              force::Bool = false)::String
    found = false
    msg = ""
    lock(BRIDGE_LOCK) do
        # GRUG: Decrystalize A->B entry
        bridges_a = get(BRIDGE_MAP, node_a, CascadeBridge[])
        for br in bridges_a
            if br.partner_id == node_b
                if !br.is_crystalized
                    msg = "Bridge $node_a<->$node_b was not crystalized."
                elseif br.crystal_origin == :user && !force
                    msg = "Bridge $node_a<->$node_b is :user-crystalized -- pass force=true (or use /decrystalize)."
                else
                    prev = br.crystal_origin
                    br.is_crystalized = false
                    br.crystal_origin = :none
                    msg = "Bridge $node_a<->$node_b de-crystalized (was :$prev)."
                end
                found = true
                break
            end
        end

        # GRUG: Decrystalize B->A entry (bidirectional!)
        bridges_b = get(BRIDGE_MAP, node_b, CascadeBridge[])
        for br in bridges_b
            if br.partner_id == node_a
                if br.is_crystalized
                    if br.crystal_origin == :user && !force
                        # Don't clear :user marks without force
                    else
                        br.is_crystalized = false
                        br.crystal_origin = :none
                    end
                end
                found = true
                break
            end
        end
    end
    if !found
        error("!!! FATAL: decrystalize_bridge! found no bridge between '$node_a' and '$node_b' !!!")
    end
    return msg
end

# GRUG: Backward compat wrapper
function decrystalize_attachment!(target_id::String, attach_id::String;
                                  force::Bool = false)::String
    return decrystalize_bridge!(target_id, attach_id; force=force)
end


"""
    _semantic_truth_score(node) -> Float64

GRUG: Cheap semantic-truth proxy used by the auto-crystallizer. Returns a
score in [0,1] based on how well a node's relational triples are anchored:
  - fraction of triples whose verb is a registered relation class verb
  - bonus for required_relations (declared semantic anchors)
  - bonus for non-empty relation_weights map (intentional weighting)
"""
function _semantic_truth_score(node)::Float64
    triples = node.relational_patterns
    n_triples = length(triples)
    if n_triples == 0 && isempty(node.required_relations)
        return 0.0
    end

    known_verbs = try
        Set(lowercase.(SemanticVerbs.get_all_verbs()))
    catch
        Set{String}()
    end

    matched = 0
    for t in triples
        v = lowercase(strip(t.relation))
        if v in known_verbs
            matched += 1
        end
    end
    triple_score = n_triples == 0 ? 0.0 : matched / n_triples

    req_bonus  = isempty(node.required_relations) ? 0.0 : 0.20
    wts_bonus  = isempty(node.relation_weights)   ? 0.0 : 0.10

    return clamp(triple_score + req_bonus + wts_bonus, 0.0, 1.0)
end

"""
    auto_crystalize_sweep!() -> Tuple{Int, Int}

GRUG v8.0: Walk every bridge in BRIDGE_MAP. Auto-crystallize bridges
whose partner node has BOTH:
  - strength >= CRYSTAL_AUTO_STRENGTH_FLOOR, AND
  - semantic_truth_score >= CRYSTAL_AUTO_SEMANTIC_FLOOR
Auto-revoke bridges previously auto-crystalized whose partner strength has
dropped below CRYSTAL_AUTO_REVOKE_FLOOR. Manual (`:user`) marks are never
touched. Bidirectional: crystallizing one side also crystallizes the partner side.

Called from the idle / phagy sweep loop. Cheap to run — O(bridges).
"""
function auto_crystalize_sweep!()::Tuple{Int, Int}
    crystallized = 0
    revoked = 0
    # GRUG v8.0 FIX: Lock ordering must be NODE_LOCK → BRIDGE_LOCK (same as bridge_nodes!).
    # Previously this held BRIDGE_LOCK while acquiring NODE_LOCK (line 2532), which
    # could deadlock against bridge_nodes! holding NODE_LOCK and waiting for BRIDGE_LOCK.
    # Fix: snapshot all bridge data under BRIDGE_LOCK first, then read nodes under NODE_LOCK,
    # then apply mutations under BRIDGE_LOCK. No nested locks.
    
    # Step 1: Snapshot bridge entries under BRIDGE_LOCK
    bridge_snapshots = lock(BRIDGE_LOCK) do
        snapshots = Tuple{String, CascadeBridge, String}[]  # (node_id, bridge, partner_id)
        for (node_id, bridges) in BRIDGE_MAP
            for br in bridges
                push!(snapshots, (node_id, br, br.partner_id))
            end
        end
        snapshots
    end
    
    # Step 2: Read source AND partner node data under NODE_LOCK (no BRIDGE_LOCK held)
    # GRUG v8.0: Both sides must be strong for auto-crystallization. Previously
    # only the partner was checked — now source node must also exceed the floor.
    node_data = Dict{String, Tuple{Bool, Float64, Float64}}()  # node_id => (is_grave, strength, semantic_truth)
    lock(NODE_LOCK) do
        for (node_id, _br, partner_id) in bridge_snapshots
            for nid in (node_id, partner_id)
                if !haskey(node_data, nid)
                    n = get(NODE_MAP, nid, nothing)
                    if isnothing(n)
                        node_data[nid] = (true, 0.0, 0.0)  # treat missing as grave
                    else
                        node_data[nid] = (n.is_grave, n.strength, _semantic_truth_score(n))
                    end
                end
            end
        end
    end
    
    # Step 3: Apply mutations under BRIDGE_LOCK only (no NODE_LOCK held)
    lock(BRIDGE_LOCK) do
        for (node_id, br, partner_id) in bridge_snapshots
            # Re-verify the bridge still exists (could have been unbridged between steps)
            current_bridges = get(BRIDGE_MAP, node_id, CascadeBridge[])
            if !(br in current_bridges)
                continue
            end

            sd = get(node_data, node_id, (true, 0.0, 0.0))
            source_is_grave, source_strength, source_semantic = sd
            source_is_grave && continue

            pd = get(node_data, partner_id, (true, 0.0, 0.0))
            partner_is_grave, partner_strength, partner_semantic = pd
            partner_is_grave && continue

            if br.is_crystalized && br.crystal_origin == :auto
                # GRUG v8.0: Revoke if EITHER side drops below revoke floor.
                # Crystallization is a mutual commitment — both sides must maintain strength.
                if source_strength < CRYSTAL_AUTO_REVOKE_FLOOR ||
                   partner_strength < CRYSTAL_AUTO_REVOKE_FLOOR
                    br.is_crystalized = false
                    br.crystal_origin = :none
                    # GRUG: Also decrystalize the partner side (bidirectional)
                    partner_bridges = get(BRIDGE_MAP, partner_id, CascadeBridge[])
                    for pbr in partner_bridges
                        if pbr.partner_id == node_id && pbr.crystal_origin == :auto
                            pbr.is_crystalized = false
                            pbr.crystal_origin = :none
                        end
                    end
                    revoked += 1
                end
            elseif !br.is_crystalized
                # GRUG v8.0: BOTH source AND partner must exceed thresholds.
                # It takes two strong nodes to form a crystal bond — one strong
                # side isn't enough. This prevents weak nodes from free-riding
                # on a strong partner's crystal status.
                if source_strength >= CRYSTAL_AUTO_STRENGTH_FLOOR &&
                   source_semantic >= CRYSTAL_AUTO_SEMANTIC_FLOOR &&
                   partner_strength >= CRYSTAL_AUTO_STRENGTH_FLOOR &&
                   partner_semantic >= CRYSTAL_AUTO_SEMANTIC_FLOOR
                    br.is_crystalized = true
                    br.crystal_origin = :auto
                    # GRUG: Also crystalize the partner side (bidirectional)
                    partner_bridges = get(BRIDGE_MAP, partner_id, CascadeBridge[])
                    for pbr in partner_bridges
                        if pbr.partner_id == node_id && !pbr.is_crystalized
                            pbr.is_crystalized = true
                            pbr.crystal_origin = :auto
                        end
                    end
                    crystallized += 1
                end
            end
            # :user marks are sticky — never auto-touched.
        end
    end
    return (crystallized, revoked)
end

"""
    is_bridge_crystalized(node_a::String, node_b::String) -> Bool

GRUG v8.0: Convenience query. Returns false if bridge doesn't exist.
"""
function is_bridge_crystalized(node_a::String, node_b::String)::Bool
    return lock(() -> begin
        bridges = get(BRIDGE_MAP, node_a, CascadeBridge[])
        for br in bridges
            br.partner_id == node_b && return br.is_crystalized
        end
        return false
    end, BRIDGE_LOCK)
end

# GRUG: Backward compat alias
is_crystalized(target_id::String, attach_id::String) = is_bridge_crystalized(target_id, attach_id)

# ==============================================================================
# IMAGE NODE ATTACHMENT (SDF-BASED RELATIONAL FIRE)
# ==============================================================================

# GRUG: /imgnodeAttach does everything /nodeAttach does but for IMAGE NODES.
# Instead of text connector patterns, uses image binary converted to nonlinear
# SDF at attach time (JIT GPU accel). Confidence is baked from SDF signal
# similarity — the cosine similarity between the connector SDF signal and the
# attached image node's own SDF signal. Same error-first philosophy, same
# validation, same AttachedNode struct (pattern stores "SDF:<format>:<w>x<h>"
# metadata, signal stores the SDF-derived signal vector).

"""
_sdf_signal_similarity(sig_a::Vector{Float64}, sig_b::Vector{Float64})::Float64

GRUG: Cosine similarity between two SDF-derived signal vectors.
This is the image-domain equivalent of _token_overlap_similarity for text.
Returns [0.0, 1.0] — 1.0 means identical SDF activations.
Errors on empty signals (NO silent failures).
"""
function _sdf_signal_similarity(sig_a::Vector{Float64}, sig_b::Vector{Float64})::Float64
    if isempty(sig_a)
        error("!!! FATAL: _sdf_signal_similarity got empty sig_a! Image SDF signals must not be empty! !!!")
    end
    if isempty(sig_b)
        error("!!! FATAL: _sdf_signal_similarity got empty sig_b! Image SDF signals must not be empty! !!!")
    end

    # GRUG: Truncate to the shorter signal length for fair comparison.
    # SDF signals may differ in length if images have different resolutions.
    min_len = min(length(sig_a), length(sig_b))
    a = @view sig_a[1:min_len]
    b = @view sig_b[1:min_len]

    # GRUG: Cosine similarity = dot(a,b) / (||a|| * ||b||)
    dot_product = sum(a .* b)
    norm_a = sqrt(sum(a .^ 2))
    norm_b = sqrt(sum(b .^ 2))

    # GRUG: If either norm is zero (black image / null signal), similarity is 0.0.
    if norm_a < 1e-12 || norm_b < 1e-12
        return 0.0
    end

    # GRUG: Clamp to [0.0, 1.0] — negative cosine means anti-correlated SDF,
    # which we treat as zero similarity for confidence purposes.
    return clamp(dot_product / (norm_a * norm_b), 0.0, 1.0)
end

"""
attach_image_node!(target_id::String, attach_id::String, image_data::Vector{UInt8}, width::Int, height::Int)::String

GRUG: Bolt an IMAGE NODE onto a target node with SDF-based relational fire.
Does everything attach_node! does but for image nodes:
  1. Validates both nodes exist, are alive, and attach_id IS an image node
  2. Converts image binary to nonlinear SDF at attach time (JIT GPU accel)
  3. Computes base_confidence from SDF signal similarity (cosine sim)
  4. Stores the SDF signal + base_confidence in the AttachedNode struct
  5. Pattern field stores metadata: "SDF:<format>:<width>x<height>" for AIML ref

JIT GPU ACCEL: JITGPU(binary) dispatches real KernelAbstractions.jl kernels —
CUDABackend() on NVIDIA, ROCBackend() on AMD, MetalBackend() on Apple Silicon,
CPU() (multithreaded) on CI/no-GPU. The expensive image→SDF conversion + similarity
computation happens ONCE here at attach time. At fire time, only jitter is applied
to the pre-baked base_confidence. Same as text JIT baking but with SDF math.

Validation (error-first, NO silent failures):
  - target_id must exist in NODE_MAP and not be grave
  - attach_id must exist in NODE_MAP, not be grave, AND must be an image node
  - target_id ≠ attach_id (no self-attachment)
  - target cannot already have MAX_ATTACHMENTS (4) attached nodes
  - attach_id cannot already be attached to this target (no duplicate bolts)
  - image_data must not be empty
  - width and height must be > 0

Returns confirmation string on success.
"""
function attach_image_node!(target_id::String, attach_id::String, image_data::Vector{UInt8}, width::Int, height::Int)::String
    if strip(target_id) == ""
        error("!!! FATAL: attach_image_node! got empty target_id! Grug needs a real target! !!!")
    end
    if strip(attach_id) == ""
        error("!!! FATAL: attach_image_node! got empty attach_id! Grug needs a real node to attach! !!!")
    end
    if target_id == attach_id
        error("!!! FATAL: attach_image_node! target '$target_id' cannot attach to itself! That's a mirror, not a relay! !!!")
    end
    if isempty(image_data)
        error("!!! FATAL: attach_image_node! got empty image_data! Cannot create SDF from nothing! !!!")
    end
    if width <= 0 || height <= 0
        error("!!! FATAL: attach_image_node! got invalid dimensions: $(width)x$(height)! Both must be > 0! !!!")
    end

    # GRUG: Validate both nodes exist and are alive, and attach_id is an image node
    lock(NODE_LOCK) do
        if !haskey(NODE_MAP, target_id)
            error("!!! FATAL: attach_image_node! target node '$target_id' does not exist on the map! !!!")
        end
        if !haskey(NODE_MAP, attach_id)
            error("!!! FATAL: attach_image_node! attach node '$attach_id' does not exist on the map! !!!")
        end
        target_node = NODE_MAP[target_id]
        attach_node_ref = NODE_MAP[attach_id]
        if target_node.is_grave
            error("!!! FATAL: attach_image_node! target node '$target_id' is GRAVE [$(target_node.grave_reason)]! Cannot attach to dead nodes! !!!")
        end
        if attach_node_ref.is_grave
            error("!!! FATAL: attach_image_node! attach node '$attach_id' is GRAVE [$(attach_node_ref.grave_reason)]! Cannot attach dead nodes! !!!")
        end
        if !attach_node_ref.is_image_node
            error("!!! FATAL: attach_image_node! node '$attach_id' is NOT an image node! Use /nodeBridge for text nodes! !!!")
        end
    end

    # GRUG: JIT GPU ACCEL — Convert image binary to nonlinear SDF at attach time!
    # JITGPU() dispatches real KernelAbstractions kernels: CUDABackend() on NVIDIA,
    # ROCBackend() on AMD, MetalBackend() on Apple Silicon, CPU() on CI/no-GPU.
    # This is the expensive computation that happens ONCE, not every fire cycle.
    connector_sdf = ImageSDF.JITGPU(image_data; width=width, height=height)
    connector_signal = ImageSDF.sdf_to_signal(connector_sdf)

    # GRUG v8.0: JIT CONFIDENCE BAKING — SDF cosine similarity + strength bonus.
    # Now bidirectional: compute confidence for both directions.
    # A→B uses B's strength, B→A uses A's strength. Same SDF similarity.
    jit_conf_target_to_attach = lock(NODE_LOCK) do
        attach_node_ref = NODE_MAP[attach_id]
        if isempty(attach_node_ref.signal)
            return 0.3
        end
        sdf_sim = _sdf_signal_similarity(connector_signal, attach_node_ref.signal)
        strength_bonus = attach_node_ref.strength / STRENGTH_CAP
        return sdf_sim + (strength_bonus * 0.5)
    end

    jit_conf_attach_to_target = lock(NODE_LOCK) do
        target_node = NODE_MAP[target_id]
        if isempty(target_node.signal)
            # GRUG: Text node with no signal — use flat baseline
            return 0.3
        end
        sdf_sim = _sdf_signal_similarity(connector_signal, target_node.signal)
        strength_bonus = target_node.strength / STRENGTH_CAP
        return sdf_sim + (strength_bonus * 0.5)
    end

    # GRUG: Seam tokens for image bridges use SDF metadata as the seam marker
    sdf_seam = ["SDF:image:$(width)x$(height)"]

    # GRUG: Resolve lobe provenance
    lobe_target = _safe_find_lobe(target_id)
    lobe_attach = _safe_find_lobe(attach_id)

    lock(BRIDGE_LOCK) do
        # GRUG: Check bridge caps on BOTH sides (bidirectional!)
        existing_target = get(BRIDGE_MAP, target_id, CascadeBridge[])
        if length(existing_target) >= MAX_BRIDGES
            error("!!! FATAL: attach_image_node! target '$target_id' already has $(length(existing_target)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end
        existing_attach = get(BRIDGE_MAP, attach_id, CascadeBridge[])
        if length(existing_attach) >= MAX_BRIDGES
            error("!!! FATAL: attach_image_node! image node '$attach_id' already has $(length(existing_attach)) bridges (max $MAX_BRIDGES)! Unbridge one first! !!!")
        end

        # GRUG: Check for duplicate bridge (either direction)
        for br in existing_target
            if br.partner_id == attach_id
                error("!!! FATAL: attach_image_node! '$attach_id' is already bridged to '$target_id'! No duplicate bridges! !!!")
            end
        end
        for br in existing_attach
            if br.partner_id == target_id
                error("!!! FATAL: attach_image_node! '$target_id' is already bridged to '$attach_id'! No duplicate bridges! !!!")
            end
        end

        # GRUG: Create bidirectional bridge entries!
        bridge_target_to_attach = CascadeBridge(attach_id, sdf_seam, jit_conf_target_to_attach, lobe_attach, false, :none)
        bridge_attach_to_target = CascadeBridge(target_id, sdf_seam, jit_conf_attach_to_target, lobe_target, false, :none)

        push!(existing_target, bridge_target_to_attach)
        BRIDGE_MAP[target_id] = existing_target
        push!(existing_attach, bridge_attach_to_target)
        BRIDGE_MAP[attach_id] = existing_attach
    end

    n_bridged_target = lock(() -> length(get(BRIDGE_MAP, target_id, CascadeBridge[])), BRIDGE_LOCK)
    n_bridged_attach = lock(() -> length(get(BRIDGE_MAP, attach_id, CascadeBridge[])), BRIDGE_LOCK)
    println("[ENGINE] 🖼️🌉  Image bridge: '$target_id' ↔ '$attach_id' via SDF ($(width)x$(height), conf_T→A=$(round(jit_conf_target_to_attach, digits=3)), conf_A→T=$(round(jit_conf_attach_to_target, digits=3)), T: $n_bridged_target/$MAX_BRIDGES, A: $n_bridged_attach/$MAX_BRIDGES)")
    return "Bridged image '$attach_id' ↔ '$target_id' via SDF ($(width)x$(height), conf_T→A=$(round(jit_conf_target_to_attach, digits=3)), A→T=$(round(jit_conf_attach_to_target, digits=3)))"
end

# ==============================================================================
# THROTTLE RESET
# ==============================================================================

"""
reset_throttle!(node::Node, relational_match_strength::Float64)

GRUG: Reset a node's throttle based on relational match strength.
Maps strength to smooth heat between 0.3 (cold) and 1.0 (hot) via
continuous mapping instead of binary hot/cold. Thread-safe via NODE_LOCK.
"""
function reset_throttle!(node::Node, relational_match_strength::Float64)
    # GRUG FIX 2.4: Continuous Throttle Mapping!
    # Instead of binary hot/cold, Grug map relational strength to smooth heat between 0.3 and 1.0.
    lock(NODE_LOCK) do
        node.throttle = clamp(relational_match_strength / 2.0, 0.3, 1.0)
    end
end

# ==============================================================================
# NODE CREATION
# ==============================================================================

"""
create_node(pattern, action_packet, data, drop_table; is_image_node=false, is_antimatch_node=false, initial_strength=1.0)::String

GRUG: Grow a new node in the cave. Returns the new node's ID.
If is_image_node=true, pattern is treated as SDF binary data (not text).
If is_antimatch_node=true, node is an anti-match: pattern-activated but vote-silent,
drains confidence from regular votes in the same lobe. No strength dynamics.
New nodes automatically try to latch onto the strongest similar existing node.
"""
function create_node(
    pattern::String,
    action_packet::String,
    data::Dict,
    drop_table::Vector{String};
    is_image_node::Bool  = false,
    is_antimatch_node::Bool = false,
    initial_strength::Float64 = 1.0
)::String
    if strip(pattern) == ""
        error("!!! FATAL: Grug cannot grow node with empty pattern! !!!")
    end
    if strip(action_packet) == ""
        error("!!! FATAL: Grug cannot grow node with empty action packet! !!!")
    end

    # GRUG FIX 2.9: Catch bad action packets before planting rotten seed!
    try
        parse_action_packet(action_packet)
    catch e
        error("!!! FATAL: Grug tried to grow node but action packet is rotten: $(e) !!!")
    end

    req_rels = haskey(data, "required_relations") ? convert(Vector{String}, data["required_relations"]) : String[]
    rel_wts  = haskey(data, "relation_weights")   ? convert(Dict{String, Float64}, data["relation_weights"]) : Dict{String, Float64}()

    rels = extract_relational_triples(pattern)

    # GRUG v7.21c-1: Allow nodes to declare auxiliary triples that aren't
    # extractable from the pattern itself. Use case: a node like `"i feel"`
    # has only 2 tokens (no verb-flanked triple available from the pattern),
    # but the seed author knows the conceptual triples are
    # ("feeling", "felt_by", "person"). data["aux_triples"] is a vector of
    # 3-element [subject, relation, object] entries that get merged in here.
    if haskey(data, "aux_triples") && isa(data["aux_triples"], AbstractVector)
        for t in data["aux_triples"]
            if isa(t, AbstractVector) && length(t) >= 3
                push!(rels, RelationalTriple(
                    String(t[1]),
                    String(t[2]),
                    String(t[3]),
                ))
            elseif isa(t, AbstractDict)
                push!(rels, RelationalTriple(
                    String(get(t, "subject", "")),
                    String(get(t, "relation", "")),
                    String(get(t, "object",  "")),
                ))
            end
        end
    end

    # GRUG: Bake word rocks into signal immediately!
    # For image nodes, signal will be set after SDF conversion. Use empty placeholder.
    node_signal = is_image_node ? Float64[] : words_to_signal(pattern)

    # GRUG: Compute Hopfield key from pattern for fast familiar-input lookup
    hopfield_key = is_image_node ? UInt64(0) : hash(join(split(lowercase(strip(pattern))), " "))

    # GRUG: Clamp initial strength to valid range
    clamped_strength = clamp(initial_strength, STRENGTH_FLOOR, STRENGTH_CAP)

    id = "node_$(atomic_add!(ID_COUNTER, 1))"
    new_node = Node(
        id, pattern, node_signal, action_packet, data, drop_table,
        0.5,          # throttle
        rels, req_rels, rel_wts,
        clamped_strength,   # strength
        is_image_node,      # is_image_node
        is_antimatch_node,  # is_antimatch_node
        String[],           # neighbor_ids
        false,              # is_unlinkable
        rand(LATCH_PARTNER_CAP_MIN:LATCH_PARTNER_CAP_MAX),  # max_neighbors (per-node 8-16 roll)
        false,              # is_grave
        "",                 # grave_reason
        Float64[],          # response_times (big-O ledger)
        time(),             # ledger_last_cleared
        hopfield_key,       # hopfield_key
        false,              # fired_this_cycle
        false,              # voted_this_cycle
        false,              # gained_this_cycle
        0.0                 # strength_delta_this_cycle
    )

    lock(NODE_LOCK) do
        NODE_MAP[id] = new_node
    end

    # GRUG: NEW NODE LATCH! Find best similar strong neighbor and link up.
    # Only for text nodes (image nodes use SDF similarity, not token overlap).
    # GRUG: LATCH GATE — only activate latching once map is big enough.
    # Below NODE_LATCH_THRESHOLD, token overlap similarity is not statistically
    # meaningful (too few nodes = junk topology from forced links). Above the
    # threshold the map has enough diversity that similarity scores are real.
    map_size = lock(() -> length(NODE_MAP), NODE_LOCK)
    latched_to_id = nothing
    # GRUG v7.49: Anti-match nodes skip latching — they don't compete,
    # don't need neighbors, and don't participate in chatter groups.
    if !is_image_node && !is_antimatch_node && map_size >= NODE_LATCH_THRESHOLD
        latch_target_id = find_best_latch_target(new_node)
        if !isnothing(latch_target_id)
            target_node = lock(() -> get(NODE_MAP, latch_target_id, nothing), NODE_LOCK)
            if !isnothing(target_node)
                linked = try_link_nodes!(new_node, target_node)
                if linked
                    latched_to_id = latch_target_id
                    println("[ENGINE] 🌱  Node $id latched onto neighbor $latch_target_id.")
                end
            end
        end
    elseif !is_image_node && !is_antimatch_node && map_size < NODE_LATCH_THRESHOLD
        # GRUG: Map too small for meaningful latching. Node plants clean with no forced links.
        # User is responsible for explicit drop_table wiring at this scale.
        # Latch will engage automatically once map reaches NODE_LATCH_THRESHOLD nodes.
        @debug "[ENGINE] Latch suppressed for $id (map_size=$map_size < NODE_LATCH_THRESHOLD=$NODE_LATCH_THRESHOLD). Plant clean."
    end

    # GRUG (v7.19): GROUP MEMBERSHIP.
    # Every text node belongs to exactly one chatter group. Groups are how
    # the chatter ritual addresses bundles of similar-pattern nodes without
    # recomputing similarity each cycle.
    #   - If we latched onto an existing partner: join that partner group.
    #     If the partner has no group (predates v7.19), seed a fresh group on
    #     the partner first, then join.
    #   - v7.56a: Time-node isolation — if add_to_group! rejects the join
    #     (time node trying to join non-time group or vice versa), the node
    #     seeds its own group instead.
    #   - If we did not latch (small map, no candidates, or partner full):
    #     seed a new group with this node as the founder.
    # Image nodes and anti-match nodes do not chatter — skip groups.
    if !is_image_node && !is_antimatch_node
        try
            if !isnothing(latched_to_id)
                partner_grp = group_for(latched_to_id)
                if isnothing(partner_grp)
                    partner_node = lock(() -> get(NODE_MAP, latched_to_id, nothing), NODE_LOCK)
                    if !isnothing(partner_node)
                        partner_grp = register_group!(partner_node)
                    end
                end
                if !isnothing(partner_grp)
                    joined = add_to_group!(partner_grp, id)
                    # GRUG v7.56a: If join was rejected (time-node isolation gate),
                    # seed a new group for this node instead of leaving it groupless.
                    if !joined
                        register_group!(new_node)
                    end
                else
                    register_group!(new_node)
                end
            else
                register_group!(new_node)
            end
        catch e
            @warn "[ENGINE] Group registration failed for $id: $e"
        end
    end

    return id
end

# ==============================================================================
# STOCHASTIC PACKET PARSER
# ==============================================================================

"""
parse_action_packet(packet::String)

GRUG: Parse an action packet string into structured action items.

## Format (pipe-delimited so action names can contain commas):
    "action[neg1, neg2]^weight | action2[neg3]^weight | action3^weight"

## Rules:
  - Actions separated by `|` (pipe), NOT comma.
  - Inline negatives per action: `action[dont do this, dont do that]^weight`
  - Weight optional; defaults to 1.0 if omitted.
  - Negatives optional; action without brackets has no negatives.
  - Weight must be > 0.0.

## Returns:
  - positives: Vector{Tuple{String, Float64}} — (action_name, weight) pairs (for select_action)
  - all_negatives: Vector{String} — deduped union of all action negatives (for Vote compat)
  - action_items: Vector{Tuple{String, Float64, Vector{String}}} — full per-action data
"""
function parse_action_packet(packet::String)
    if strip(packet) == ""
        error("!!! FATAL: Grug cannot parse empty action packet! !!!")
    end

    # GRUG: Actions are pipe-delimited. Pipes let action names contain commas.
    action_items = Vector{Tuple{String, Float64, Vector{String}}}()

    for part in split(packet, '|')
        p = strip(part)
        isempty(p) && continue

        action_negatives = String[]

        # GRUG: Match inline negatives: "action_name[neg1, neg2]^weight"
        # Regex groups: (1) action name, (2) negatives block, (3) optional weight after ]^
        inline_match = match(r"^(.+?)\[([^\]]*)\](?:\^([\d.]+))?$", p)

        if !isnothing(inline_match)
            action_name = strip(inline_match.captures[1])
            if isempty(action_name)
                error("!!! FATAL: Grug found empty action name before inline negatives block! Packet: '$packet' !!!")
            end

            # GRUG: Parse comma-separated negatives inside [ ]
            neg_block = inline_match.captures[2]
            for neg in split(neg_block, ',')
                neg_clean = strip(neg)
                !isempty(neg_clean) && push!(action_negatives, neg_clean)
            end

            # GRUG: Parse optional weight after ]^
            weight_str = inline_match.captures[3]
            weight = if !isnothing(weight_str)
                w = tryparse(Float64, strip(weight_str))
                if isnothing(w) || w <= 0.0
                    error("!!! FATAL: Bad weight '$(weight_str)' in action packet! Weight must be > 0.0 !!!")
                end
                w
            else
                1.0
            end

            push!(action_items, (String(action_name), weight, action_negatives))

        else
            # GRUG: No inline negatives. Check for weight suffix: "action_name^weight"
            action_name, weight = if contains(p, '^')
                parts = split(p, '^'; limit=2)
                name  = strip(parts[1])
                if isempty(name)
                    error("!!! FATAL: Grug found empty action name before '^' weight! Packet: '$packet' !!!")
                end
                w = tryparse(Float64, strip(parts[2]))
                if isnothing(w) || w <= 0.0
                    error("!!! FATAL: Bad weight '$(parts[2])' in action packet! Weight must be > 0.0 !!!")
                end
                name, w
            else
                p_name = strip(p)
                if isempty(p_name)
                    error("!!! FATAL: Grug found empty action name token in packet! Packet: '$packet' !!!")
                end
                p_name, 1.0
            end

            push!(action_items, (String(action_name), weight, String[]))
        end
    end

    if isempty(action_items)
        error("!!! FATAL: Grug found no valid actions in packet! Packet was: '$packet' !!!")
    end

    # GRUG: Build backward-compatible positives list (name, weight) for select_action
    positives = Tuple{String, Float64}[(item[1], item[2]) for item in action_items]

    # GRUG: Collect deduped union of all negatives across all actions (for Vote compat)
    seen_negatives = Set{String}()
    all_negatives  = String[]
    for item in action_items
        for neg in item[3]
            if !(neg in seen_negatives)
                push!(all_negatives, neg)
                push!(seen_negatives, neg)
            end
        end
    end

    return positives, all_negatives, action_items
end

"""
select_action(packet::String)

GRUG: Select a single action from an action packet via weighted coinflip.
Parses the packet into positives (weighted actions), picks one stochastically
using CoinFlipHeader bias. Returns the selected action name.
"""
function select_action(packet::String)
    positives, negatives, _ = parse_action_packet(packet)
    total_weight = sum(p[2] for p in positives)
    
    pairs_for_coin = Pair[]
    for (name, weight) in positives
        prob = (weight / total_weight) * 100.0
        push!(pairs_for_coin, bias(Symbol(name), prob) => () -> nothing)
    end
    
    winning_sym = @coinflip pairs_for_coin
    return String(winning_sym), negatives
end

# ==============================================================================
# GRUG ROUTING MECHANICS (WITH ACTIVE LIMIT & COMPLEXITY BASED SCANS)
# ==============================================================================

# ==============================================================================
# COMPLEXITY PRE-SCREENER
# ==============================================================================

"""
# GRUG DOC 2.5: Magic Numbers Explained!
# Base word token = 0.15 weight. 
# Relational triple = 1.5 weight (1 triple = ~10 words of complexity!).
# Thresholds: 
#   < 1.5  (e.g. less than 10 words, no triples) -> Cheap Eye.
#   < 4.5  (e.g. 10-30 words, or 1-2 triples) -> Medium Eye.
#   >= 4.5 (e.g. big paragraph or many gears) -> High-Res Eye.
"""
function screen_input_complexity(signal::Vector{Float64}, triples::Vector{RelationalTriple})::Int
    if isempty(signal)
        # GRUG: If signal empty, scanner will crash later. Scream now!
        error("!!! FATAL: Complexity screener found empty signal! No silent failure! !!!")
    end

    sig_len   = length(signal)
    rel_count = length(triples)
    
    complexity_score = (sig_len * 0.15) + (rel_count * 1.5)

    if complexity_score < 1.5
        return 1
    elseif complexity_score < 4.5
        return 2
    else
        return 3
    end
end

"""
_effective_scan_mode(base_mode::Int, node_signal::Vector{Float64})::Int

GRUG: SELECTIVE PATTERN SCAN — downgrade the scan tier based on node pattern
complexity. The base_mode comes from screen_input_complexity (which looks at
INPUT complexity). But a simple 2-token node pattern doesn't justify a high-res
two-pass scan — cheap_scan would give the same answer with less work.

This is per-node downgrade logic: the scan tier can only go DOWN, never UP.
If the input demands cheap_scan (mode=1), the node can't push it to high_res.
But if the input demands high_res (mode=3), a tiny node pattern drops it back.

Pattern complexity thresholds:
  - signal length ≤ 3 tokens  → mode capped at 1 (cheap scan only, BIDIRECTIONAL)
  - signal length ≤ 8 tokens  → mode capped at 2 (medium scan max)
  - signal length > 8 tokens  → no cap (full tier from input complexity)

BIDIRECTIONAL AT TIER 1: When effective_mode == 1, scan_and_expand uses
_bidirectional_cheap_scan() instead of plain cheap_scan(). Forward + reverse
passes are both run and fused via big_number_small_number_coherence — NOT
averaged — so that agreement on strong signal is rewarded while agreement
on weak/noise signal is correctly suppressed. This catches order-reversed
matches that forward-only scanning would miss — "man bites dog" aligns
with "dog bites man" when the reverse pass runs.

Why: Short patterns have so few signal values that the sliding window
variance penalty in high_res_scan is numerically meaningless, and the
stride optimization in cheap_scan already covers the full signal. Wasting
O(n²) work on a 2-element pattern is cave fire.
"""
function _effective_scan_mode(base_mode::Int, node_signal::Vector{Float64})::Int
    if isempty(node_signal)
        # GRUG: Empty signal means this node can't be scanned at all.
        # Return base_mode and let the scanner throw PatternNotFoundError.
        return base_mode
    end

    sig_len = length(node_signal)

    # GRUG: Short patterns → force cheap scan. The pattern is too small
    # for medium/high-res to add any discriminative value.
    if sig_len <= 3
        return min(base_mode, 1)
    end

    # GRUG: Medium patterns → cap at medium scan. High-res two-pass
    # variance penalty is meaningless with fewer than 8 signal values.
    if sig_len <= 8
        return min(base_mode, 2)
    end

    # GRUG: Complex patterns → full tier from input complexity. These
    # patterns have enough signal to benefit from high-res scanning.
    return base_mode
end

# ==============================================================================
# BIDIRECTIONAL CHEAP SCAN
# ==============================================================================

"""
_bidirectional_cheap_scan(
    target::Vector{Float64},
    pattern::Vector{Float64};
    threshold::Real = 0.3
)::Tuple{Int, Float64}

GRUG: Bidirectional confidence smoothing for tier-1 (cheap scan) patterns.

The signal encoding of words_to_signal is ORDER-SENSITIVE: "dog bites man" and
"man bites dog" produce different signal vectors. A pure forward cheap_scan misses
cases where token overlap is high but word order is reversed — the sliding window
never aligns the reversed pattern against the target.

BIDIRECTIONAL FIX:
  1. Forward scan:  cheap_scan(target, pattern)         — normal left-to-right
  2. Reverse scan:  cheap_scan(target, reverse(pattern)) — reversed pattern signal

COHERENCE FUSION (v7.19 — replaces averaging):
  Both succeed  → coherence = big_number_small_number_coherence(forward_conf, reverse_conf)
                  Two strong confidences that agree -> near 1.0.
                  Two weak confidences that "agree" -> near 0.0 (correctly distrusted).
                  Strong on one side, weak on the other -> penalized by magnitude_mean.
  One succeeds  → coherence = big_number_small_number_coherence(hit_conf, miss_contribution)
                  miss_contribution is just below threshold so a partial reversal gets
                  a moderate coherence, not a spike and not zero.
  Both fail     → rethrow PatternNotFoundError.
                  No match either way. Consistent with single-direction behavior.

WHY COHERENCE BEATS AVERAGING:
  Averaging hides asymmetry: forward=0.9/reverse=0.1 and forward=0.5/reverse=0.5
  both average to 0.5, but one is real disagreement and the other is real agreement.
  Averaging also suffers catastrophic cancellation on close values. Coherence fuses
  |forward - reverse| normalized by max magnitude, then scales by mean magnitude —
  so agreement on strong signal wins, agreement on noise does not.

Called only for effective_mode == 1 (cheap scan tier, simple patterns ≤ 3 signal
elements). Medium and high-res tiers don't need this — they already scan every
index exhaustively, so order sensitivity is minimal at longer pattern lengths.

ERRORS: propagates PatternNotFoundError if both directions miss. NO SILENT FAILURES.

v7.20 NONJITTER KWARG:
  When `nonjitter=true`, the end-confidence snap-back jitter applied to the fused
  coherence output is skipped. This is the per-node opt-out: the caller in
  scan_and_expand passes `nonjitter=is_nonjitter(node)` so that anchor / calibration /
  canonical-form nodes receive bit-stable confidence scores. Per-window jitter
  inside the underlying cheap_scan calls is unaffected — that is a substrate-level
  behavior of the scanner and remains in effect for both forward and reverse passes.
  The NONJITTER tag silences only the post-fusion bounded micro-variance.

v7.20 VOTE-LEVEL OVERRIDE (`jitter_floor`):
  The NONJITTER tag is a *baseline*, not an absolute. If `nonjitter=true` BUT
  the fused coherence comes in below `jitter_floor`, jitter still runs on the
  output. This stops a solidified node from ossifying a low-confidence guess.
  Default `jitter_floor=0.0` preserves the old behavior (no override). The
  scan_and_expand caller passes `jitter_floor=JITTER_CONFIDENCE_FLOOR` to
  activate the override system-wide.
"""
function _bidirectional_cheap_scan(
    target::Vector{Float64},
    pattern::Vector{Float64};
    threshold::Real = 0.3,
    nonjitter::Bool = false,
    jitter_floor::Float64 = 0.0
)::Tuple{Int, Float64}
    if isempty(target)
        # GRUG: Empty target is a scanner crash waiting to happen. Scream now!
        error("!!! FATAL: _bidirectional_cheap_scan got empty target signal! !!!")
    end
    if isempty(pattern)
        # GRUG: Empty pattern means there's nothing to match. No silent failure!
        error("!!! FATAL: _bidirectional_cheap_scan got empty pattern signal! !!!")
    end

    # GRUG: Threshold floor — just below threshold so a miss contributes a near-zero
    # but honest value to the average, rather than harshly dragging it down to 0.
    # This avoids the asymmetry where one direction missing tanks an otherwise good score.
    miss_contribution = max(0.0, Float64(threshold) - 0.01)

    # GRUG: Forward scan — standard left-to-right window alignment.
    forward_idx  = 0
    forward_conf = miss_contribution
    forward_ok   = false
    try
        forward_idx, forward_conf = cheap_scan(target, pattern; threshold=threshold)
        forward_ok = true
    catch e
        if e isa PatternNotFoundError
            # GRUG: Forward direction missed. Not fatal — reverse may still hit.
            forward_conf = miss_contribution
        elseif e isa PatternScanError
            # GRUG: FATAL scanner logic error. Always rethrow. NO SILENT FAILURE!
            rethrow(e)
        else
            error("!!! FATAL: _bidirectional_cheap_scan forward pass got unknown error: $e !!!")
        end
    end

    # GRUG: Reverse scan — reverse the pattern signal so "man bites dog" encoded
    # in reverse becomes equivalent to "dog bites man" forward.
    reverse_conf = miss_contribution
    reverse_ok   = false
    rev_pattern  = reverse(pattern)  # GRUG: New vector, original untouched
    try
        _, reverse_conf = cheap_scan(target, rev_pattern; threshold=threshold)
        reverse_ok = true
    catch e
        if e isa PatternNotFoundError
            # GRUG: Reverse direction also missed. Will check both-fail case below.
            reverse_conf = miss_contribution
        elseif e isa PatternScanError
            rethrow(e)
        else
            error("!!! FATAL: _bidirectional_cheap_scan reverse pass got unknown error: $e !!!")
        end
    end

    # GRUG: Both directions missed — pattern truly not found. Propagate forward error
    # so scan_and_expand gets a PatternNotFoundError and skips this node.
    if !forward_ok && !reverse_ok
        throw(PatternNotFoundError(
            "Bidirectional cheap scan: pattern not found in either direction.",
            miss_contribution
        ))
    end

    # GRUG v7.25: FORWARD-DOMINANT SHORT-CIRCUIT.
    # When the forward scan finds a high-confidence match and the reverse scan
    # misses, the node clearly matches in its natural word order. Penalizing a
    # perfect forward hit because the reversed signal doesn't also match is wrong
    # — the reverse scan exists to catch word-order inversions ("dog bites man"
    # ↔ "man bites dog"), not to gate forward matches. When forward is confident
    # enough, use it directly; the reverse-miss means the word order is correct
    # (not inverted), which is evidence FOR the match, not against it.
    FORWARD_PASSTHROUGH_THRESHOLD = 0.7
    if forward_ok && !reverse_ok && forward_conf >= FORWARD_PASSTHROUGH_THRESHOLD
        smoothed_conf = forward_conf
    elseif reverse_ok && !forward_ok && reverse_conf >= FORWARD_PASSTHROUGH_THRESHOLD
        smoothed_conf = reverse_conf
    else
        # GRUG v7.19: Fuse forward and reverse confidences via big-number/small-number
        # coherence instead of plain averaging. This rewards agreement on strong signal,
        # suppresses agreement on noise, and is immune to catastrophic cancellation
        # between close floats. See PatternScanner.big_number_small_number_coherence
        # for the full formula. If only one direction hit, miss_contribution stands in
        # for the missing side so a partial reversal gets a moderate score instead of
        # a spike (pure average) or a zero (hard drop).
        smoothed_conf = big_number_small_number_coherence(forward_conf, reverse_conf)
    end

    # GRUG v7.20: END-CONFIDENCE SNAP-BACK JITTER.
    # The per-window slight_jitter inside cheap_scan fuzzes each window's score
    # BEFORE fusion. That's substrate-level hardware-variance modelling. Here we
    # add a second, bounded micro-jitter on the fused coherence — the snap-back
    # breath at the decision boundary. This prevents rigid lock-in on identical
    # re-scans and keeps the system biologically plausible.
    #
    # NONJITTER opt-out: if the caller passed nonjitter=true (wired from
    # is_nonjitter(node) at scan_and_expand), we skip this jitter entirely so
    # the output is bit-stable for that node. Global _JITTER_ENABLED in
    # RelationalJitter is not consulted here — that switch governs relational
    # weight jitter, not confidence fusion.
    #
    # v7.20 VOTE-LEVEL OVERRIDE: NONJITTER is a *baseline*, not an absolute.
    # When jitter_floor > 0 and the fused coherence falls below it, jitter
    # runs even on a NONJITTER node. The semantics: a solidified rock that's
    # only 30% sure of itself on this firing is *guessing*, and we don't want
    # to ossify the guess. High-confidence firings (≥ floor) on solidified
    # rocks remain bit-stable. Default jitter_floor=0.0 disables the override
    # (old behavior).
    suppress_jitter = nonjitter && smoothed_conf >= jitter_floor
    final_conf = suppress_jitter ? smoothed_conf : slight_jitter(smoothed_conf)

    # GRUG: Return best alignment index (forward preferred; reverse is orientation-flipped
    # so its index doesn't map back to the original signal cleanly).
    best_idx = forward_ok ? forward_idx : 1
    return (best_idx, final_conf)
end

# ==============================================================================
# DROP TABLE NEIGHBOR ACTIVATION
# ==============================================================================

"""
collect_drop_table_neighbors(node::Node)::Vector{String}

GRUG: When a node is selected for voting, also collect its drop_table neighbors
for co-activation. Drop table entries are node IDs that fire together with this node.
Returns list of valid (non-grave, existing) neighbor node IDs to co-activate.
"""
function collect_drop_table_neighbors(node::Node)::Vector{String}
    result = String[]

    # GRUG: Try lobe hash table first (O(1) prefix lookup) if LobeTable is loaded
    # and this node has been registered in a lobe's drop chunk.
    # Fall back to node.drop_table vector for nodes not yet in lobe storage.
    # This handles both old-style (vector) and new-style (hash table) drop entries.
    lobe_drop_ids = String[]
    if isdefined(@__MODULE__, :LobeTable)
        # GRUG: Ask reverse index which lobe owns this node, then fetch drop chunk.
        if isdefined(@__MODULE__, :Lobe)
            owning_lobe = Lobe.find_lobe_for_node(node.id)
            if !isnothing(owning_lobe) && LobeTable.table_exists(owning_lobe)
                lobe_drop_ids = try
                    LobeTable.get_drop_neighbors(owning_lobe, node.id)
                catch e
                    # GRUG: Non-fatal. Fall back to vector if chunk lookup fails.
                    @warn "[Engine] collect_drop_table_neighbors: lobe table lookup failed for node '$(node.id)': $e"
                    String[]
                end
            end
        end
    end

    # GRUG: Merge lobe table results with node.drop_table vector (dedup via Set).
    # Once all nodes migrate to lobe storage, node.drop_table will be empty and
    # this merge will just use lobe_drop_ids. Both sources are valid during transition.
    all_drop_ids = union(Set(lobe_drop_ids), Set(node.drop_table))

    lock(NODE_LOCK) do
        for drop_id in all_drop_ids
            if haskey(NODE_MAP, drop_id)
                neighbor = NODE_MAP[drop_id]
                # GRUG: Only activate non-grave drop table neighbors
                if !neighbor.is_grave
                    push!(result, drop_id)
                end
            end
            # GRUG: If drop entry doesn't exist in NODE_MAP, skip silently.
            # Nodes can be graved or deleted; drop tables may go stale.
        end
    end
    return result
end

# ==============================================================================
# STRENGTH-BIASED SCAN COINFLIP
# ==============================================================================

"""
strength_biased_scan_coinflip(node::Node)::Bool

GRUG: Before scanning a node, flip a biased coin.
Strong nodes are more likely to be scanned and activated.
Weak nodes can still get scanned, but less often (keeps competition alive).

Probability formula: base_prob + (strength / STRENGTH_CAP) * bonus_prob
  - Weakest node (strength=0.0): 20% chance of scan
  - Average node (strength=5.0): 60% chance
  - Strongest node (strength=10.0): 90% chance
"""
function strength_biased_scan_coinflip(node::Node)::Bool
    base_prob  = 0.20
    bonus_prob = 0.70
    scan_prob  = base_prob + (node.strength / STRENGTH_CAP) * bonus_prob
    return rand() < clamp(scan_prob, 0.0, 1.0)
end

#=
    confidence_biased_bridge_coinflip(node::Node, bridge_confidence::Float64)::Bool

GRUG v8.0: Bridge relay coinflip biased by BOTH strength AND confidence.
Unlike strength_biased_scan_coinflip (scan-time, strength-only), this is the
relay-time coinflip for CascadeBridge handoffs. The confidence bias comes from
the bridge's base_confidence relative to AIML_CONFIDENCE_THRESHOLD.

When bridge_confidence >= AIML_CONFIDENCE_THRESHOLD, the node gets a bonus
proportional to how far above threshold it is. When below threshold, the base
strength-only formula applies (no penalty — low-confidence bridges still get
a fair shake via strength alone).

Probability formula:
  base_prob  = 0.20   (same floor as scan coinflip)
  strength_bonus = (node.strength / STRENGTH_CAP) * 0.50
  conf_bonus     = max(0, (bridge_confidence - AIML_CONFIDENCE_THRESHOLD) / (1.0 - AIML_CONFIDENCE_THRESHOLD)) * 0.30
  bridge_prob = base_prob + strength_bonus + conf_bonus

Range analysis (AIML_CONFIDENCE_THRESHOLD = 0.35):
  - Weakest, low-conf (str=0, conf=0.1): 20% + 0% + 0% = 20%
  - Average, at-threshold (str=5, conf=0.35): 20% + 25% + 0% = 45%
  - Average, high-conf (str=5, conf=0.8): 20% + 25% + 20.8% = 65.8%
  - Strongest, high-conf (str=10, conf=1.0): 20% + 50% + 30% = 100%
=#
function confidence_biased_bridge_coinflip(node::Node, bridge_confidence::Float64)::Bool
    base_prob       = 0.20
    strength_bonus  = (node.strength / STRENGTH_CAP) * 0.50
    conf_range      = 1.0 - VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD
    conf_bonus      = max(0.0, (bridge_confidence - VoteOrchestrator.AIML_CONFIDENCE_THRESHOLD) / conf_range) * 0.30
    bridge_prob     = base_prob + strength_bonus + conf_bonus
    return rand() < clamp(bridge_prob, 0.0, 1.0)
end

# ==============================================================================
# CHUNK RESOLUTION — map scanner best_idx to InputChunk indices
# ==============================================================================

#=
    _match_to_chunks(best_idx, pat_len, chunks) -> Vector{Int}

GRUG v7.23: Given a scanner's best_idx (1-based token position where the
match starts) and the pattern's signal length (how many tokens the match
covers), determine which InputChunk(s) the match range overlaps.

The match covers tokens [best_idx, best_idx + pat_len - 1].
A chunk overlaps if [chunk.first_token, chunk.last_token] intersects
that range. Returns the chunk_index of each overlapping chunk.

If best_idx is 0 (unknown position) or chunks is empty, returns Int[].
=#
function _match_to_chunks(best_idx::Int, pat_len::Int,
                          chunks::Vector{InputDecomposer.InputChunk})::Vector{Int}
    if best_idx <= 0 || isempty(chunks) || pat_len <= 0
        return Int[]
    end

    match_first = best_idx
    match_last  = best_idx + pat_len - 1
    result = Int[]

    for chunk in chunks
        # Two ranges overlap iff: max(first1, first2) <= min(last1, last2)
        overlap_first = max(match_first, chunk.first_token)
        overlap_last  = min(match_last, chunk.last_token)
        if overlap_first <= overlap_last
            push!(result, chunk.chunk_index)
        end
    end

    return result
end

# ==============================================================================
# MAIN SCAN FUNCTION
# ==============================================================================

"""
scan_specimens(input_text::String)::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Int}}

GRUG: Main scan entry point. Converts input text to signal, extracts relational
triples, runs ActionTonePredictor, checks Hopfield fast-path, then scans all
nodes for matches. Returns vector of (id, confidence, antimatch, user_triples,
node_triples, best_idx) tuples. The best_idx is the 1-based token position in
the input signal where the scanner found the best match — this is the chunked-
affinity channel. When a scanner can't report a position (e.g. image nodes,
or fallback paths), best_idx is 0. Throws on empty input — NO SILENT FAILURES.
"""
function scan_specimens(input_text::String)::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Int}}
    if strip(input_text) == ""
        error("!!! FATAL: Grug cannot scan empty air! Input text is blank! !!!")
    end

    all_valid_specimens = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Int}[]
    
    # GRUG: Convert input to number rocks!
    target_signal = words_to_signal(input_text)

    # GRUG: LITERAL TOKEN PRE-GATE — input side.
    # Compute the lowercased, whitespace-split token set of the input ONCE here
    # so every fire_one call can do a cheap set lookup. The gate exists because
    # words_to_signal hashes tokens to uniformly-distributed Float64 values in
    # [0, 1], and the matcher then accepts |a - b| <= 0.1 as a "match." That
    # gives unrelated word pairs a ~20% false-match rate per token comparison,
    # which is why nodes from semantically unrelated lobes kept firing on
    # short inputs. The fix: require at least one literal token of the node's
    # pattern to appear in the input (or vice-versa for short inputs) BEFORE
    # the float scanner gets to vote. Float math still runs on the survivors —
    # it's the fuzzy-refinement step on top of a real lexical hit.
    #
    # Thesaurus expansion is intentionally NOT applied here. The thesaurus is
    # an orchestration / synthesis-time concern, not a matching one — the
    # scanner's job is to find what literally hit, the synthesizer's job is
    # to remix the result with synonyms. See Main.jl:1339 for that path.
    input_token_set = Set(split(lowercase(strip(input_text))))
    
    # GRUG: DETERMINISTIC SCAN SELECTION
    # Grug look at how complex input is to choose scanner eye.
    scan_mode = screen_input_complexity(target_signal, RelationalTriple[])

    # GRUG: RELATIONAL EXTRACTION COUPLING (per architecture spec)
    # --------------------------------------------------------------------------
    # Rule: "complex pattern scan → dynamic relational extraction, keep basic
    #        relational triples for simple things, dynamic is needed for complex"
    #
    # Therefore:
    #   mode 1 (cheap_scan)   → basic extract_relational_triples
    #   mode 2 (medium_scan)  → basic extract_relational_triples
    #   mode 3 (high_res_scan)→ dynamic extract_dynamic_relational_triples
    #                            NO SILENT FALLBACK. If dynamic fails on a
    #                            complex input, we scream loud. Falling back to
    #                            basic on mode-3 input would defeat the purpose
    #                            of the complexity coupling — the input earned
    #                            high-res scanning, so it earns dynamic triples.
    #
    # Error handling:
    #   - mode 3 dynamic failure → rethrow (fatal for this scan cycle, caller
    #                                       receives real error, NO SILENT FAIL)
    #   - mode 1/2 basic failure → return empty triples + loud @warn
    #     (basic extraction on simple input is less critical; an empty triple
    #      set just means pattern-scan alone drives the decision.)
    # --------------------------------------------------------------------------
    user_triples = if scan_mode >= 3
        # GRUG: High-res mode → DYNAMIC triples REQUIRED. No fallback.
        try
            result = extract_dynamic_relational_triples(input_text, scan_mode)
            println("[ENGINE] 🌊 High-res dynamic relational extraction: $(length(result)) triples from complex input")
            result
        catch e
            # GRUG: Complex input failed dynamic extraction. This is serious.
            # Do NOT quietly degrade to basic — the caller asked for complex
            # analysis and we must either deliver or fail loudly.
            @error "[ENGINE] ⚠ Dynamic relational extraction FAILED on complex input (mode=$scan_mode). NO SILENT FAIL — rethrowing: $e"
            rethrow(e)
        end
    else
        # GRUG: Simple mode (1 or 2) → basic extraction. Non-fatal on failure
        # because basic triples are complementary to pattern scan, not required.
        try
            extract_relational_triples(input_text)
        catch e
            @warn "[ENGINE] Basic relational extraction failed on simple input (mode=$scan_mode), returning empty triples: $e"
            RelationalTriple[]
        end
    end

    # GRUG: ACTION+TONE PRE-PREDICTION (DIAGNOSTIC ONLY)
    # Side processes must NEVER affect vote confidence. ActionTonePredictor may
    # observe, log, and populate LAST_PREDICTION for UI/telemetry, but the scan
    # score below remains pure core matching: token_conf + rel_conf.
    # If prediction fails for any reason, Grug logs warning and continues.
    prediction = try
        ActionTonePredictor.predict_action_tone(input_text, SemanticVerbs.get_all_verbs())
    catch e
        @warn "[ENGINE] ActionTonePredictor failed (non-fatal): $e"
        nothing
    end

    if !isnothing(prediction)
        # GRUG v7.21b-3a: Run the TonalJudge against the prediction so its
        # frame_hint verdict lands in LAST_JUDGEMENT. b-3a is OBSERVATION-ONLY
        # at the orchestrator level — the judge runs and surfaces a [FRAME=...]
        # diagnostic, but no scoring dimension reads it yet (that's b-3b). If
        # judging fails for any reason, log and continue — the existing log
        # line keeps working without the frame tag.
        frame_str = try
            judgement = TonalJudge.judge_from_prediction(prediction)
            mode_label = judgement.mode === TonalJudge.RELATIONAL ? "rel" : "basic"
            " [FRAME=$(TonalJudge.frame_hint_label(judgement.frame_hint))/$(mode_label)]"
        catch e
            @warn "[ENGINE] TonalJudge.judge_from_prediction failed (non-fatal): $e"
            ""
        end

        @info "[ENGINE] 🔮 $(ActionTonePredictor.format_prediction_summary(prediction))$(frame_str)"
        # GRUG: If predictor found a dangling verb (incomplete causal chain), warn user.
        # Informational only -- scan still proceeds, but output may be less coherent.
        if prediction.incomplete_chain
            @warn "[ENGINE] Incomplete causal chain detected (dangling verb: '$(prediction.dangling_verb)'). Input may be truncated."
        end
    end

    # GRUG: HOPFIELD FAST-PATH — REMOVED (SMELL-003 cleanup)
    # ============================================================================
    # The Hopfield cache fast-path was disabled and left as a 30-line comment
    # block. Removed during the QoL sweep — git history preserves the original.
    # If you need to re-enable familiar-input caching for very large lobes
    # (50k+ nodes per lobe), reintroduce a minimal lookup here. Current 1000-
    # node-per-cycle cap makes this unnecessary.
    # ============================================================================

    # GRUG: SCAN NODES - Already have scan_mode from earlier (deterministic selection)
    # scan_mode was computed before relational extraction to decide extraction strategy

    # GRUG: PARALLEL FIRE PIPELINE (new architecture)
    # --------------------------------------------------------------------------
    # Old code was a serial for-loop. New code:
    #   1. Snapshot node map under NODE_LOCK -> release lock.
    #   2. Build FireCounter (hard cap = 1000, shared across ALL fire types).
    #   3. Dispatch batched fire Tasks via VoteOrchestrator.parallel_fire_batches.
    #      Each Task has a unique non-colliding name so there is NO collision.
    #   4. Results are aggregated flat. Attachment relay later uses SAME counter.
    # --------------------------------------------------------------------------
    # GRUG: Snapshot key list under lock, then release so per-node work can run
    # without blocking other threads. Each node is read-only inside the fire
    # closure (only bump_strength! mutates, and it takes its own sub-lock).
    active_keys = lock(NODE_LOCK) do
        if isempty(NODE_MAP)
            error("!!! FATAL: Grug find cave empty! No specimens to scan! !!!")
        end

        # GRUG DOC 2.6: Biological Attention Bottleneck!
        # Grug cannot look at 1,000,000 rocks at once. Cave will catch fire!
        # active_cap  = 1000  # GRUG: HARD CAP - 1000 nodes max per cycle (now in VoteOrchestrator)
        all_keys    = collect(keys(NODE_MAP))
        shuffle!(all_keys)
        # GRUG: Pre-trim to cap so we don't even build Tasks for over-cap ids.
        all_keys[1:min(length(all_keys), VoteOrchestrator.ACTIVE_FIRE_CAP)]
    end

    # GRUG: Build FireCounter for this cycle. Cap = 1000. All firing shares this.
    # cycle_id carries the input hash for diagnostic traceability.
    cycle_id = "scan#$(hash(input_text))"
    fire_counter = VoteOrchestrator.FireCounter(cycle_id, VoteOrchestrator.ACTIVE_FIRE_CAP)

    # GRUG: The fire_one closure. One node = one fire attempt. Called from
    # many Tasks in parallel. Returns a tuple if node voted, nothing if skipped.
    # Returns shape: (id, confidence, is_antimatch, user_triples, node_triples)
    fire_one = function(id::String, fc::VoteOrchestrator.FireCounter)
        # GRUG: Read node under lock, then release for scan work.
        # Scan work (pattern matching, relational eval) is read-only on the node.
        node = lock(NODE_LOCK) do
            get(NODE_MAP, id, nothing)
        end
        if isnothing(node)
            return nothing
        end

        # GRUG: Skip grave nodes. They are negative reinforcement markers, not voters!
        if node.is_grave
            return nothing
        end

        # GRUG: LITERAL TOKEN PRE-GATE — pattern side.
        # Hard correctness gate AND coinflip-bypass for text nodes.
        #
        # Order is intentional: this runs BEFORE strength_biased_scan_coinflip.
        # Why? Because the coinflip is a "should we burn cycles on fuzzy work?"
        # gate. If the input literally contains one of the node's pattern
        # tokens, the work is already justified — there's no reason to skip
        # a sure thing 70% of the time just because the node is freshly
        # created with strength=1.0. That was causing weak-but-relevant nodes
        # (e.g. greeting's "good morning" node firing on input "good morning")
        # to go silent half the time.
        #
        # Behavior matrix:
        #   text node + literal-token hit  → BYPASS coinflip, fall through to scanner.
        #   text node + no literal hit     → reject outright (no fuzzy noise vote).
        #   text node + empty pattern      → coinflip as before.
        #   image node                     → coinflip as before (uses SDF signal,
        #                                    different match path entirely).
        # GRUG: STOPWORDS — closed-class words that match almost anything.
        # The float-hash scanner cannot distinguish "shared stop-word" from
        # "shared content-word", so a node that only collides with the input
        # on `the` or `for` will get the same hash-window similarity boost
        # as a node that genuinely shares `cliff`. We exclude stop-words from
        # the literal-hit decision: if the ONLY shared tokens are stop-words,
        # the node falls back to coinflip-gated scanning like an OOV node.
        # Content overlap still grants literal_hit and bypasses the coinflip.
        literal_hit = false
        literal_jaccard = 0.0
        if !node.is_image_node && !isempty(node.pattern)
            pattern_token_set = Set(split(lowercase(strip(node.pattern))))
            if !isempty(pattern_token_set) && !isempty(input_token_set)
                shared = intersect(pattern_token_set, input_token_set)
                # GRUG: Strip stop-words from the shared set for the gate decision.
                # Pattern AND input both lose stop-words from the union for Jaccard
                # so a single content-word match scores reasonably (e.g. "cliff"
                # in "watch out for the cliff" vs "beware the cliff edge" gives
                # content-Jaccard = 1/4 = 0.25 instead of full-Jaccard = 1/8).
                shared_content = Set(t for t in shared if !(t in STOPWORDS))
                if isempty(shared_content)
                    # No CONTENT token in common → not a real lexical hit. Don't
                    # grant the literal bypass; let coinflip decide. Still allow
                    # the scan to run if coinflip passes (image-node behavior).
                    literal_hit = false
                    # We still know there's *some* overlap (stop-word). Reject
                    # outright like the original gate did when shared was empty:
                    # patterns sharing only stop-words with the input are noise.
                    return nothing
                else
                    literal_hit = true
                    pat_content = Set(t for t in pattern_token_set if !(t in STOPWORDS))
                    inp_content = Set(t for t in input_token_set if !(t in STOPWORDS))
                    union_content = union(pat_content, inp_content)
                    union_size = isempty(union_content) ?
                        length(union(pattern_token_set, input_token_set)) :
                        length(union_content)
                    literal_jaccard = length(shared_content) / max(1, union_size)
                end
            end
        end

        # GRUG: STRENGTH-BIASED COINFLIP — only runs when no literal hit decided
        # the question. A literal-token match is a sure thing; don't roll dice
        # on it. Image nodes and empty-pattern nodes still go through coinflip
        # because their match path can't be cheaply pre-gated by tokens.
        if !literal_hit
            if !strength_biased_scan_coinflip(node)
                return nothing
            end
        end

        # GRUG: Image nodes use SDF signal, not text signal. Skip size check for them.
        # BUG-004: When pattern is longer than user input, the original code
        # SILENTLY skipped the node. Now we downgrade to cheap bidirectional
        # scan instead — the bidirectional scan handles short-input-vs-long-pattern
        # by matching on the shorter side. We also apply a confidence penalty
        # (BUG_004_PENALTY) because swapped-argument cheap scans are inherently
        # less reliable — the best_idx is in node-signal space, not input space,
        # so chunk resolution is lost and the match semantics are inverted.
        # v7.24: Changed from one-shot @warn to ALWAYS warn (visible in CLI
        # as well) and apply penalty. Operators should fix patterns that are
        # longer than typical inputs — single-token patterns avoid this entirely.
        long_pattern_short_input = false
        if !node.is_image_node
            if length(target_signal) < length(node.signal)
                long_pattern_short_input = true
                # v7.24: ALWAYS warn (not one-shot). Operators must fix patterns.
                @warn "[ENGINE] BUG-004: pattern ($(length(node.signal)) tokens) longer than input ($(length(target_signal)) tokens) — cheap bidirectional scan + penalty applied. Fix: use single-token patterns." node_id=node.id pattern=node.pattern
            end
        end

        # GRUG v7.23 CHUNKED AFFINITIES: best_idx tracks WHERE in the input
        # signal the scanner found the best match. This is the 1-based token
        # position. When no scan succeeds (fallback paths), best_idx stays 0.
        # Downstream, scan_and_expand cross-references this against InputChunk
        # boundaries to stamp each specimen with input_chunks::Vector{Int}.
        best_idx = 0
        token_conf = 0.0
        try
            if node.is_image_node
                # GRUG: Image nodes cannot be scanned with text signals.
                # They only respond to image inputs that have been SDF-converted.
                # Skip image nodes during text scans (they'll fire in image scan path).
                return nothing
            end

            # GRUG: SELECTIVE PATTERN SCAN — downgrade scan tier for simple patterns.
            effective_mode = _effective_scan_mode(scan_mode, node.signal)

            # BUG-004: If pattern is longer than input, FORCE cheap bidirectional
            # scan regardless of complexity tier. Higher tiers assume input ≥ pattern.
            if long_pattern_short_input
                effective_mode = 1
            end

            if effective_mode == 1
                # GRUG: BIDIRECTIONAL CHEAP SCAN — simple patterns (≤3 signal elements)
                # v7.20: pass per-node NONJITTER opt-out so anchor / calibration /
                # canonical-form nodes return bit-stable confidence. Tag lives in
                # node.required_relations (see is_nonjitter / set_nonjitter! above).
                #
                # v7.20 VOTE-LEVEL OVERRIDE: also pass JITTER_CONFIDENCE_FLOOR so a
                # solidified rock firing low-confidence still gets jittered. The
                # combined behavior is "high-conf solid: silent; low-conf solid:
                # still jitters; unsolid: always jitters." See jitter_allowed_for.
                #
                # v7.23 CHUNKED AFFINITIES: capture best_idx from the scanner.
                # This is the token position where the match starts — used to
                # determine which input chunk(s) this vote resolves.
                #
                # BUG-004: When pattern is longer than input, swap arg roles so
                # the (smaller) input acts as the pattern and the (larger) node
                # signal acts as the target. The cheap scan loops `(length(target)
                # - pat_len + 1)` and would otherwise have an empty range.
                # NOTE: In BUG-004 mode, best_idx refers to the node signal, not
                # the input signal — so it's not meaningful for chunk resolution.
                # We keep best_idx=0 in that case (set below after the scan).
                if long_pattern_short_input
                    _, token_conf = _bidirectional_cheap_scan(
                        node.signal, target_signal;
                        threshold=CHEAP_SCAN_THRESHOLD,
                        nonjitter=is_nonjitter(node),
                        jitter_floor=JITTER_CONFIDENCE_FLOOR
                    )
                    # BUG-004 path: best_idx is in node-signal space, not input-
                    # signal space. Not useful for chunk resolution, leave as 0.
                else
                    best_idx, token_conf = _bidirectional_cheap_scan(
                        target_signal, node.signal;
                        threshold=CHEAP_SCAN_THRESHOLD,
                        nonjitter=is_nonjitter(node),
                        jitter_floor=JITTER_CONFIDENCE_FLOOR
                    )
                end
            elseif effective_mode == 2
                best_idx, token_conf = medium_scan(target_signal, node.signal; threshold=MEDIUM_SCAN_THRESHOLD)
            else
                best_idx, token_conf = high_res_scan(target_signal, node.signal; threshold=HIGH_SCAN_THRESHOLD)
            end
        catch e
            if e isa PatternNotFoundError
                # Normal logic: Scanner says no match in any direction.
                #
                # BUT: if the literal-token gate confirmed a real lexical hit
                # earlier, we don't want to silently drop this node just
                # because the float scanner couldn't find a clean window. A
                # short pattern (e.g. "hello hi") embedded in a longer input
                # (e.g. "hello again old friend") will fail cheap_scan's
                # window threshold even though "hello" is literally present —
                # the noise tokens around it drag the per-window similarity
                # below CHEAP_SCAN_THRESHOLD.
                #
                # Resolution: when literal_hit=true, fall back to the Jaccard
                # of pattern_tokens ∩ input_tokens / pattern_tokens ∪ input_tokens
                # as a literal-hit floor. This is honest about partial overlap:
                # full overlap → ~1.0, single-word-of-many → low. Still gives
                # the node a fair shot at the vote pool instead of dropping it.
                if literal_hit
                    token_conf = literal_jaccard
                    # GRUG v7.23: Scanner didn't find a clean window, so we have
                    # no meaningful best_idx for chunk resolution. The literal
                    # token gate confirmed a real hit, but we can't pinpoint WHERE.
                    # best_idx stays 0 — downstream will treat this as "unknown position."
                    best_idx = 0
                else
                    return nothing
                end
            elseif e isa PatternScanError
                # FATAL LOGIC ERROR. NO SILENT FAILURE! Scream loud!
                rethrow(e)
            else
                error("!!! FATAL: Unknown error during complexity-based pattern scan: $e !!!")
            end
        end

        # GRUG: LITERAL-JACCARD BLEND.
        # The float-hash scanner produces unreliable inflation when only stop
        # words or hash collisions happen to align — it can score 0.5 for a
        # pattern that genuinely shares only one content token. Now that the
        # literal-token pre-gate guarantees real content overlap, we blend the
        # scanner's output with the content-Jaccard so the final score reflects
        # actual lexical overlap rather than hash noise.
        #
        # final = JACCARD_BLEND_W * jaccard + (1 - JACCARD_BLEND_W) * cheap_scan
        # The blend is only applied when literal_hit fired AND we got a real
        # cheap_scan number (not the Jaccard fallback path above). Jaccard is
        # already honest by construction; the scanner is the noisy one.
        if literal_hit && token_conf > 0.0
            JACCARD_BLEND_W = 0.6
            blended = JACCARD_BLEND_W * literal_jaccard + (1.0 - JACCARD_BLEND_W) * token_conf
            token_conf = blended
        end

        # BUG-004 PENALTY: When pattern is longer than input, the cheap
        # bidirectional scan with swapped arguments is inherently less
        # reliable — best_idx is in node-signal space (useless for chunk
        # resolution) and match semantics are inverted. Apply a penalty
        # so these votes rank lower than properly-sized patterns.
        if long_pattern_short_input && token_conf > 0.0
            penalty = token_conf * BUG_004_PENALTY
            token_conf = max(0.0, token_conf - penalty)
        end

        # 2. Relational Matcher (Dialectical)
        rel_conf, is_antimatch = evaluate_relational_dialectics(
            user_triples, node.relational_patterns, node.required_relations, node.relation_weights
        )

        # 3. Hard Anti-Match / Missing Requirement Penalty
        # GRUG: -9999.0 means node demanded a gear user did not have!
        if is_antimatch || rel_conf == -9999.0
            return nothing
        end

        confidence = token_conf + rel_conf

        # GRUG v7.21c-5: Side-process isolation.
        # Do NOT multiply confidence by ActionTonePredictor, TonalJudge, memory,
        # lobe routing, timing ledgers, or any other auxiliary process. Vote
        # confidence is the raw result of core node matching only.

        if token_conf > 0 || rel_conf > 0
            # GRUG: Node wants to fire. Claim a slot from the shared FireCounter.
            # If cap reached, skip — hard cap applies to ALL fire paths.
            if !VoteOrchestrator.try_claim_fire_slot!(fc)
                return nothing
            end
            # GRUG DEBUG: gated diagnostic for fire trace.
            if get(ENV, "GRUG_DEBUG_FIRE", "") != ""
                try
                    @info "[FIRE] $(node.id) pat='$(node.pattern)' act='$(node.action_packet)' tok=$(round(token_conf,digits=3)) rel=$(round(rel_conf,digits=3)) conf=$(round(confidence,digits=3)) lit=$(literal_hit) jac=$(round(literal_jaccard,digits=3))"
                catch
                end
            end
            return (id, confidence, is_antimatch, user_triples, node.relational_patterns, best_idx)
        end
        return nothing
    end

    # GRUG: Launch parallel fire. Each batch is its own Task with unique name.
    # Errors from any Task surface here via fetch_with_timeout inside
    # parallel_fire_batches. TaskTimeoutError distinguishable from other errors
    # so caller can choose retry vs abort. NO SILENT FAILURES.
    fire_results = try
        VoteOrchestrator.parallel_fire_batches(
            active_keys, fire_counter, fire_one;
            batch_size       = VoteOrchestrator.FIRE_BATCH_SIZE,
            task_prefix      = "scan_fire",
            batch_timeout_s  = VoteOrchestrator.FIRE_BATCH_TIMEOUT_S
        )
    catch e
        # GRUG: Parallel fire exploded or timed out. Scream, don't hide.
        if e isa VoteOrchestrator.TaskTimeoutError
            @error "[ENGINE] parallel_fire_batches TIMEOUT during scan_specimens: $e"
        else
            @error "[ENGINE] parallel_fire_batches failed during scan_specimens: $e"
        end
        rethrow(e)
    end

    # GRUG: Re-type the flat Any[] into our specimen tuple vector.
    for r in fire_results
        push!(all_valid_specimens, r)
    end

    # GRUG: Attach FireCounter to a task-local so scan_and_expand relay pass
    # can count attachment fires toward the same 1000 cap. We pass it via a
    # thread-local-ish handoff: store last cycle's counter in a const Ref.
    lock(_FIRE_COUNTER_LOCK) do
        _LAST_FIRE_COUNTER[] = fire_counter
    end

    if isempty(all_valid_specimens)
        # GRUG QoL FIX: If no valid rocks found, this is not a logic failure!
        # The Antikythera gears simply did not lock for this signal. Return empty basket!
        return all_valid_specimens
    end

    return all_valid_specimens
end

# ==============================================================================
# SCAN SPECIMENS WITH DROP TABLE CO-ACTIVATION
# ==============================================================================

"""
scan_and_expand(input_text; chunks)

GRUG: Run scan_specimens then expand results in two passes:

Pass 1 — Drop-table expansion (same lobe co-activation):
  Nodes paired in drop tables activate together.
  Drop-table neighbors inherit 80% of activating node confidence.

Pass 2 — Lobe cascade expansion (cross-lobe bridge activation):
  When a primary node lives in a lobe, cascade into other lobes —
  but ONLY inject a non-primary lobe's node if its own pattern signal
  shares at least one token with the input (within scan tolerance).
  This is the "share at least one node pattern token with the input"
  rule the original cascade design promised but never enforced.
  Without this gate, every lobe got its full node set injected at the
  cascade discount whenever ANY primary fired loudly — flooding the
  vote pool with semantically unrelated nodes from every domain and
  collapsing routing to coinflip-on-a-flat-plateau. The gate keeps
  cross-lobe talk alive (genuinely overlapping queries still cascade)
  while killing the indiscriminate flood.
  Cascade threshold: 0.15 (soft gate on cascade_conf).
  Cascade confidence: 60% of the highest primary confidence (cross-lobe discount).

v7.23 CHUNKED AFFINITIES:
  When `chunks` is provided (Vector{InputChunk}), each primary specimen's
  `best_idx` from the scanner is cross-referenced against chunk boundaries
  to produce `input_chunks::Vector{Int}` — which input chunk(s) this vote
  resolved. Expansion specimens (drop-table, cascade, relay) inherit the
  activating node's input_chunks; if no activating context, input_chunks
  is Int[]. When `chunks` is empty or not provided, all specimens get
  Int[] (backward compatible — old behavior).
"""
function scan_and_expand(input_text::String;
                         chunks::Vector{InputDecomposer.InputChunk} = InputDecomposer.InputChunk[]
                         )::Vector{Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}}
    # ──────────────────────────────────────────────────────────────────────
    # STAGE 1.5a — FRONT-DOOR SIGIL PROMOTION
    # ──────────────────────────────────────────────────────────────────────
    # GRUG: Before anything else, run the input through the SigilPromoter.
    # Two layers:
    #   Layer 1 — thesaurus canonicalization ("two plus two" -> "2 + 2")
    #   Layer 2 — registry shape promotion   ("2 + 2"        -> "&n &op &n")
    # The matcher downstream just compares strings; pre-rewriting collapses
    # many surface variants of the same shape onto ONE pattern bucket. For
    # pure-text inputs (no digits, no math words) the rewrite is a no-op
    # confidence-equivalence guarantee; existing tests are unaffected.
    #
    # The bindings (position-keyed Vector{SigilBinding}) get stashed into
    # task-local storage so downstream phases (vote, ATP) can read them
    # without changing the scan_and_expand return-tuple shape. ATP arithmetic
    # dispatch (Stage 1.5b) reads from current_promotion_bindings().
    #
    # No silent failures: if the promoter raises, we let it propagate. The
    # alternative (catch + fall back to raw input) would mask configuration
    # bugs in specimen-level registries, exactly the kind of thing we need
    # to surface loudly.
    promoted_text, promotion_bindings = SigilPromoter.promote_input(
        _ENGINE_SIGIL_TABLE, input_text)

    # GRUG: Stash promotion results. Each scan_and_expand call OVERWRITES
    # any prior binding so stale state from a previous input never leaks.
    # We write to BOTH task-local storage AND module-level Refs:
    #   - Task-local: backward compat for code in the same task
    #   - Module-level Refs: survive @spawn Task boundaries (BUG-5 fix).
    #     scan_and_expand runs in a @spawn'd Task but generate_aiml_payload
    #     runs in a DIFFERENT @spawn'd Task, so task-local storage is invisible.
    task_local_storage(_PROMOTION_RAW_KEY,       input_text)
    task_local_storage(_PROMOTION_REWRITTEN_KEY, promoted_text)
    task_local_storage(_PROMOTION_BINDINGS_KEY,  promotion_bindings)
    lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_PROMOTION_RAW[]        = input_text
        _GLOBAL_PROMOTION_REWRITTEN[]  = promoted_text
        _GLOBAL_PROMOTION_BINDINGS[]   = promotion_bindings
    end

    # GRUG v8.1: TIME ORIENTATION — extract temporal orientation from promotion
    # bindings and stash it the same way (task-local + global Ref). When a time
    # sigil (&now/&before/&next) fired, this carries orientation + vote_flags
    # downstream to generate_aiml_payload and the hippocampal lever.
    time_orient, time_meta = extract_time_orientation(promotion_bindings)
    task_local_storage(_TIME_ORIENTATION_KEY, (time_orient, time_meta))
    lock(_GLOBAL_PROMOTION_LOCK) do
        _GLOBAL_TIME_ORIENTATION[] = (time_orient, time_meta)
    end
    if time_orient != "none"
        @info "[ENGINE v8.1] Time orientation detected: $(time_orient) (sigil=$(get(time_meta, "sigil_name", "?")), surface='$(get(time_meta, "surface", ""))')"
    end

    # GRUG: From here on, scan_specimens and the cascade gates see the
    # PROMOTED text, not the raw text. That is the whole point — one shape,
    # one node.
    primary_results = scan_specimens(promoted_text)

    if isempty(primary_results)
        # GRUG: Return empty vector with the correct 6-tuple element type.
        return Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]
    end

    # GRUG v7.23 CHUNKED AFFINITIES: Resolve best_idx -> input_chunks.
    # Each specimen now carries best_idx (6th element) from the scanner.
    # Cross-reference against InputChunk boundaries to determine which
    # chunk(s) this specimen's match covers. The match covers tokens
    # [best_idx, best_idx + pattern_length - 1]; a chunk overlaps if
    # its [first_token, last_token] range intersects that match range.
    # When no chunks are provided (backward compat), all get Int[].
    if !isempty(chunks)
        # GRUG: We need the pattern length for each specimen to compute
        # the match range. Read node.signal length from NODE_MAP.
        # If best_idx is 0 (scanner fallback) or node not found,
        # input_chunks is Int[] (unknown position).
        resolved_results = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]
        for (id, conf, antimatch, u_trips, n_trips, bidx) in primary_results
            ichunks = if bidx > 0
                node_for_range = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
                pat_len = if !isnothing(node_for_range)
                    length(node_for_range.signal)
                else
                    1  # Fallback: assume single-token match
                end
                _match_to_chunks(bidx, pat_len, chunks)
            else
                Int[]  # best_idx=0 means unknown position
            end
            push!(resolved_results, (id, conf, antimatch, u_trips, n_trips, ichunks))
        end
        primary_results = resolved_results
    else
        # GRUG: No chunks provided — still need to convert 6th element
        # from Int (best_idx) to Vector{Int} (input_chunks) for type
        # consistency. Downstream code (antimatch separation, drain pass,
        # Main.jl specimen wrapping) all expect Vector{Int}.
        nochunk_results = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]
        for (id, conf, antimatch, u_trips, n_trips, bidx) in primary_results
            push!(nochunk_results, (id, conf, antimatch, u_trips, n_trips, Int[]))
        end
        primary_results = nochunk_results
    end

    # ── v7.49 ANTI-MATCH NODE SEPARATION ────────────────────────────
    # GRUG: Anti-match nodes must NOT be expanded (no drop-table, no cascade,
    # no relay) — they exist only to drain confidence. Separate them out here
    # and only carry regular entries into the expansion passes. Anti-match
    # entries are collected separately and re-joined before the drain pass
    # (which runs after relay and before score_lobes).
    antimatch_primary = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]
    regular_primary   = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]
    for entry in primary_results
        entry_node = lock(() -> get(NODE_MAP, entry[1], nothing), NODE_LOCK)
        if !isnothing(entry_node) && entry_node.is_antimatch_node
            push!(antimatch_primary, entry)
        else
            push!(regular_primary, entry)
        end
    end
    primary_results = regular_primary

    # GRUG: Pre-compute input CONTENT TOKEN SET once for cascade overlap gate.
    # We compare cascade-candidate nodes' pattern-token sets against this set
    # (CONTENT tokens only, stop-words stripped) to decide whether a cross-lobe
    # node's pattern is genuinely related to the input. The original gate used
    # signal-hash bands, which suffer the same hash-collision noise as the
    # primary scanner — every "the/for/a" overlap let cross-lobe garbage in.
    # Switching to content tokens makes the gate semantically honest.
    #
    # NOTE: we use the PROMOTED text here for the same reason the primary
    # scanner does — cascade gates need to see the same token universe the
    # matcher does, otherwise sigil tokens (&n, &op) wouldn't gate properly.
    cascade_input_tokens = try
        Set(String(t) for t in split(lowercase(strip(promoted_text))) if !(t in STOPWORDS))
    catch
        Set{String}()
    end

    # GRUG: Track which IDs are already in the result set to avoid duplicates
    already_included = Set(r[1] for r in primary_results)
    expanded = copy(primary_results)

    user_triples = extract_relational_triples(input_text)
    max_primary_conf = isempty(primary_results) ? 0.0 : maximum(r[2] for r in primary_results)

    # ── PASS 1: Drop-table expansion (same lobe, 80% confidence discount) ──────
    for (id, conf, antimatch, u_trips, n_trips, ichunks) in primary_results
        activating_node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
        isnothing(activating_node) && continue

        drop_neighbors = collect_drop_table_neighbors(activating_node)
        for drop_id in drop_neighbors
            if !(drop_id in already_included)
                drop_node = lock(() -> get(NODE_MAP, drop_id, nothing), NODE_LOCK)
                isnothing(drop_node) && continue

                # GRUG: Drop-table neighbor gets discounted confidence (80% of activator)
                # v7.23: Drop-table neighbors inherit the activating node's input_chunks.
                # They fire alongside the activator in the same lobe, so they resolve
                # the same part of the input.
                drop_conf = conf * 0.8
                push!(expanded, (drop_id, drop_conf, false, user_triples, drop_node.relational_patterns, ichunks))
                push!(already_included, drop_id)
            end
        end
    end

    # ── PASS 2: Lobe cascade expansion (cross-lobe bridge, 60% of max primary) ─
    # GRUG: Only run cascade if LobeTable and Lobe modules are loaded.
    if isdefined(@__MODULE__, :LobeTable) && isdefined(@__MODULE__, :Lobe)
        cascade_conf = max_primary_conf * 0.6

        # GRUG: Cascade threshold - only cascade if primary conf was meaningful
        if cascade_conf >= 0.15
            # GRUG: Collect lobes that own the primary firing nodes
            primary_lobe_names = Set{String}()
            for (id, conf, _, _, _, _) in primary_results
                lobe_name = Lobe.find_lobe_for_node(id)
                !isnothing(lobe_name) && push!(primary_lobe_names, lobe_name)
            end

            # GRUG: For each OTHER lobe not in primary set, cascade into it
            if !isempty(primary_lobe_names)
                all_lobe_names = try
                    Lobe.get_lobe_ids()
                catch ex
                    # GRUG: Lobe registry blew up — log it, don't kill the scan!
                    @warn "[ENGINE] ⚠ Failed to get lobe IDs for cascade: $ex"
                    String[]
                end

                for lobe_name in all_lobe_names
                    lobe_name in primary_lobe_names && continue  # GRUG: Already fired, skip!

                    # GRUG: Get active node IDs from this lobe via LobeTable
                    lobe_node_ids = try
                        LobeTable.table_exists(lobe_name) ?
                            LobeTable.get_active_node_ids(lobe_name) : String[]
                    catch ex
                        # GRUG: One lobe table exploded — warn and skip, don't nuke cascade!
                        @warn "[ENGINE] ⚠ Failed to get node IDs from lobe '$lobe_name': $ex"
                        String[]
                    end

                    for node_id in lobe_node_ids
                        node_id in already_included && continue

                        cascade_node = lock(() -> get(NODE_MAP, node_id, nothing), NODE_LOCK)
                        isnothing(cascade_node) && continue
                        cascade_node.is_grave && continue  # GRUG: Dead nodes don't cascade!

                        # GRUG: CONTENT-TOKEN OVERLAP GATE — only cascade if this
                        # node's pattern shares at least one CONTENT token (non
                        # stop-word) with the input. The original gate compared
                        # signal-hash bands and leaked through every "the/for/a"
                        # collision, flooding routing with cross-lobe noise.
                        # Switching to content tokens makes the gate honest.
                        if cascade_node.is_image_node
                            continue
                        end
                        if isempty(cascade_input_tokens) || isempty(cascade_node.pattern)
                            continue
                        end
                        cand_tokens = Set(t for t in split(lowercase(strip(cascade_node.pattern)))
                                          if !(t in STOPWORDS))
                        if isempty(cand_tokens)
                            continue
                        end
                        if isempty(intersect(cand_tokens, cascade_input_tokens))
                            continue  # GRUG: No shared content token → skip.
                        end

                        push!(expanded, (node_id, cascade_conf, false, user_triples, cascade_node.relational_patterns, Int[]))
                        push!(already_included, node_id)
                    end
                end
            end
        end
    end

    # ── PASS 3: Cascade bridge handoff (match-cascade relay system) ──────
    # GRUG v8.0: For every node that made it into the expanded set, check if it
    # has bridges. If so, fire_cascades! hands off the unmatched input tail (the
    # match boundary) to the bridged partner node's lobe scanner. The unmatched
    # tail IS the natural cross-lobe bridge — no more dumb middle-man connector
    # pattern. The seam tokens at the boundary become the handoff payload.
    #
    # The seam text also surfaces as a RelationalTriple in the node's context
    # so the generative pipeline knows WHY this node was co-activated.
    # Triple format: (source_id, "cascade_bridge", seam_text)
    # GRUG: Relay pass uses the SAME FireCounter that scan_specimens built for
    # this cycle. That means bridge fires COUNT against the global 1000 cap
    # along with pattern-scan fires, drop-table fires, and cascade fires.
    # If scan already consumed all 1000 slots, bridges simply won't fire.
    # If scan_specimens was never called (edge case, e.g. empty NODE_MAP branch),
    # fall back to a fresh FireCounter so relay still respects the cap.
    shared_fc = lock(_FIRE_COUNTER_LOCK) do; _LAST_FIRE_COUNTER[] end
    if isnothing(shared_fc)
        shared_fc = VoteOrchestrator.FireCounter("relay_fallback#$(hash(input_text))", VoteOrchestrator.ACTIVE_FIRE_CAP)
    end
    relay_cap   = shared_fc.cap
    relay_additions = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]

    # GRUG v8.0: Compute the unmatched tail from the input. This is the match
    # boundary — the tokens the primary scan DIDN'T consume. These become the
    # seam tokens for the cascade handoff. Simple approach: tokens in the input
    # that aren't in any matched node's pattern. This is the "cut off where it
    # didn't match" the user was talking about.
    # GRUG v8.1: Use String[] not SubString{String}[] for input_tokens.
    # split() returns SubString{String} which causes TypeError when passed
    # as unmatched_tail (declared Vector{String}) to fire_cascades!.
    # Converting up front keeps the set difference type-consistent.
    input_tokens = Set(String.(split(lowercase(input_text))))
    matched_tokens = Set{String}()
    for (id, conf, antimatch, u_trips, n_trips, ichunks) in expanded
        if !antimatch
            node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
            if !isnothing(node)
                for tok in split(lowercase(node.pattern))
                    push!(matched_tokens, String(tok))
                end
            end
        end
    end
    unmatched_tail = collect(setdiff(input_tokens, matched_tokens))

    for (id, conf, antimatch, u_trips, n_trips, ichunks) in expanded
        # GRUG: Stop firing bridges if global cap is already hit. Hard cap
        # applies across ALL fire paths — no bypass for bridges!
        if VoteOrchestrator.fire_cap_reached(shared_fc)
            println("[ENGINE] 🧠  Cascade bridge halted — global fire cap ($relay_cap) reached.")
            break
        end
        # GRUG v8.0: Pass unmatched tail to fire_cascades! so the bridge
        # handoff carries the match-boundary payload. This is the core of
        # the match-cascade system — the scanner's cutoff IS the bridge.
        fired_pairs = fire_cascades!(id, VoteOrchestrator.current_fire_count(shared_fc), relay_cap;
                                     unmatched_tail=unmatched_tail)
        for (fired_id, fired_conf, seam_text) in fired_pairs
            if !(fired_id in already_included)
                # GRUG: Claim a fire slot for this bridge. If cap is hit, skip.
                # This ensures bridge-node firings count toward the 1000 limit.
                if !VoteOrchestrator.try_claim_fire_slot!(shared_fc)
                    break
                end
                fired_node = lock(() -> get(NODE_MAP, fired_id, nothing), NODE_LOCK)
                isnothing(fired_node) && continue
                # GRUG v8.0: Inject the seam text as a cascade triple so generative
                # knows WHY this node was co-fired. The triple reads:
                #   subject=source_id, relation="cascade_bridge", object=seam_text
                relay_triple = RelationalTriple(id, "cascade_bridge", seam_text)
                relay_triples = vcat(fired_node.relational_patterns, [relay_triple])
                # v10-coherence-fix: CASCADE-RELAY CONFIDENCE DISCOUNT AT INJECTION.
                # Bridge handoffs are CONTEXT co-activations, not direct answers.
                # The bridge's pre-baked base_confidence (~0.4-0.5) was high enough
                # that, combined with the lobe-curve's winner bonus, a bridged
                # partner in a different lobe could out-rank the genuine primary
                # content match (e.g. gravity→derivative bridge made n103 beat the
                # real n101 gravity node). Discounting the relay confidence HERE —
                # before score_lobes runs — keeps bridges alive for generative
                # context while ensuring they can't steal the lobe winner crown
                # or the primary vote from a real content match. Downstream
                # composite_vote_score still applies its own RELAY discount via
                # the relay_attached detection; this is the earlier, structural cut.
                discounted_conf = fired_conf * CASCADE_RELAY_CONF_DISCOUNT
                push!(relay_additions, (fired_id, discounted_conf, false, user_triples, relay_triples, Int[]))
                push!(already_included, fired_id)
            end
        end
    end

    if !isempty(relay_additions)
        append!(expanded, relay_additions)
        println("[ENGINE] 🌉  Cascade bridge pass added $(length(relay_additions)) node(s) to expanded set.")
    end

    # GRUG v7.49: Re-join anti-match primary entries into expanded before drain.
    # They were separated out before expansion passes (no drop/cascade/relay
    # for anti-match), but the drain pass needs to see them to compute drain.
    if !isempty(antimatch_primary)
        append!(expanded, antimatch_primary)
    end

    # ── ANTI-MATCH DRAIN PASS (v7.49) ────────────────────────────────
    # GRUG: Anti-match nodes are pattern-activated but vote-silent. They exist
    # to suppress confidence in their lobe — like inhibitory interneurons.
    # Every anti-match activation drains a small random tick from all regular
    # votes in the same lobe. NONJITTER anti-match nodes drain a fixed constant
    # instead of a random tick. Anti-match nodes never enter the vote pool,
    # never gain/lose strength, and never compete for stages.
    #
    # Pipeline: separate anti-match entries → group regular entries by lobe →
    # for each anti-match activation, drain confidence from regular entries in
    # the same lobe → remove anti-match entries from expanded before score_lobes.
    #
    # See ANTIMATCH_DRAIN_FIXED and ANTIMATCH_DRAIN_MAX_JITTER at module level.

    antimatch_entries = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]
    regular_entries = Tuple{String, Float64, Bool, Vector{RelationalTriple}, Vector{RelationalTriple}, Vector{Int}}[]

    for entry in expanded
        entry_id = entry[1]
        entry_node = lock(() -> get(NODE_MAP, entry_id, nothing), NODE_LOCK)
        if !isnothing(entry_node) && entry_node.is_antimatch_node
            push!(antimatch_entries, entry)
        else
            push!(regular_entries, entry)
        end
    end

    if !isempty(antimatch_entries)
        # GRUG: Group regular entries by lobe for efficient drain application.
        regular_by_lobe = Dict{String, Vector{Int}}()  # lobe_id -> indices into regular_entries
        for (i, entry) in enumerate(regular_entries)
            lobe_id = Lobe.find_lobe_for_node(entry[1])
            if !isnothing(lobe_id)
                if !haskey(regular_by_lobe, lobe_id)
                    regular_by_lobe[lobe_id] = Int[]
                end
                push!(regular_by_lobe[lobe_id], i)
            end
        end

        # GRUG: For each anti-match activation, drain confidence from regular
        # entries in the same lobe. The drain is a random tick (jitter) unless
        # the anti-match node has NONJITTER tag, in which case it's a fixed constant.
        total_drain = 0.0
        for am_entry in antimatch_entries
            am_id = am_entry[1]
            am_node = lock(() -> get(NODE_MAP, am_id, nothing), NODE_LOCK)
            isnothing(am_node) && continue

            am_lobe = Lobe.find_lobe_for_node(am_id)
            isnothing(am_lobe) && continue

            # GRUG: Determine drain amount — jitter or fixed.
            is_fixed = is_nonjitter(am_node)
            drain_amount = is_fixed ? ANTIMATCH_DRAIN_FIXED : (rand() * ANTIMATCH_DRAIN_MAX_JITTER)

            # GRUG: Apply drain to all regular entries in the same lobe.
            if haskey(regular_by_lobe, am_lobe)
                for idx in regular_by_lobe[am_lobe]
                    old_conf = regular_entries[idx][2]
                    new_conf = max(0.0, old_conf - drain_amount)
                    # GRUG: Rebuild the tuple with the drained confidence.
                    regular_entries[idx] = (
                        regular_entries[idx][1],  # id
                        new_conf,                  # drained confidence
                        regular_entries[idx][3],  # antimatch flag
                        regular_entries[idx][4],  # user_triples
                        regular_entries[idx][5],  # node_triples
                        regular_entries[idx][6]   # input_chunks
                    )
                    total_drain += drain_amount
                end
            end
        end
        println("[ENGINE] 🧫 Anti-match drain: $(length(antimatch_entries)) activation(s) applied $(round(total_drain, digits=3)) total drain across $(length(regular_by_lobe)) lobe(s).")

        # GRUG: Replace expanded with regular entries only (anti-match removed).
        expanded = regular_entries
    end

    # ── LOBE CURVE — averages-based selection (replaces the v7.18 hard mute) ──
    # GRUG: After all expansion passes, group entries by lobe and compute the
    # base_avg × top_avg curve. Winner lobe goes first; runners-up that pass
    # the multi-lobe threshold (score >= MIN_PASS_THROUGH_SCORE AND >=
    # MIN_WINNING_VOTES_PER_LOBE hard-selected votes) fire after. Lobes that
    # don't clear are dropped from the firing list. Cross-domain leakage is
    # naturally prevented because off-topic lobes will have low confidence
    # averages even if they lexically match a few tokens. No hard subject-
    # token muting needed. See plans/semantic_plugins/QOL_SWEEP_2025.md
    # "BUG-011 rewrite" for the architectural reasoning.
    expanded = try
        if isempty(expanded)
            expanded
        else
            orders = LobeOrchestrator.score_lobes(expanded, Lobe.find_lobe_for_node;
                input_tokens=collect(String, split(lowercase(strip(input_text)))))
            if isempty(orders)
                # No lobe cleared (would only happen with totally empty pool).
                # Return empty — downstream prints "Cave is silent" cleanly.
                eltype(expanded)[]
            else
                # Loud trace so operators see the curve at work.
                println("[ORCHESTRATOR] 🎯 ", LobeOrchestrator.last_summary())
                LobeOrchestrator.flatten_in_fire_order(orders)
            end
        end
    catch e
        @warn "[ORCHESTRATOR] lobe curve FAILED (continuing with unfiltered pool): $e"
        expanded
    end

    return expanded
end

# ==============================================================================
# VOTE CASTING  
# ==============================================================================

"""
cast_vote(id, conf, antimatch, u_trips, n_trips)

GRUG: Cast a vote for a matched node. Selects a stochastic action from the
node's action packet, bumps node strength on coinflip, and returns a Vote.
Throws if node ID is empty or node vanished from NODE_MAP — NO SILENT FAILURES.
"""
function cast_vote(id, conf, antimatch, u_trips, n_trips)
    if strip(id) == "" error("!!! FATAL: Need real node ID to cast vote! !!!") end
    
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before vote! !!!")

    # GRUG v7.49: Anti-match nodes never vote. If one somehow reaches this
    # path, reject it loudly — it should have been filtered out upstream.
    if node.is_antimatch_node
        error("!!! FATAL: Anti-match node [$id] reached cast_vote! Anti-match nodes never vote! !!!")
    end

    winning_action, negatives = select_action(node.action_packet)
    
    # GRUG FIX 2.8: Include bad action name in error!
    if !haskey(COMMANDS, winning_action) 
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    # GRUG NEW: Bump strength on a coinflip when a node votes (used = maybe stronger)
    bump_strength!(node)

    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch)
end

"""
cast_explicit_vote(cmd_name::String, id::String)::Vote

GRUG: Cast an explicit vote bypassing stochastic action selection. Used for
direct command overrides (e.g. /force). Sets confidence to 9999.0 (max priority).
Throws if node not found — NO SILENT FAILURES.
"""
function cast_explicit_vote(cmd_name::String, id::String)::Vote
    # Helper to bypass everything
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Explicit override failed, node [$id] not found !!!")
    
    _, negatives, _ = parse_action_packet(node.action_packet)
    return Vote(id, cmd_name, 9999.0, negatives, RelationalTriple[], node.relational_patterns, false)
end

"""
cast_vote_with_group(id, conf, antimatch, u_trips, n_trips, multipart_group, multipart_role)

GRUG v7.23: Same as cast_vote but stamps the vote with multipart_group and
multipart_role. Used when input decomposer splits a compound query into
sub-subjects — each sub-subject's votes carry the group ID assigned by
the decomposer, and the role (:primary for first sub-subject, :support
for subsequent ones) so MultipartOrchestrator can coalesce them into
one cohesive objective.
"""
function cast_vote_with_group(id, conf, antimatch, u_trips, n_trips,
                               multipart_group::String, multipart_role::Symbol)
    if strip(id) == "" error("!!! FATAL: Need real node ID to cast vote! !!!") end
    
    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before vote! !!!")

    # GRUG v7.49: Anti-match nodes never vote. If one somehow reaches this
    # path, reject it loudly — it should have been filtered out upstream.
    if node.is_antimatch_node
        error("!!! FATAL: Anti-match node [$id] reached cast_vote_with_group! Anti-match nodes never vote! !!!")
    end

    winning_action, negatives = select_action(node.action_packet)
    
    if !haskey(COMMANDS, winning_action) 
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    bump_strength!(node)

    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch,
                multipart_group, multipart_role)
end

#=
    cast_vote_chunked(id, conf, antimatch, u_trips, n_trips, input_chunks)

GRUG v7.23: Cast a vote that knows which input chunk(s) it resolved.
This is the chunked-affinity path — the vote carries its own scope
instead of relying on a multipart_group tag. Used when the pattern
bind phase has chunk boundaries and can determine which part of the
input the node matched.

The vote's multipart_group is derived from input_chunks: if there's
exactly one chunk, group_id = "mp_{chunk_index}". If multiple chunks,
group_id = "mp_{first_chunk}" (primary chunk). If no chunks, group_id
= "" (singleton). multipart_role is always :primary for the winning
vote within its chunk group — same as the InputDecomposer path.
=#
function cast_vote_chunked(id, conf, antimatch, u_trips, n_trips,
                           input_chunks::Vector{Int})
    if strip(id) == "" error("!!! FATAL: Need real node ID to cast vote! !!!") end

    node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
    isnothing(node) && error("!!! FATAL: Node [$id] vanished before vote! !!!")

    # GRUG v7.49: Anti-match nodes never vote. If one somehow reaches this
    # path, reject it loudly — it should have been filtered out upstream.
    if node.is_antimatch_node
        error("!!! FATAL: Anti-match node [$id] reached cast_vote_chunked! Anti-match nodes never vote! !!!")
    end

    winning_action, negatives = select_action(node.action_packet)

    if !haskey(COMMANDS, winning_action)
        error("!!! FATAL: Grug rolled unknown action [$(winning_action)]! Not in COMMANDS dictionary !!!")
    end

    bump_strength!(node)

    # GRUG: Derive multipart_group from input_chunks.
    # Single chunk -> group "mp_{chunk}". Multiple -> group "mp_{first}".
    # No chunks -> "" (singleton / old behavior).
    group_id = isempty(input_chunks) ? "" : "mp_$(input_chunks[1])"

    return Vote(id, winning_action, conf, negatives, u_trips, n_trips, antimatch,
                group_id, :primary, input_chunks)
end

# ==============================================================================
# /WRONG FEEDBACK: PENALIZE ALL VOTERS
# ==============================================================================

"""
apply_wrong_feedback!(voter_ids::Vector{String})

GRUG: /wrong command! Every node who voted gets a coinflip.
Losers have their strength lowered. Nodes that hit 0 are marked GRAVE.
Grave nodes become negative reinforcement anchors during generative phase.
"""
#=
    apply_right_feedback!(contributor_votes, locked_node_ids) -> Dict

Apply secondary reinforcement to nodes that contributed to output.

v7.23 TIERED REWARD:
- LOCKED votes (node_id in locked_node_ids) -> GUARANTEED reward. These
  are the top-tier votes that were hard-selected by the orchestrator.
  They earned their spot — /right confirms them unconditionally.
- UNSURE votes (not locked) -> CONFIDENCE-BIASED coinflip. The coinflip
  probability equals the vote's confidence. High-confidence unsure votes
  are more likely to be rewarded; low-confidence ones are less likely.
- EITHER tier: skip if gained_this_cycle is already true. Nodes that
  already got a strength bump from their use-coinflip (bump_strength!)
  this cycle don't get a second one — no double reward.
- Grave nodes are always skipped.

Returns statistics dictionary with:
- "total_contributors": Total number of contributing votes
- "rewarded": Node IDs that gained strength
- "locked_rewarded": Node IDs from locked tier that gained strength
- "unsure_rewarded": Node IDs from unsure tier that gained strength
- "skipped_double_reward": Node IDs that already gained (skipped)
- "coinflip_missed": Node IDs from unsure tier that lost the coinflip
- "grave_skipped": Node IDs that are grave and were skipped
=#
function apply_right_feedback!(contributor_votes::Vector{Vote},
                               locked_node_ids::Set{String} = Set{String}())::Dict{String, Any}
    if isempty(contributor_votes)
        error("!!! FATAL: apply_right_feedback! got empty contributor_votes list! !!!")
    end

    rewarded = String[]
    locked_rewarded = String[]
    unsure_rewarded = String[]
    skipped_double_reward = String[]
    coinflip_missed = String[]
    grave_skipped = String[]
    STRENGTH_DELTA = 1.0  # Same as AIML_STRENGTH_DELTA

    # GRUG: Deduplicate by node_id — a node can appear in multiple votes
    # (e.g., as both a primary and a support in different objectives).
    # First occurrence wins; subsequent ones are skipped.
    seen_nodes = Set{String}()

    lock(NODE_LOCK) do
        for vote in contributor_votes
            id = vote.node_id

            # Skip duplicate node entries
            if id in seen_nodes
                continue
            end
            push!(seen_nodes, id)

            node = get(NODE_MAP, id, nothing)
            if isnothing(node)
                # GRUG: Node may have already been deleted. Non-fatal, skip.
                println("[ENGINE] ⚠  /right: Node [$id] not found, skipping.")
                continue
            end

            # Skip grave nodes
            if node.is_grave
                push!(grave_skipped, node.id)
                continue
            end

            # Skip nodes that already gained strength this cycle (no double reward)
            if node.gained_this_cycle
                push!(skipped_double_reward, node.id)
                continue
            end

            is_locked = id in locked_node_ids

            if is_locked
                # LOCKED TIER: Guaranteed reward. This node was hard-selected
                # by the orchestrator — it earned its spot. /right confirms it.
                node.strength = min(node.strength + STRENGTH_DELTA, STRENGTH_CAP)
                node.gained_this_cycle = true
                node.strength_delta_this_cycle += STRENGTH_DELTA
                check_solidify_threshold!(node)
                push!(rewarded, node.id)
                push!(locked_rewarded, node.id)
            else
                # UNSURE TIER: Confidence-biased coinflip.
                # The probability of reward equals the vote's confidence.
                # High-confidence unsure votes are likely rewarded;
                # low-confidence ones are unlikely. This is the GRUG way:
                # uncertain contributors get an uncertain reward.
                if rand() < vote.confidence
                    node.strength = min(node.strength + STRENGTH_DELTA, STRENGTH_CAP)
                    node.gained_this_cycle = true
                    node.strength_delta_this_cycle += STRENGTH_DELTA
                    check_solidify_threshold!(node)
                    push!(rewarded, node.id)
                    push!(unsure_rewarded, node.id)
                else
                    push!(coinflip_missed, node.id)
                end
            end
        end
    end

    result = Dict{String, Any}(
        "total_contributors"    => length(contributor_votes),
        "rewarded"              => rewarded,
        "locked_rewarded"       => locked_rewarded,
        "unsure_rewarded"       => unsure_rewarded,
        "skipped_double_reward" => skipped_double_reward,
        "coinflip_missed"       => coinflip_missed,
        "grave_skipped"         => grave_skipped,
    )
    println("[ENGINE] ✅ /right: total=$(length(contributor_votes)) rewarded=$(length(rewarded)) [locked=$(length(locked_rewarded)) unsure=$(length(unsure_rewarded))] double_skip=$(length(skipped_double_reward)) coinflip_miss=$(length(coinflip_missed)) grave_skip=$(length(grave_skipped))")
    return result
end

# GRUG: Old signature kept for backward compat — delegates to new tiered version.
# Any code still calling with just node IDs gets flat 50/50 coinflip for all
# (confidence=0.5 stub, no locked tier).
function apply_right_feedback!(contributor_ids::Vector{String})::Dict{String, Any}
    # Build stub votes with confidence=0.5 (old 50/50 behavior) and empty locked set.
    # This preserves backward compat for any callers that haven't been migrated.
    stub_votes = [Vote(id, "", 0.5, String[], RelationalTriple[], RelationalTriple[], false, "", :singleton)
                  for id in contributor_ids]
    return apply_right_feedback!(stub_votes, Set{String}())
end

function apply_wrong_feedback!(contributor_ids::Vector{String})
    if isempty(contributor_ids)
        error("!!! FATAL: apply_wrong_feedback! got empty contributor_ids list! !!!")
    end

    penalized_count = 0
    graved_count    = 0

    for id in contributor_ids
        node = lock(() -> get(NODE_MAP, id, nothing), NODE_LOCK)
        if isnothing(node)
            # GRUG: Node may have already been graved. Non-fatal, skip.
            println("[ENGINE] ⚠  /wrong: Node [$id] not found, skipping.")
            continue
        end

        was_grave_before = node.is_grave
        penalize_strength!(node)

        penalized_count += 1
        if node.is_grave && !was_grave_before
            graved_count += 1
        end
    end

    println("[ENGINE] ❌  /wrong applied to $(length(contributor_ids)) contributors. penalized= $penalized_count, newly_graved= $graved_count.")
end

# ==============================================================================
# JSON NODE GROWER (MAP EXPANSION)
# ==============================================================================

"""
    ensure_action_packet_registered!(action_packet::AbstractString)

GRUG v7.21c-2: PROSE-SLOT REGISTRY HELPER.

Walks every slot in an action_packet. For each slot's action_name, if it
is not already in COMMANDS:
  - If it looks like prose (>=2 words AND >=8 chars), auto-register a
    passthrough handler that funnels through `generate_aiml_payload`.
  - Otherwise (single short word, looks like a typo): raise a FATAL error
    with the list of valid actions, preserving QoL-2025 BUG-007 behavior.

Called from grow_nodes_from_packet (seed-time) and from load_specimen
(restore-time), so prose-slot nodes survive a save/load round-trip.

Idempotent: registering the same prose action twice is a no-op.
"""
function ensure_action_packet_registered!(action_packet::AbstractString)
    for entry in split(action_packet, '|')
        cleaned = strip(entry)
        isempty(cleaned) && continue
        no_brackets = replace(cleaned, r"\[[^\]]*\]" => "")
        action_name = String(strip(split(no_brackets, '^')[1]))
        isempty(action_name) && continue
        haskey(COMMANDS, action_name) && continue

        is_prose_slot = (length(split(action_name)) >= 2) && (length(action_name) >= 8)
        if is_prose_slot
            COMMANDS[action_name] = (mission, node, primary_vote, sure_votes, unsure_votes, all_votes) -> begin
                return Base.invokelatest(generate_aiml_payload, mission, primary_vote, sure_votes, unsure_votes, all_votes, node.json_data)
            end
        else
            valid_actions = sort(collect(keys(COMMANDS)))
            valid_list = join(valid_actions, ", ")
            error("!!! FATAL: action_packet contains unknown action '$action_name'. " *
                  "Valid actions: $valid_list. " *
                  "(see plans/semantic_plugins/QOL_SWEEP_2025.md BUG-007) !!!")
        end
    end
    return nothing
end

"""
grow_nodes_from_packet(json_str::String; target_lobe::Union{String,Nothing}=nothing,
                                          default_system_prompt::String="Grug speaks plainly.")::Vector{String}

GRUG: Parse a JSON packet and grow new nodes from it.

Supports BOTH packet shapes (QoL-2025 unification):
  - Multi-node:  `{"nodes":[{...}, {...}]}`
  - Single-node: `{"pattern":"...", "action_packet":"...", "data":{...}}`

Per-node fields accepted:
  - `pattern`         (required) — text or image binary descriptor
  - `action_packet`   (required) — pipe-separated `name^weight` entries
  - `data` OR `json_data` — node-internal metadata Dict
                            (BOTH keys accepted; `data` is the new canonical
                            spelling; `json_data` kept for back-compat)
  - `drop_table`      (optional) — co-activation neighbor ID list
  - `is_image_node`   (optional) — flag for image-binary nodes

If `target_lobe` is provided and exists, every grown node is added to that
lobe (Lobe.add_node_to_lobe! + LobeTable.json_to_table_chunk!) so the
topicality gate sees them. If `target_lobe` is `nothing`, nodes go to the
unassigned pool (legacy behavior).

If `data` does not include a `system_prompt` field, `default_system_prompt`
is injected. AIML synthesis requires it; missing it crashes voting with
`FATAL: Node dictionary missing 'system_prompt'!` (see QOL_SWEEP_2025 BUG-010).

Supports `is_image_node` flag in the JSON for image node creation.
If `is_image_node` is true, `pattern` field is treated as image binary descriptor.

Supports `is_antimatch_node` flag (v7.49) for anti-match node creation.
Anti-match nodes are pattern-activated but vote-silent — they drain confidence
from regular votes in the same lobe instead of casting their own vote.
NONJITTER tag makes drain a fixed constant instead of a random tick.
"""
function grow_nodes_from_packet(json_str::String;
                                target_lobe::Union{String,Nothing}=nothing,
                                default_system_prompt::String="Grug speaks plainly.")::Vector{String}
    if strip(json_str) == "" error("!!! FATAL: Cannot grow from empty JSON string !!!") end
    packet = try JSON.parse(json_str) catch e error("!!! FATAL: JSON parser dead: $e !!!") end

    # GRUG QoL-2025: Accept either {"nodes":[...]} or a single node dict.
    nodes_arr = if haskey(packet, "nodes")
        packet["nodes"]
    elseif haskey(packet, "pattern") && haskey(packet, "action_packet")
        [packet]  # treat the packet itself as a single-node entry
    else
        error("!!! FATAL: /grow JSON packet must have either 'nodes' array or top-level 'pattern' + 'action_packet'. !!!")
    end

    validated = Vector{Tuple{String,String,Dict{String,Any},Vector{String},Bool,Bool}}()
    for n in nodes_arr
        pattern      = String(n["pattern"])
        action_packet = String(n["action_packet"])

        # GRUG QoL-2025: Accept both `data` and `json_data` keys for the
        # node-metadata field. They are the same thing under different
        # historic names — `/grow` originally used `json_data`,
        # `/lobeGrow` used `data`. Now: `data` preferred, `json_data` accepted.
        # If both present, prefer `data` and warn.
        raw_data = if haskey(n, "data") && haskey(n, "json_data")
            @warn "[ENGINE] grow_nodes_from_packet: node has BOTH 'data' and 'json_data'; using 'data' and ignoring 'json_data'."
            n["data"]
        elseif haskey(n, "data")
            n["data"]
        elseif haskey(n, "json_data")
            n["json_data"]
        else
            Dict()
        end
        json_data = Dict{String, Any}(string(k) => v for (k, v) in raw_data)

        # GRUG QoL-2025 BUG-010: Inject default system_prompt if missing.
        # AIML synthesis hard-fails without it; quietly defaulting is
        # friendlier than letting the user discover the requirement at
        # vote time.
        if !haskey(json_data, "system_prompt") || isempty(strip(string(get(json_data, "system_prompt", ""))))
            json_data["system_prompt"] = default_system_prompt
        end

        # v7.25: HARD CONFIG WARNING — if the node is missing voice config,
        # it WILL produce incoherent responses. The operator needs to know NOW,
        # not at vote time. These are NOT optional for coherent speech.
        _sp_body = let sp = string(get(json_data, "system_prompt", ""))
            parts = split(sp, "."); isempty(parts) ? "" : strip(join([strip(String(p)) for p in parts[2:end] if !isempty(strip(String(p)))], ". "))
        end
        if isempty(_sp_body) && !haskey(json_data, "noun_anchors")
            @warn """⚠️  COHERENCE WARNING: Node with pattern \"$(haskey(n, "pattern") ? n["pattern"] : "?")\" has single-sentence system_prompt and NO noun_anchors!
               The claim will fall back to the raw pattern — this produces pattern-echo garbage.
               FIX: Make system_prompt multi-sentence (sentence 1 = persona, rest = grug voice)
               OR add \"noun_anchors\" to json_data. YOU NEED THIS OR NO CAN DO."""
        end
        if !haskey(json_data, "voice_register")
            @warn """⚠️  COHERENCE WARNING: Node with pattern \"$(haskey(n, "pattern") ? n["pattern"] : "?")\" has NO voice_register!
               Frame skeleton will be chosen by TonalJudge alone — may not match the node's intent.
               FIX: Add \"voice_register\" to json_data (e.g. \"warm\", \"terse\", \"explanatory\").
               YOU NEED THIS OR NO CAN DO."""
        end
        if !haskey(json_data, "frame_hints")
            @warn """⚠️  COHERENCE WARNING: Node with pattern \"$(haskey(n, "pattern") ? n["pattern"] : "?")\" has NO frame_hints!
               TonalJudge cannot compute frame_match_multiplier for this node.
               FIX: Add \"frame_hints\" to json_data (e.g. [\"warm\", \"plain\"]).
               Valid: warm, exploratory, imperative, contemplative, de-escalating, terse, plain.
               YOU NEED THIS OR NO CAN DO."""
        end

        drop_table   = haskey(n, "drop_table") && (n["drop_table"] isa AbstractVector) ?
                       String[string(x) for x in n["drop_table"]] : String[]
        # GRUG NEW: Check for is_image_node flag in JSON packet
        is_img_node  = haskey(n, "is_image_node") && n["is_image_node"] === true

        # GRUG v7.49: Check for is_antimatch_node flag in JSON packet.
        # Anti-match nodes are pattern-activated confidence drainers — they
        # never vote, never gain/lose strength, and never enter the averages curve.
        is_am_node   = haskey(n, "is_antimatch_node") && n["is_antimatch_node"] === true

        # GRUG QoL-2025 BUG-007 + v7.21c-2 PROSE-SLOT EXTENSION:
        # Validate every action name against COMMANDS at grow time, but
        # auto-register prose answer-slots (multi-word, 8+ chars). Single-word
        # unknown actions are still treated as typos.
        ensure_action_packet_registered!(action_packet)

        push!(validated, (pattern, action_packet, json_data, drop_table, is_img_node, is_am_node))
    end

    new_ids = String[]
    for (p, a, j, d, is_img, is_am) in validated
        # GRUG: Optional initial_strength from json_data. Lets seed packets
        # anchor "obvious-winner" nodes (e.g. greeting's "good morning" node
        # for a greeting-domain query) at high strength so the strength-biased
        # coinflip and downstream confidence ranking favor them. Honest fallback
        # to 1.0 default if missing or malformed. Clamped to [FLOOR, CAP] inside
        # create_node, so a packet asking for strength=999 lands at STRENGTH_CAP
        # rather than crashing.
        init_str = 1.0
        if haskey(j, "initial_strength")
            try
                init_str = Float64(j["initial_strength"])
            catch e
                @warn "[ENGINE] grow_nodes_from_packet: bad initial_strength on a node ($(j["initial_strength"])), falling back to 1.0: $e"
            end
        end
        nid = create_node(p, a, j, d; is_image_node=is_img, is_antimatch_node=is_am, initial_strength=init_str)
        push!(new_ids, nid)

        # GRUG QoL-2025 BUG-008: If a target lobe was specified, route the
        # node into it AND register its json_data in the lobe table so the
        # topicality gate can reason about it.
        if !isnothing(target_lobe) && isdefined(@__MODULE__, :Lobe)
            try
                if haskey(Lobe.LOBE_REGISTRY, target_lobe)
                    alive = count_alive_nodes_in_lobe(target_lobe)
                    Lobe.add_node_to_lobe!(target_lobe, nid; alive_count=alive)
                    LobeTable.json_to_table_chunk!(target_lobe, nid, j)
                    LobeTable.drop_table_to_chunk!(target_lobe, nid, d)

                    # GRUG: STOCHASTIC AIML GROWTH — when a main node lands in a
                    # lobe, coinflip ~1/3 to auto-grow an AIML executive node.
                    # This makes the AIML sub-population grow at approximately
                    # 1/3 the rate of the main population, stochastically.
                    # No lockstep. No rigidity. Just moss on the cave wall.
                    # data_warrant=1.0 because the USER explicitly planted this
                    # node — their intent IS the data signal. No blind growth.
                    if isdefined(@__MODULE__, :AIMLNodeSystem)
                        try
                            AIMLNodeSystem.stochastic_aiml_growth!(target_lobe, p; data_warrant=1.0)
                        catch e
                            @warn "[ENGINE] grow_nodes_from_packet: stochastic AIML growth failed for lobe '$target_lobe': $e"
                        end
                    end
                else
                    @warn "[ENGINE] grow_nodes_from_packet: target_lobe '$target_lobe' does not exist; node '$nid' grown into unassigned pool."
                end
            catch e
                @warn "[ENGINE] grow_nodes_from_packet: failed to attach node '$nid' to lobe '$target_lobe': $e"
            end
        end
    end
    return new_ids
end

# ==============================================================================
# NODE STATUS SUMMARY (FOR /nodes COMMAND)
# ==============================================================================

"""
get_node_status_summary()::String

GRUG: Return a human-readable summary of all nodes: strength, neighbors, grave status.
Used by the /nodes CLI command.
"""
function get_node_status_summary()::String
    lines = String[]
    lock(NODE_LOCK) do
        if isempty(NODE_MAP)
            push!(lines, "[NODE MAP EMPTY]")
            return
        end
        push!(lines, "=== NODE MAP STATUS ($(length(NODE_MAP)) nodes) ===")
        for (id, node) in sort(collect(NODE_MAP), by=x->x[1])
            grave_tag  = node.is_grave     ? "[$(node.grave_reason)]" : "[ALIVE]"
            link_tag   = node.is_unlinkable ? "[UNLINKABLE]"          : "[LINKABLE]"
            img_tag    = node.is_image_node ? "[IMG]"                 : "[TXT]"
            am_tag     = node.is_antimatch_node ? "[ANTIMATCH]"      : ""
            avg_rt     = isempty(node.response_times) ? "N/A" :
                         "$(round(sum(node.response_times)/length(node.response_times), digits=3))s"
            nj_tag     = is_nonjitter(node) ? "[NONJITTER]" : ""
            push!(lines, "  $id | str=$(round(node.strength, digits=2)) | neighbors=$(length(node.neighbor_ids)) | $grave_tag $link_tag $img_tag $am_tag $nj_tag | avg_rt=$avg_rt | pattern=\"$(first(node.pattern, 40))\"")
        end
    end
    return join(lines, "\n")
end

# ==============================================================================
# AIML RULE TABLE (STOCHASTIC ORCHESTRATION RULES)
# ==============================================================================
# GRUG: Rule table lives here so Engine and test runner can both access it.
# Main.jl uses add_orchestration_rule! to populate it at runtime.

# GRUG: AIML rules are STOCHASTIC! Each rule has a fire probability [0.0, 1.0].
# At evaluation time, Grug rolls a coinflip against the probability.
# Rules with prob=1.0 always fire (deterministic). prob=0.5 fires half the time.
struct StochasticRule
    text::String               # GRUG: Rule template text (with magic word placeholders)
    fire_probability::Float64  # GRUG: [0.0, 1.0] - how often this rule fires
end

const AIML_DROP_TABLE = StochasticRule[]
const _DROP_TABLE_LOCK = ReentrantLock()

# GRUG: Allowed magic word tags. Fake tags are rejected loudly!
const ALLOWED_RULE_TAGS = Set([
    "{MISSION}",
    "{PRIMARY_ACTION}",
    "{SURE_ACTIONS}",
    "{UNSURE_ACTIONS}",
    "{ALL_ACTIONS}",
    "{CONFIDENCE}",
    "{NODE_ID}",
    "{MEMORY}",
    "{LOBE_CONTEXT}",
    "{VOTE_CERTAINTY}",
    "{TIED_ALTERNATIVES}"
])

"""
add_orchestration_rule!(rule_input::String)::String

GRUG: Add a stochastic rule to the AIML rule board.
Optional [prob=X.XX] suffix sets fire probability (default 1.0).
Validates all magic word tags. Throws loudly on invalid input.
"""
function add_orchestration_rule!(rule_input::String)::String
    if strip(rule_input) == ""
        error("!!! FATAL: Grug cannot add empty air to rule board! !!!")
    end

    # GRUG: Parse optional stochastic probability suffix [prob=X.XX]
    prob_match = match(r"\[prob=([0-9.]+)\]\s*$", rule_input)
    fire_prob  = 1.0
    rule_text  = rule_input

    if !isnothing(prob_match)
        parsed_prob = tryparse(Float64, prob_match.captures[1])
        if isnothing(parsed_prob) || parsed_prob < 0.0 || parsed_prob > 1.0
            error("!!! FATAL: /addRule [prob=X] value is invalid: '$(prob_match.captures[1])'. Must be 0.0-1.0 !!!")
        end
        fire_prob = parsed_prob
        # GRUG: Strip the [prob=...] suffix from the rule text before storing
        rule_text = strip(replace(rule_input, r"\[prob=[0-9.]+\]\s*$" => ""))
    end

    if strip(rule_text) == ""
        error("!!! FATAL: Rule text is empty after stripping probability suffix! !!!")
    end

    # GRUG: Strict Tag Validation. If tag not in allowed list, throw big rock error!
    for m in eachmatch(r"\{[A-Z_]+\}", rule_text)
        tag = m.match
        if !(tag in ALLOWED_RULE_TAGS)
            error("!!! FATAL: Grug see fake magic rock: $tag! Allowed rocks are: $(join(ALLOWED_RULE_TAGS, ", ")) !!!")
        end
    end

    lock(_DROP_TABLE_LOCK) do
        push!(AIML_DROP_TABLE, StochasticRule(rule_text, fire_prob))
    end
    return "Rule tied to tree: [$rule_text] (fire_prob=$(round(fire_prob, digits=2)))"
end

# ==============================================================================
# ARCHITECTURAL SPECIFICATION: KERNEL LAYER (UPDATED)
#
# 1. PERCEPTUAL SIGNAL MAPPING:
# Natural language strings are deterministically hashed into normalized Float64
# vectors upon node creation and user input. This converts NLP string matching 
# into localized sliding-window signal processing via PatternScanner.jl.
#
# 2. DYNAMIC ATTENTION BOTTLENECK (600-1800):
# scan_specimens implements a biological cap. At evaluation time, active_cap 
# is rolled (600:1800). The node registry is shuffled, and only the capped subset 
# is evaluated. This guarantees bounded compute times while simulating shifting 
# heuristic attention patterns.
#
# 3. DETERMINISTIC PERCEPTION MODES:
# Every active node deterministically scales its sensory resolution (cheap, 
# medium, high_res) based on the complexity score of the user's signal density 
# and relational structure, saving CPU cycles on simple inputs.
#
# 4. STRENGTH SYSTEM (APOPTOSIS + STRATIFICATION):
# Nodes accumulate strength on a coinflip when used. Strength is capped at 
# STRENGTH_CAP to prevent runaway dominance (apoptosis ceiling). Nodes penalized 
# via /wrong lose strength on a coinflip; at 0 they become grave markers used as 
# negative reinforcement during the generative phase.
#
# 5. HOPFIELD FAMILIAR INPUT CACHE:
# High-confidence scan results are stored in HOPFIELD_CACHE keyed by input hash.
# Inputs seen multiple times at high confidence bypass the full scan and fire 
# precached node IDs directly, dramatically reducing compute for familiar patterns.
#
# 6. DROP TABLE CO-ACTIVATION:
# scan_and_expand() extends primary scan results with drop-table neighbor nodes.
# Nodes in a primary node's drop_table co-activate with 80% confidence discount.
# This models associative memory: related concepts activate together.
#
# 7. STRENGTH-BIASED SCAN COINFLIP:
# Before pattern scanning, each node undergoes a strength-biased Bernoulli trial.
# Strong nodes (strength near cap) have ~90% scan probability; weak nodes ~20%.
# This creates a soft attention hierarchy without hard winner-takes-all exclusion.
#
# 8. BIG-O RESPONSE TIME LEDGER:
# Each node tracks its own response time history in a 24-hour rolling ledger.
# v7.21c-5 side-process isolation makes this telemetry-only: slow averages
# are logged but do not change vote confidence or active voting eligibility.
#
# 9. NEIGHBOR LINKING (MAX 4 = UNLINKABLE):
# New nodes latch onto the strongest pattern-similar existing node. Nodes are 
# capped at MAX_NEIGHBORS (4) before being flagged UNLINKABLE. Drop tables and 
# neighbor links form the associative graph structure of the specimen.
#
# 10. LIVE SEMANTIC VERB REGISTRY (SEMANRICVERBS.JL):
# Static const verb sets have been replaced by a mutable runtime registry managed
# by SemanticVerbs.jl. extract_relational_triples() calls get_all_verbs() on every
# invocation, so verbs added via /addVerb take effect immediately on the next input.
# Synonym normalization (normalize_synonyms) runs as the first step of triple
# extraction, before passive rewriting, ensuring alias→canonical mapping happens at
# word boundaries without corrupting partial tokens. Load-time snapshot consts
# (CAUSAL_VERBS, SPATIAL_VERBS, TEMPORAL_VERBS) are preserved for backward
# compatibility with external diagnostic code but must not be used in new matching.
#
# 11. ACTION+TONE PRE-VOTE MODULATION (ACTIONTONEPREDICTOR.JL):
# Before the Hopfield cache check and before the scan loop, scan_specimens() invokes
# ActionTonePredictor.predict_action_tone() to classify the input's action family
# (ASSERT/QUERY/COMMAND/NEGATE/SPECULATE/ESCALATE) and tone family
# (HOSTILE/CURIOUS/DECLARATIVE/URGENT/NEUTRAL/REFLECTIVE) from surface lexical
# markers. The resulting PredictionResult carries an action_weight multiplier that
# is applied per-node inside the scan loop: nodes whose declared action aligns with
# the predicted action family receive a confidence boost; misaligned nodes receive
# a mild suppression (0.85 base + 0.15*(1-conf)). Low-confidence predictions apply
# near-unity multipliers, preserving scan integrity when evidence is weak. Dangling
# causal chain detection emits a non-fatal @warn when the input ends on a verb with
# no object, helping surface ambiguous or truncated inputs.
# ==============================================================================

# ==============================================================================
# LOBE POPULATION HELPERS
# ==============================================================================

"""
    count_alive_nodes_in_lobe(lobe_id::String)::Int

GRUG: Count how many ALIVE (non-grave) nodes belong to a lobe.
Graves are memory, not bloat — dead nodes don't eat cap space.
Returns 0 if lobe doesn't exist or Lobe module not loaded.
"""
function count_alive_nodes_in_lobe(lobe_id::String)::Int
    if !isdefined(@__MODULE__, :Lobe)
        return 0
    end
    lobe_rec = Lobe.get_lobe(lobe_id)
    if isnothing(lobe_rec)
        return 0
    end
    alive_count = 0
    lock(NODE_LOCK) do
        for node_id in lobe_rec.node_ids
            node = get(NODE_MAP, node_id, nothing)
            if !isnothing(node) && !node.is_grave
                alive_count += 1
            end
        end
    end
    return alive_count
end