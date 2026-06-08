# ==============================================================================
# InputDecomposer.jl — v7.28 Compound-Query Decomposition
# ==============================================================================
# GRUG say: when user say one thing, cave scan once, one vote pool, easy.
#           when user say THREE thing in one breath — "what time ALSO what
#           is dinosaur AND what is 2+2" — cave need THREE scan pass, THREE
#           vote pool, but ONE answer. Old grug treat three question as one
#           big jumble. Wrong! Three distinct subject, three distinct scan.
#
# GRUG say: THIS is why multipart system exist. Not because node say "I have
#           many parts". Because INPUT say "I have many parts". The multipart
#           group ID come from HERE — the decomposition layer — and flow DOWN
#           through scan and vote. Node don't know it part of compound query.
#           Only decomposer know.
#
# GRUG say: detection is CONJUNCTION + MULTI-CLAUSE + SIGIL BOUNDARY.
#           "also", "and", "but" when they join two INDEPENDENT clauses.
#           Multiple "?" markers. Multiple sigil expansions. Not every
#           "and" trigger split — "bread and butter" is ONE subject.
#           "what is bread AND what is butter" is TWO subject. Context
#           matter. Heuristic is: conjunction + question marker on both
#           side = split. Conjunction + no question = same subject.
#
# v7.27: GRUG say SPECIMEN OWNS THE CONJUNCTIONS. Not source code. The
#           specimen has decomposer_config with split_conjunctions, compound_pairs,
#           question_markers, command_markers, conjugation_rules. The decomposer
#           reads them at runtime. If specimen doesn't have them, built-in defaults
#           (the old constants) are used. SPECIMEN-OVERRIDES-DEFAULTS.
#
# v7.27: CONJUGATION RULES. "calculates", "calculated", "calculating" all
#           match the "calculate" command marker. The specimen's
#           conjugation_rules maps verb stems to inflected forms. The
#           decomposer expands command_markers to include all inflected forms.
#           Now "describe what fire is and then calculate the total" splits
#           correctly even when the user writes "describes" or "calculated".
# ==============================================================================
#
# ACADEMIC: This module sits at the very front of the processing pipeline,
# BEFORE scan_and_expand. It analyzes the raw user input for compound
# structure — multiple independent sub-subjects that each deserve their own
# scan pass but must be coordinated under one response. The key output is
# a Vector of DecomposedSubSubject, each carrying a unique multipart_group
# ID. Downstream, each sub-subject is scanned independently; votes inherit
# the group ID; MultipartOrchestrator.build_objectives coalesces them.
#
# The decomposition is intentionally heuristic, not syntactic. Full NLP
# parsing would be overkill; the signals are:
#   1. Conjunction boundaries with independent clause structure
#   2. Multiple question markers (each "?" starts a new sub-subject)
#   3. Sigil-class boundaries (arithmetic expressions are distinct subjects)
#   4. Fallback: if heuristics are ambiguous, treat as single subject
#      (false negative is safe; false positive splits what should be one
#      answer, which is worse).
#
# Group IDs are opaque strings: "mp_1", "mp_2", etc. Singleton inputs
# (no decomposition) get a single sub-subject with group_id = "" (matching
# the Vote default for singleton behavior).
# ==============================================================================

module InputDecomposer

export DecomposedSubSubject, decompose_input, is_compound
export InputChunk, chunk_boundaries
export DecomposerConfig, build_config, DEFAULT_CONFIG
export set_config!, get_config
# v7.28: Config mutation exports (for /decomposer CLI)
export add_split_conjunction!, remove_split_conjunction!
export add_compound_pair!, remove_compound_pair!
export add_question_marker!, remove_question_marker!
export add_command_marker!, remove_command_marker!
export add_conjugation_rule!, remove_conjugation_rule!
export set_context_conjunction!, reset_config!
export config_status_string

# ==============================================================================
# STRUCTS
# ==============================================================================

"""
A single sub-subject extracted from a compound input. `text` is the
substring to scan. `multipart_group` is the group ID that will be stamped
onto all votes produced by scanning this sub-subject. `role` is :primary
for the first sub-subject and :support for subsequent ones — this controls
OUTPUT ORDERING in the combined response (first sub-subject's output appears
first). It does NOT determine the vote's multipart_role within MultipartOrchestrator;
every group's winning vote is always :primary within its own group. `index` is
the 1-based position in the decomposition order.
"""
struct DecomposedSubSubject
    text::String
    multipart_group::String
    role::Symbol
    index::Int
end

# ==============================================================================
# INPUT CHUNK — token-range scope for pattern bind phase
# ==============================================================================

#=
    InputChunk — a contiguous token range in the input.

    When the decomposer splits a compound input, each sub-subject covers a
    span of the original tokenized input. InputChunk captures that span as
    (first_token, last_token) indices into the whitespace-split token array,
    plus a chunk_index for fast comparison.

    The scanner already returns best_idx (1-based token position) from
    cheap_scan / medium_scan / high_res_scan. By cross-referencing best_idx
    against InputChunk boundaries, the scan phase can determine which chunk(s)
    a match covers and stamp the resulting vote with input_chunks.

    Bio-coherence: place cells fire for a specific location, not "the
    environment." Object cells fire for a specific object, not "the scene."
    A vote that knows which chunk it resolved is a place-cell vote — it
    carries its own scope instead of relying on an external tag.
=#
struct InputChunk
    first_token::Int    # 1-based index of first token in this chunk
    last_token::Int     # 1-based index of last token in this chunk
    chunk_index::Int    # which chunk this is (1, 2, 3...)
    text::String        # the sub-string this chunk covers (for diagnostics)
end

# ==============================================================================
# DECOMPOSER CONFIG — user-definable via specimen
# ==============================================================================

#=
    DecomposerConfig — all the lists that were previously hardcoded constants.

    The specimen's decomposer_config dict is read at runtime via build_config().
    If the specimen doesn't have a decomposer_config, or a key is missing,
    built-in defaults are used (the old constants). This is
    SPECIMEN-OVERRIDES-DEFAULTS, not specimen-replaces-defaults.

    conjugation_rules: maps verb stem (String) to Vector of inflected forms.
    When checking command_markers, the decomposer also checks all inflected
    forms. So "calculates" matches the "calculate" command marker.

    expanded_command_markers: the FULL set — command_markers + all their
    inflected forms. Built by build_config() from command_markers and
    conjugation_rules. This is what _has_clause_structure actually checks.
=#
struct DecomposerConfig
    split_conjunctions::Set{String}
    compound_pairs::Dict{String,Set{String}}   # "and" → Set(["then","also",...])
    context_conjunction::String
    question_markers::Set{String}
    command_markers::Set{String}               # stems only (for display/diagnostics)
    expanded_command_markers::Set{String}       # stems + all inflected forms
    conjugation_rules::Dict{String,Vector{String}}
end

# ==============================================================================
# BUILT-IN DEFAULTS (the old constants, used when specimen has no config)
# ==============================================================================

const _DEFAULT_SPLIT_CONJUNCTIONS = Set([
    "also", "additionally", "furthermore", "moreover",
    "besides", "likewise", "similarly",
    "but", "however", "yet", "nevertheless", "nonetheless",
    "alternatively", "instead",
    "or",   # "what is X or what is Y" — split
    "then"  # "calculate X and then describe Y" — split at "then"
])

const _DEFAULT_COMPOUND_PAIRS = Dict{String,Set{String}}(
    "and" => Set(["then", "also", "additionally", "furthermore", "moreover"])
)

const _DEFAULT_CONTEXT_CONJUNCTION = "and"

const _DEFAULT_QUESTION_MARKERS = Set([
    "what", "who", "where", "when", "why", "how",
    "which", "whose", "whom"
])

const _DEFAULT_COMMAND_MARKERS = Set([
    "tell", "show", "give", "explain", "describe",
    "calculate", "compute", "solve", "define",
    "list", "name", "find", "count"
])

const _DEFAULT_CONJUGATION_RULES = Dict{String,Vector{String}}(
    "tell"      => ["tells", "told", "telling"],
    "show"      => ["shows", "showed", "showing"],
    "give"      => ["gives", "gave", "giving"],
    "explain"   => ["explains", "explained", "explaining"],
    "describe"  => ["describes", "described", "describing"],
    "calculate" => ["calculates", "calculated", "calculating"],
    "compute"   => ["computes", "computed", "computing"],
    "solve"     => ["solves", "solved", "solving"],
    "define"    => ["defines", "defined", "defining"],
    "list"      => ["lists", "listed", "listing"],
    "name"      => ["names", "named", "naming"],
    "find"      => ["finds", "found", "finding"],
    "count"     => ["counts", "counted", "counting"],
)

"""
    DEFAULT_CONFIG — the built-in config used when no specimen config is provided.
    Built once at module load time from the default constants above.
"""
const DEFAULT_CONFIG = let
    _expanded = copy(_DEFAULT_COMMAND_MARKERS)
    for (stem, forms) in _DEFAULT_CONJUGATION_RULES
        push!(_expanded, stem)
        for f in forms
            push!(_expanded, f)
        end
    end
    DecomposerConfig(
        _DEFAULT_SPLIT_CONJUNCTIONS,
        _DEFAULT_COMPOUND_PAIRS,
        _DEFAULT_CONTEXT_CONJUNCTION,
        _DEFAULT_QUESTION_MARKERS,
        _DEFAULT_COMMAND_MARKERS,
        _expanded,
        _DEFAULT_CONJUGATION_RULES
    )
end

# ==============================================================================
# RUNTIME CONFIG — set by Main.jl when a specimen is loaded
# ==============================================================================

# GRUG: This Ref holds the decomposer config that was loaded from the specimen.
# When Main.jl loads a specimen, it calls set_config!(specimen_dict) which
# builds a DecomposerConfig from the specimen's decomposer_config section
# and stores it here. The single-arg decompose_input(input_text) uses this.
# If no specimen has been loaded, it falls back to DEFAULT_CONFIG.

const _RUNTIME_CONFIG = Ref{DecomposerConfig}(DEFAULT_CONFIG)

"""
    set_config!(specimen_dict) -> DecomposerConfig

Build a DecomposerConfig from the specimen's decomposer_config and store it
as the runtime config. Called by Main.jl after loading a specimen. Returns
the new config for inspection/logging.
"""
function set_config!(specimen_dict)::DecomposerConfig
    cfg = build_config(specimen_dict)
    _RUNTIME_CONFIG[] = cfg
    return cfg
end

"""
    get_config() -> DecomposerConfig

Get the current runtime decomposer config. Useful for diagnostics.
"""
function get_config()::DecomposerConfig
    return _RUNTIME_CONFIG[]
end

# ==============================================================================
# BUILD CONFIG FROM SPECIMEN DICT
# ==============================================================================

"""
    build_config(specimen_dict) -> DecomposerConfig

Build a DecomposerConfig from the specimen's decomposer_config dict.
If the specimen doesn't have a decomposer_config, returns DEFAULT_CONFIG.
If a key is missing, uses the built-in default for that key.

The specimen dict should have a "decomposer_config" key with:
  - "split_conjunctions": Array of strings
  - "compound_pairs": Dict of string → Array of strings
  - "context_conjunction": String
  - "question_markers": Array of strings
  - "command_markers": Array of strings
  - "conjugation_rules": Dict of string → Array of strings

GRUG say: SPECIMEN OWNS THE CONJUNCTIONS. You want "hence" to be a split
conjunction? Put it in decomposer_config.split_conjunctions. You want
"investigate" to be a command marker with conjugation "investigates",
"investigated", "investigating"? Put it in decomposer_config. No source
code edit needed. The specimen is the brain, not the compiler.
"""
function build_config(specimen_dict)::DecomposerConfig
    dc = get(specimen_dict, "decomposer_config", nothing)
    if dc === nothing
        return DEFAULT_CONFIG
    end

    # Split conjunctions
    split_conjs = if haskey(dc, "split_conjunctions")
        Set{String}(String(x) for x in dc["split_conjunctions"])
    else
        _DEFAULT_SPLIT_CONJUNCTIONS
    end

    # Compound pairs
    compound_pairs = if haskey(dc, "compound_pairs")
        Dict{String,Set{String}}(
            String(k) => Set{String}(String(v) for v in vs)
            for (k, vs) in dc["compound_pairs"]
        )
    else
        _DEFAULT_COMPOUND_PAIRS
    end

    # Context conjunction
    context_conj = if haskey(dc, "context_conjunction")
        String(dc["context_conjunction"])
    else
        _DEFAULT_CONTEXT_CONJUNCTION
    end

    # Question markers
    question_markers = if haskey(dc, "question_markers")
        Set{String}(String(x) for x in dc["question_markers"])
    else
        _DEFAULT_QUESTION_MARKERS
    end

    # Command markers (stems)
    command_markers = if haskey(dc, "command_markers")
        Set{String}(String(x) for x in dc["command_markers"])
    else
        _DEFAULT_COMMAND_MARKERS
    end

    # Conjugation rules
    conj_rules = if haskey(dc, "conjugation_rules")
        Dict{String,Vector{String}}(
            String(k) => [String(v) for v in vs]
            for (k, vs) in dc["conjugation_rules"]
        )
    else
        _DEFAULT_CONJUGATION_RULES
    end

    # Expanded command markers: stems + all inflected forms
    expanded = copy(command_markers)
    for (stem, forms) in conj_rules
        push!(expanded, stem)
        for f in forms
            push!(expanded, f)
        end
    end

    return DecomposerConfig(
        split_conjs,
        compound_pairs,
        context_conj,
        question_markers,
        command_markers,
        expanded,
        conj_rules
    )
end

# ==============================================================================
# CHUNK BOUNDARIES — compute InputChunks from decomposed sub-subjects
# ==============================================================================

# GRUG: Characters to strip when matching sub-subject tokens against
# full-input tokens. Decomposition may remove trailing punctuation.
const punctuation_chars = [',', '.', ';', ':', '!', '?', '-', '—']

#=
    chunk_boundaries(input_text) -> Vector{InputChunk}

    Decompose the input, then compute token ranges for each sub-subject.
    Returns a vector of InputChunk, one per sub-subject. For singleton
    inputs, returns one chunk spanning the entire input.

    Uses DEFAULT_CONFIG (no specimen config). For specimen-driven config,
    use chunk_boundaries(input_text, config).
=#
function chunk_boundaries(input_text::String)::Vector{InputChunk}
    return chunk_boundaries(input_text, _RUNTIME_CONFIG[])
end

function chunk_boundaries(input_text::String, config::DecomposerConfig)::Vector{InputChunk}
    if isempty(strip(input_text))
        # Empty input — one chunk spanning nothing
        return [InputChunk(1, 0, 1, "")]
    end

    # Decompose the input first
    subs = decompose_input(input_text, config)

    # Singleton — one chunk spanning everything
    if length(subs) == 1
        n_tokens = length(split(input_text))
        return [InputChunk(1, n_tokens, 1, input_text)]
    end

    # Compound — compute token ranges for each sub-subject.
    # Tokenize the full input once, then find each sub-subject's tokens.
    full_tokens = split(input_text)
    n_full = length(full_tokens)

    # GRUG: Build a mapping from (lowercased token, position) for the full
    # input so we can find where each sub-subject starts.
    # Strategy: walk the full token stream left-to-right. For each
    # sub-subject, find its first token in the remaining full stream,
    # then track how many tokens it covers.
    chunks = InputChunk[]
    full_idx = 1  # current position in full token stream

    for (i, sub) in enumerate(subs)
        sub_tokens = split(sub.text)
        isempty(sub_tokens) && continue

        # GRUG: Find where this sub-subject starts in the full token stream.
        # The sub-subject's tokens are a contiguous subsequence of the full
        # token stream (because decomposition splits at boundaries, it doesn't
        # reorder). We search from full_idx forward.
        first_tok = lowercase(strip(sub_tokens[1], punctuation_chars))
        start_idx = full_idx

        # Scan forward to find the start of this sub-subject
        found = false
        for fi in full_idx:n_full
            ft = lowercase(strip(full_tokens[fi], punctuation_chars))
            if ft == first_tok
                start_idx = fi
                found = true
                break
            end
        end

        if !found
            # Fallback: can't find sub-subject start. Use current position.
            start_idx = full_idx
        end

        # GRUG: The sub-subject covers len(sub_tokens) tokens starting
        # from start_idx. But we need to handle the case where the
        # conjunction that was split on appears in the full stream but
        # not in the sub-subject's text.
        end_idx = min(start_idx + length(sub_tokens) - 1, n_full)

        push!(chunks, InputChunk(start_idx, end_idx, i, sub.text))
        full_idx = end_idx + 1
    end

    # GRUG: If we failed to produce any chunks, fall back to singleton.
    if isempty(chunks)
        return [InputChunk(1, n_full, 1, input_text)]
    end

    return chunks
end

# ==============================================================================
# CORE DECOMPOSITION
# ==============================================================================

"""
    decompose_input(input_text) -> Vector{DecomposedSubSubject}

Analyze the input for compound structure using the runtime config
(set by set_config! from the specimen). If no specimen has been loaded,
uses DEFAULT_CONFIG. For explicit config, use decompose_input(input_text, config).
"""
function decompose_input(input_text::String)::Vector{DecomposedSubSubject}
    return decompose_input(input_text, _RUNTIME_CONFIG[])
end

"""
    decompose_input(input_text, config) -> Vector{DecomposedSubSubject}

Analyze the input for compound structure using the provided DecomposerConfig.
Returns a vector of sub-subjects. If the input is simple (no compound
structure), returns a single sub-subject with multipart_group = "" and
role = :singleton (matching historical behavior).

If compound, each sub-subject gets a unique multipart_group ("mp_1", "mp_2", ...)
and the first sub-subject is :primary while subsequent ones are :support.
NOTE: The .role field controls OUTPUT ORDERING only — it tells the orchestrator
which part to render first. It does NOT set the vote's multipart_role. In
MultipartOrchestrator, every group's winning vote is :primary within its own
group, regardless of this field. The caller (process_mission) stamps :primary
as the vote role for every sub-subject's winning vote.
"""
function decompose_input(input_text::String, config::DecomposerConfig)::Vector{DecomposedSubSubject}
    if isempty(strip(input_text))
        return [DecomposedSubSubject(input_text, "", :singleton, 1)]
    end

    # GRUG: Step 1 — try conjunction-based splitting.
    clauses = _split_on_conjunctions(input_text, config)

    # GRUG: Step 2 — if conjunction splitting found nothing, try
    # question-marker splitting (multiple "?" in the input).
    if length(clauses) <= 1
        clauses = _split_on_question_markers(input_text)
    end

    # GRUG: Step 2b — if still just one clause, try comma-based splitting.
    # "what is X, what is Y, what is Z" — commas between independent questions.
    if length(clauses) <= 1
        clauses = _split_on_comma_clauses(input_text, config)
    end

    # GRUG: Step 3 — still just one clause? Singleton. Old path.
    if length(clauses) <= 1
        # v7.25: HARD WARNING when input LOOKS compound but wasn't decomposed.
        # Heuristic: multiple imperative/question verbs in the input suggest
        # compound structure that the decomposer missed.
        _lower_tokens = [lowercase(replace(t, r"[,;.!?:]" => "")) for t in split(input_text)]
        _cmd_count = count(t -> t in config.expanded_command_markers || t in config.question_markers, _lower_tokens)
        if _cmd_count >= 2
            @warn """⚠️  COHERENCE WARNING: Input looks compound but was NOT decomposed!
               Input: \"$input_text\"
               Found $_cmd_count question/command markers but no split was made.
               The system will pick ONE action and ignore the rest — that's a coherence failure.
               FIX: Add the missing conjunction to decomposer_config.split_conjunctions, or restructure the input.
               YOU NEED DECOMPOSITION FOR COMPOUND INPUT, OR NO CAN DO."""
        end
        return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]
    end

    # GRUG: Multiple clauses detected! Assign group IDs.
    result = DecomposedSubSubject[]
    for (i, clause) in enumerate(clauses)
        clause_text = strip(clause)
        isempty(clause_text) && continue
        group_id = "mp_$i"
        role = i == 1 ? :primary : :support
        push!(result, DecomposedSubSubject(clause_text, group_id, role, i))
    end

    # GRUG: Edge case — if all clauses were empty after stripping, fall back.
    if isempty(result)
        return [DecomposedSubSubject(strip(input_text), "", :singleton, 1)]
    end

    # GRUG: If only one non-empty clause survived, it's a singleton after all.
    if length(result) == 1
        return [DecomposedSubSubject(result[1].text, "", :singleton, 1)]
    end

    return result
end

"""
    is_compound(input_text) -> Bool

Quick check: does this input decompose into multiple sub-subjects?
Cheap — runs decomposition and checks count > 1.
"""
function is_compound(input_text::String)::Bool
    return length(decompose_input(input_text)) > 1
end

# ==============================================================================
# INTERNAL: CONJUNCTION-BASED SPLITTING
# ==============================================================================

"""
    _split_on_conjunctions(input_text, config) -> Vector{String}

Split the input at conjunction boundaries where both sides look like
independent clauses (question or command structure). Returns Vector of
clause strings. If no splits found, returns [input_text].
"""
function _split_on_conjunctions(input_text::String, config::DecomposerConfig)::Vector{String}
    tokens = split(input_text)
    isempty(tokens) && return [input_text]

    # GRUG: Walk the token stream. When we find a split-conjunction,
    # check if both the left and right contexts look independent.
    # "what is time also what is dinosaur" — "also" splits because
    # left has "what" and right has "what".
    # "time also runs fast" — "also" does NOT split because neither
    # side has question/command structure.

    splits = Tuple{Int,Int}[]  # (left_end, right_start) — conjunction tokens to discard
    lower_tokens = [lowercase(replace(t, r"[,;.!?:]" => "")) for t in tokens]

    # v7.26-COMPOUND-CONJ: Track which token indices were consumed as part
    # of a compound conjunction pair (e.g., "and" + "then"). These indices
    # should be skipped in the main loop to prevent double-splitting.
    _consumed = Set{Int}()

    # v7.26-COMPOUND-CONJ: Pre-pass — find compound conjunction pairs
    # ("and then", "and also", etc.) and record them.
    # Uses config.compound_pairs instead of hardcoded COMPOUND_LEADERS.
    for i in 2:(length(tokens) - 1)
        tok = lower_tokens[i]
        if haskey(config.compound_pairs, tok)
            # This token is a compound leader. Check if the next token
            # is one of its compound followers.
            if i + 1 <= length(lower_tokens) && lower_tokens[i + 1] in config.compound_pairs[tok]
                left_has_structure = _has_clause_structure(lower_tokens, 1, i - 1, config)
                right_has_structure = _has_clause_structure(lower_tokens, i + 2, length(tokens), config)
                if left_has_structure && right_has_structure
                    # "and then" — compound conjunction. Left clause ends at i-1,
                    # right clause starts at i+2 (skip both "and" and "then").
                    push!(splits, (i - 1, i + 2))
                    push!(_consumed, i)
                    push!(_consumed, i + 1)
                end
            end
        end
    end

    # Main pass — handle remaining conjunctions (not consumed by compound pass)
    for i in 2:(length(tokens) - 1)
        i in _consumed && continue  # already handled as part of compound pair

        tok = lower_tokens[i]

        # GRUG: Hard split conjunctions — split if right side has
        # question or command structure.
        if tok in config.split_conjunctions
            right_has_structure = _has_clause_structure(lower_tokens, i + 1, length(tokens), config)
            if right_has_structure
                # Left clause ends at i-1, right clause starts at i+1
                # (skip just the conjunction token itself).
                push!(splits, (i - 1, i + 1))
            end
            continue
        end

        # GRUG: "and" — special case. Only split if BOTH sides have
        # independent clause structure (question/command markers).
        # NOTE: "and then" is already handled above (compound conjunction).
        # This branch handles standalone "and" like "what is X and what is Y".
        if tok == config.context_conjunction
            left_has_structure = _has_clause_structure(lower_tokens, 1, i - 1, config)
            right_has_structure = _has_clause_structure(lower_tokens, i + 1, length(tokens), config)
            if left_has_structure && right_has_structure
                push!(splits, (i - 1, i + 1))
            end
            continue
        end
    end

    isempty(splits) && return [input_text]

    # GRUG: Build clause strings from split boundaries.
    # Each split is (left_end, right_start) — tokens[left_end+1..right_start-1]
    # are the conjunction(s) to discard.
    # Sort by left_end to process left-to-right.
    unique_sorted = sort(unique(splits), by = s -> s[1])
    clauses = String[]
    prev = 1
    for (left_end, right_start) in unique_sorted
        # Left clause: tokens[prev:left_end]
        if left_end >= prev
            clause = join(tokens[prev:left_end], " ")
            clause = strip(clause)
            !isempty(clause) && push!(clauses, clause)
        end
        prev = right_start
    end
    # GRUG: Don't forget the last clause!
    if prev <= length(tokens)
        clause = join(tokens[prev:end], " ")
        clause = strip(clause)
        !isempty(clause) && push!(clauses, clause)
    end

    return isempty(clauses) ? [input_text] : clauses
end

# ==============================================================================
# INTERNAL: QUESTION-MARKER SPLITTING
# ==============================================================================

"""
    _split_on_question_markers(input_text) -> Vector{String}

If the input contains multiple "?" characters, split at the sentence
boundary before each subsequent "?". Each question becomes its own
sub-subject. This catches: "what time is it? what is a dinosaur? what is 2+2?"

NOTE: Uses `nextind` for Unicode-safe advancement past the "?" position.
"""
function _split_on_question_markers(input_text::String)::Vector{String}
    # GRUG: Count question marks. If only one (or none), no split.
    q_positions = findall(c -> c == '?', input_text)
    length(q_positions) <= 1 && return [input_text]

    # GRUG: Split at sentence boundaries. A sentence boundary is:
    # after a "?" and any trailing whitespace/punctuation, before the
    # next word character. We look for the gap between sentences.
    clauses = String[]
    last_end = 1

    for qpos in q_positions
        # GRUG: Find the end of this sentence = after "?" and any
        # trailing punctuation/whitespace. Use chktop to avoid running
        # past the end of the string. nextind handles multi-byte chars.
        end_idx = qpos
        while end_idx < lastindex(input_text)
            nxt = nextind(input_text, end_idx)
            input_text[nxt] in " \t,;." || break
            end_idx = nxt
        end

        # GRUG: Extract this clause (from last_end to end of sentence).
        clause = strip(input_text[last_end:min(end_idx, lastindex(input_text))])
        if !isempty(clause)
            push!(clauses, clause)
        end

        last_end = min(nextind(input_text, end_idx), lastindex(input_text) + 1)
    end

    # GRUG: Grab any remaining text after the last "?".
    if last_end <= lastindex(input_text)
        remainder = strip(input_text[last_end:end])
        if !isempty(remainder)
            push!(clauses, remainder)
        end
    end

    return isempty(clauses) ? [input_text] : clauses
end

# ==============================================================================
# INTERNAL: CLAUSE STRUCTURE DETECTION
# ==============================================================================

"""
    _has_clause_structure(lower_tokens, start_idx, end_idx, config) -> Bool

Check if the token range [start_idx, end_idx] contains question or command
markers that indicate independent clause structure. Used to decide whether
a conjunction should trigger a split.

Uses config.expanded_command_markers (which includes inflected forms)
instead of just the stem forms. So "calculates" matches "calculate".
"""
function _has_clause_structure(lower_tokens::Vector{String},
                                start_idx::Int,
                                end_idx::Int,
                                config::DecomposerConfig)::Bool
    for i in start_idx:end_idx
        if i < 1 || i > length(lower_tokens)
            continue
        end
        tok = lower_tokens[i]
        if tok in config.question_markers || tok in config.expanded_command_markers
            return true
        end
    end
    return false
end

# ==============================================================================
# INTERNAL: COMMA-BASED CLAUSE SPLITTING
# ==============================================================================

"""
    _split_on_comma_clauses(input_text, config) -> Vector{String}

Split the input at comma boundaries where both sides look like independent
questions or commands. This catches: "what is X, what is Y, what is Z" —
a common compound pattern that lacks explicit conjunctions.

Comma splitting is tried LAST (after conjunctions and question markers)
because commas are ambiguous: "bread, butter, and cheese" is ONE subject,
but "what is X, what is Y" is TWO. We only split when both sides have
clause structure (question/command markers).
"""
function _split_on_comma_clauses(input_text::String, config::DecomposerConfig)::Vector{String}
    # GRUG: Only try if there are at least 1 comma.
    comma_positions = findall(c -> c == ',', input_text)
    length(comma_positions) < 1 && return [input_text]

    tokens = split(input_text)
    isempty(tokens) && return [input_text]
    lower_tokens = [lowercase(replace(t, r"[,;.!?:]" => "")) for t in tokens]

    # GRUG: Walk the token stream. When we find a comma, check if the
    # right side starts a new independent clause (question/command marker).
    splits = Int[]
    for (tok_idx, tok) in enumerate(tokens)
        if endswith(tok, ",")
            # Check if the NEXT token starts a question/command clause.
            if tok_idx < length(tokens)
                next_tok = lower_tokens[tok_idx + 1]
                if next_tok in config.question_markers || next_tok in config.expanded_command_markers
                    push!(splits, tok_idx + 1)
                end
            end
        end
    end

    isempty(splits) && return [input_text]

    # GRUG: Build clause strings from split positions.
    unique_sorted = sort(unique(splits))
    clauses = String[]
    prev = 1
    for split_idx in unique_sorted
        if split_idx > prev
            clause = strip(join(tokens[prev:split_idx-1], " "), ',')
            clause = strip(clause)
            !isempty(clause) && push!(clauses, clause)
        end
        prev = split_idx
    end
    # Don't forget the last clause!
    if prev <= length(tokens)
        clause = strip(join(tokens[prev:end], " "), ',')
        clause = strip(clause)
        !isempty(clause) && push!(clauses, clause)
    end

    return isempty(clauses) ? [input_text] : clauses
end

# ==============================================================================
# CONFIG MUTATION — runtime editing via /decomposer CLI
# ==============================================================================
#
# GRUG say: SPECIMEN OWNS THE CONJUNCTIONS, but OPERATOR OWNS THE RUNTIME.
# These functions mutate _RUNTIME_CONFIG in place. They are called by the
# /decomposer CLI command in Main.jl. Every mutation:
#   1. Validates input (no empty strings, no duplicates where forbidden)
#   2. Mutates the _RUNTIME_CONFIG Ref
#   3. Returns a human-readable success string
#   4. Throws ArgumentError on invalid input (caller catches and hard-warns)
#
# NO SILENT FAILURES. If something goes wrong, the operator MUST see it.
# If a word is already in the set, that's not an error — it's a no-op with
# a visible "already present" message. The operator needs to KNOW.

"""
    add_split_conjunction!(word) -> String

Add a word to the runtime split_conjunctions set. These are words that
trigger a hard split when the right side has clause structure.
Returns a status message. Throws ArgumentError on empty input.
"""
function add_split_conjunction!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot add empty string as split conjunction"))
    cfg = _RUNTIME_CONFIG[]
    if word in cfg.split_conjunctions
        return "⚠  '$word' already in split_conjunctions (no change)"
    end
    push!(cfg.split_conjunctions, word)
    _RUNTIME_CONFIG[] = cfg  # re-store (Set mutation may not trigger Ref update)
    return "✅ Added '$word' to split_conjunctions (now $(length(cfg.split_conjunctions)) total)"
end

"""
    remove_split_conjunction!(word) -> String

Remove a word from the runtime split_conjunctions set.
Returns a status message. Throws ArgumentError if word not present.
"""
function remove_split_conjunction!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot remove empty string from split conjunctions"))
    cfg = _RUNTIME_CONFIG[]
    if !(word in cfg.split_conjunctions)
        throw(ArgumentError("'$word' not in split_conjunctions — cannot remove what isn't there"))
    end
    delete!(cfg.split_conjunctions, word)
    _RUNTIME_CONFIG[] = cfg
    return "✅ Removed '$word' from split_conjunctions (now $(length(cfg.split_conjunctions)) total)"
end

"""
    add_compound_pair!(leader, follower) -> String

Add a follower to a compound pair. If the leader doesn't exist yet,
creates the entry. Compound pairs are conjunction pairs like
"and then", "and also" that are treated as a single split point.
Returns a status message. Throws ArgumentError on empty input.
"""
function add_compound_pair!(leader::String, follower::String)::String
    leader = strip(lowercase(leader))
    follower = strip(lowercase(follower))
    isempty(leader) && throw(ArgumentError("Compound pair leader cannot be empty"))
    isempty(follower) && throw(ArgumentError("Compound pair follower cannot be empty"))
    cfg = _RUNTIME_CONFIG[]
    if !haskey(cfg.compound_pairs, leader)
        cfg.compound_pairs[leader] = Set{String}([follower])
        _RUNTIME_CONFIG[] = cfg
        return "✅ Created compound pair '$leader' → {'$follower'} (new leader)"
    end
    if follower in cfg.compound_pairs[leader]
        return "⚠  '$leader' → '$follower' already in compound_pairs (no change)"
    end
    push!(cfg.compound_pairs[leader], follower)
    _RUNTIME_CONFIG[] = cfg
    return "✅ Added '$follower' to compound pair '$leader' (now $(length(cfg.compound_pairs[leader])) followers)"
end

"""
    remove_compound_pair!(leader, follower) -> String

Remove a follower from a compound pair. If the leader has no followers
left after removal, the leader entry is deleted entirely.
Throws ArgumentError if the pair doesn't exist.
"""
function remove_compound_pair!(leader::String, follower::String)::String
    leader = strip(lowercase(leader))
    follower = strip(lowercase(follower))
    isempty(leader) && throw(ArgumentError("Compound pair leader cannot be empty"))
    isempty(follower) && throw(ArgumentError("Compound pair follower cannot be empty"))
    cfg = _RUNTIME_CONFIG[]
    if !haskey(cfg.compound_pairs, leader)
        throw(ArgumentError("'$leader' not in compound_pairs — no such leader"))
    end
    if !(follower in cfg.compound_pairs[leader])
        throw(ArgumentError("'$follower' not in compound_pairs['$leader'] — cannot remove what isn't there"))
    end
    delete!(cfg.compound_pairs[leader], follower)
    if isempty(cfg.compound_pairs[leader])
        delete!(cfg.compound_pairs, leader)
        _RUNTIME_CONFIG[] = cfg
        return "✅ Removed '$follower' from '$leader'; leader had no followers left, removed '$leader' entry entirely"
    end
    _RUNTIME_CONFIG[] = cfg
    return "✅ Removed '$follower' from compound pair '$leader' (now $(length(cfg.compound_pairs[leader])) followers)"
end

"""
    add_question_marker!(word) -> String

Add a word to the runtime question_markers set (what, who, where, etc.).
Returns a status message. Throws ArgumentError on empty input.
"""
function add_question_marker!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot add empty string as question marker"))
    cfg = _RUNTIME_CONFIG[]
    if word in cfg.question_markers
        return "⚠  '$word' already in question_markers (no change)"
    end
    push!(cfg.question_markers, word)
    _RUNTIME_CONFIG[] = cfg
    return "✅ Added '$word' to question_markers (now $(length(cfg.question_markers)) total)"
end

"""
    remove_question_marker!(word) -> String

Remove a word from the runtime question_markers set.
Throws ArgumentError if word not present.
"""
function remove_question_marker!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Cannot remove empty string from question markers"))
    cfg = _RUNTIME_CONFIG[]
    if !(word in cfg.question_markers)
        throw(ArgumentError("'$word' not in question_markers — cannot remove what isn't there"))
    end
    delete!(cfg.question_markers, word)
    _RUNTIME_CONFIG[] = cfg
    return "✅ Removed '$word' from question_markers (now $(length(cfg.question_markers)) total)"
end

"""
    add_command_marker!(stem, conjugated_forms) -> String

Add a verb stem to command_markers AND all its conjugated forms to
expanded_command_markers. Also records the conjugation rule.
If conjugated_forms is empty, only the stem is added (no conjugation).
Returns a status message. Throws ArgumentError on empty stem.
"""
function add_command_marker!(stem::String, conjugated_forms::Vector{String}=String[])::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Cannot add empty string as command marker"))
    cfg = _RUNTIME_CONFIG[]
    was_new = !(stem in cfg.command_markers)
    push!(cfg.command_markers, stem)
    push!(cfg.expanded_command_markers, stem)  # stem itself is always in expanded
    if !isempty(conjugated_forms)
        # GRUG: Store the conjugation rule AND expand all forms
        clean_forms = [strip(lowercase(f)) for f in conjugated_forms if !isempty(strip(f))]
        cfg.conjugation_rules[stem] = clean_forms
        for f in clean_forms
            push!(cfg.expanded_command_markers, f)
        end
    end
    _RUNTIME_CONFIG[] = cfg
    n_expanded = length(cfg.expanded_command_markers)
    if was_new
        if isempty(conjugated_forms)
            return "✅ Added command marker '$stem' (no conjugation; now $n_expanded expanded markers)"
        else
            return "✅ Added command marker '$stem' with conjugation $(conjugated_forms) (now $n_expanded expanded markers)"
        end
    else
        # Already existed — but may have added new conjugation
        if isempty(conjugated_forms)
            return "⚠  '$stem' already in command_markers (no change)"
        else
            return "✅ Updated conjugation for '$stem' → $(conjugated_forms) (now $n_expanded expanded markers)"
        end
    end
end

"""
    remove_command_marker!(stem) -> String

Remove a verb stem from command_markers AND all its conjugated forms
from expanded_command_markers. Also removes the conjugation rule.
Throws ArgumentError if stem not present.
"""
function remove_command_marker!(stem::String)::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Cannot remove empty string from command markers"))
    cfg = _RUNTIME_CONFIG[]
    if !(stem in cfg.command_markers)
        throw(ArgumentError("'$stem' not in command_markers — cannot remove what isn't there"))
    end
    delete!(cfg.command_markers, stem)
    delete!(cfg.expanded_command_markers, stem)
    # GRUG: Also remove all conjugated forms for this stem
    if haskey(cfg.conjugation_rules, stem)
        for f in cfg.conjugation_rules[stem]
            delete!(cfg.expanded_command_markers, f)
        end
        delete!(cfg.conjugation_rules, stem)
    end
    _RUNTIME_CONFIG[] = cfg
    return "✅ Removed command marker '$stem' and its conjugated forms (now $(length(cfg.expanded_command_markers)) expanded markers)"
end

"""
    add_conjugation_rule!(stem, forms) -> String

Add or replace a conjugation rule for a verb stem. Also updates
expanded_command_markers with the new forms. The stem MUST already
be in command_markers — you can't conjugate what you don't mark.
Throws ArgumentError if stem not in command_markers or forms empty.
"""
function add_conjugation_rule!(stem::String, forms::Vector{String})::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Conjugation rule stem cannot be empty"))
    isempty(forms) && throw(ArgumentError("Conjugation rule must have at least one form"))
    cfg = _RUNTIME_CONFIG[]
    if !(stem in cfg.command_markers)
        throw(ArgumentError("'$stem' not in command_markers — add it with /decomposer addCommand first"))
    end
    # GRUG: Remove old forms from expanded if they existed
    if haskey(cfg.conjugation_rules, stem)
        for old_f in cfg.conjugation_rules[stem]
            delete!(cfg.expanded_command_markers, old_f)
        end
    end
    # Add new forms
    clean_forms = [strip(lowercase(f)) for f in forms if !isempty(strip(f))]
    isempty(clean_forms) && throw(ArgumentError("All conjugation forms were empty after trimming"))
    cfg.conjugation_rules[stem] = clean_forms
    for f in clean_forms
        push!(cfg.expanded_command_markers, f)
    end
    _RUNTIME_CONFIG[] = cfg
    return "✅ Set conjugation rule '$stem' → $clean_forms (now $(length(cfg.expanded_command_markers)) expanded markers)"
end

"""
    remove_conjugation_rule!(stem) -> String

Remove a conjugation rule for a verb stem. Also removes the inflected
forms from expanded_command_markers. The stem itself stays in
command_markers and expanded_command_markers.
Throws ArgumentError if no rule exists for this stem.
"""
function remove_conjugation_rule!(stem::String)::String
    stem = strip(lowercase(stem))
    isempty(stem) && throw(ArgumentError("Conjugation rule stem cannot be empty"))
    cfg = _RUNTIME_CONFIG[]
    if !haskey(cfg.conjugation_rules, stem)
        throw(ArgumentError("No conjugation rule for '$stem' — cannot remove what isn't there"))
    end
    for f in cfg.conjugation_rules[stem]
        delete!(cfg.expanded_command_markers, f)
    end
    delete!(cfg.conjugation_rules, stem)
    _RUNTIME_CONFIG[] = cfg
    return "✅ Removed conjugation rule for '$stem' (stem still in command_markers; now $(length(cfg.expanded_command_markers)) expanded markers)"
end

"""
    set_context_conjunction!(word) -> String

Set the context conjunction (default: "and"). This is the conjunction
that only triggers a split when BOTH sides have clause structure.
Throws ArgumentError on empty input.
"""
function set_context_conjunction!(word::String)::String
    word = strip(lowercase(word))
    isempty(word) && throw(ArgumentError("Context conjunction cannot be empty"))
    cfg = _RUNTIME_CONFIG[]
    old = cfg.context_conjunction
    cfg = DecomposerConfig(  # Reconstruct — context_conjunction is immutable in struct
        cfg.split_conjunctions,
        cfg.compound_pairs,
        word,  # new context conjunction
        cfg.question_markers,
        cfg.command_markers,
        cfg.expanded_command_markers,
        cfg.conjugation_rules
    )
    _RUNTIME_CONFIG[] = cfg
    return "✅ Context conjunction changed: '$old' → '$word'"
end

"""
    reset_config!() -> String

Reset the runtime config to built-in defaults. NO SILENT SURPRISE:
this is a hard reset, and the operator is told exactly what they lost.
"""
function reset_config!()::String
    old_n = length(_RUNTIME_CONFIG[].split_conjunctions)
    _RUNTIME_CONFIG[] = DEFAULT_CONFIG
    new_n = length(DEFAULT_CONFIG.split_conjunctions)
    return "✅ Decomposer config reset to built-in defaults (was $old_n split_conjunctions, now $new_n)"
end

# ==============================================================================
# DIAGNOSTICS
# ==============================================================================

"""
    summarize_decomposition(sub_subjects) -> String

One-line diagnostic summary of a decomposition result.
"""
function summarize_decomposition(subs::Vector{DecomposedSubSubject})::String
    if length(subs) == 1
        return "[singleton] \"$(subs[1].text)\""
    end
    parts = ["[$(s.multipart_group)/$(s.role)] \"$(s.text)\"" for s in subs]
    return "compound($(length(subs)) parts): " * join(parts, " | ")
end

"""
    config_status_string() -> String

Multi-line formatted string showing the full runtime decomposer config.
Used by /decomposer status command. NO SILENT ANYTHING — every field
is shown, even if empty.
"""
function config_status_string()::String
    cfg = _RUNTIME_CONFIG[]
    lines = String[]

    push!(lines, "╔══════════════════════════════════════════════════════════╗")
    push!(lines, "║            ✂️  DECOMPOSER CONFIG STATUS                  ║")
    push!(lines, "╠══════════════════════════════════════════════════════════╣")

    # Split conjunctions
    push!(lines, "  SPLIT CONJUNCTIONS ($(length(cfg.split_conjunctions))):")
    push!(lines, "    $(join(sort(collect(cfg.split_conjunctions)), ", "))")

    # Compound pairs
    push!(lines, "  COMPOUND PAIRS ($(length(cfg.compound_pairs)) leaders):")
    for (leader, followers) in sort(collect(cfg.compound_pairs), by=x->x[1])
        push!(lines, "    '$leader' → $(join(sort(collect(followers)), ", "))")
    end

    # Context conjunction
    push!(lines, "  CONTEXT CONJUNCTION: '$(cfg.context_conjunction)'")

    # Question markers
    push!(lines, "  QUESTION MARKERS ($(length(cfg.question_markers))):")
    push!(lines, "    $(join(sort(collect(cfg.question_markers)), ", "))")

    # Command markers (stems)
    push!(lines, "  COMMAND MARKERS (stems: $(length(cfg.command_markers)), expanded: $(length(cfg.expanded_command_markers))):")
    push!(lines, "    Stems: $(join(sort(collect(cfg.command_markers)), ", "))")

    # Conjugation rules
    push!(lines, "  CONJUGATION RULES ($(length(cfg.conjugation_rules))):")
    for (stem, forms) in sort(collect(cfg.conjugation_rules), by=x->x[1])
        push!(lines, "    '$stem' → $(join(forms, ", "))")
    end

    push!(lines, "╚══════════════════════════════════════════════════════════╝")
    return join(lines, "\n")
end

end # module
