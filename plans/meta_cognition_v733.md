# GRUG v7.33: Meta-Cognition — The Observing Eye

## The Insight

Code is just very anal linguistic philosophy. Grug doesn't need code levers — it needs
to think more meta. Code is not the only language tool. The problem isn't "how does
Grug emit code strings" — it's "how does Grug observe its own output patterns and
invent new approaches instead of rotating through pre-made ones."

## What We Have Now (The Plumbing)

The machinery for meta-cognition partially exists already. It's just pointed at the
wrong target:

| Component | What It Does Now | What It Could Do |
|-----------|-----------------|-------------------|
| SelfObserver | Records MLP cycle metadata (activation mode, novelty, quality) — observes the *brain's internals* | Observe the *output itself* — what patterns are in the text we just emitted |
| EphemeralMLP | Transforms vote list before orchestration — adjusts *input selection* | Adjust *output shaping* based on observed patterns |
| Phase Accumulator | Tracks action/tone distribution over time — the brain's *rhythm* | Could track *linguistic* distribution — sentence shapes, connector usage, vocabulary repetition |
| Skeleton Pools (v7.32) | Randomize surface variety — mechanical rotation | Could be *adaptively* weighted — deplete overused shapes, boost dormant ones |
| _RECENT_PREAMBLES cache | 20-entry ring buffer, simple hit/miss | Could carry *counts* and *timestamps* — "this shape has been used 4x in last 10 cycles" |
| Thesaurus swap | 25% random word swap from fixed synset | Could be *driven by observation* — "you keep saying X, try Y instead" |
| EphemeralAutomaton | Step machine with :userfn, :setctx, :getctx | Could run *post-output reflection steps* — analyze, tag, feed back |

## The Gap: No Output Observation Loop

Right now the pipeline is:

```
Input → Scan → Vote → MLP → Skeleton → Synonym Swap → EMIT → (done, no lookback)
```

Grug generates text, prints it, stores a digest, and never thinks about it again.
The SelfObserver only watches the MLP cycle metadata (activation mode, novelty score).
Nobody watches the *actual words*.

What's needed:

```
Input → Scan → Vote → MLP → Skeleton → Synonym Swap → EMIT
                                                         ↓
                                              OBSERVE (SelfObserver)
                                                         ↓
                                              REFLECT (new: meta-layer)
                                                         ↓
                                              ADJUST (weight future picks)
```

## The Concrete Proposal: Output Self-Observation

### Step 1: Observe the output (wire into existing SelfObserver)

After `output` is assembled (line ~3911), before it's printed, observe it into
`_MLP_OBSERVER_STORE` with tag `:meta` (already a valid tag). The payload captures
the linguistic fingerprint:

```julia
# After output is assembled, before println
try
    SelfObserver.observe!(
        _MLP_OBSERVER_STORE,
        "output_$(round(Int, time()))",
        :meta,
        Dict{String, Any}(
            "frame"          => judged_frame_label,
            "action"         => String(primary_vote.action),
            "connector_used" => connector,       # which of the 8 connectors fired
            "skeleton_used"  => skeleton,         # the actual skeleton string picked
            "word_count"     => length(split(output)),
            "unique_words"   => length(unique(split(lowercase(output)))),
            "repetition_ratio" => 1.0 - length(unique(split(lowercase(output)))) /
                                       max(1, length(split(output))),
        )
    )
catch e
    @warn "[MAIN] Output self-observation failed (non-fatal): $e"
end
```

This is almost free — the observation is stochastic (p_write default ~0.3) and
the store already has eviction and bounded size. It doesn't slow the pipeline.
But it starts building a *record* of what Grug actually says.

### Step 2: Reflect on patterns (new: `_reflect_on_output()`)

A lightweight function that peeks at recent observations and returns structured
hints about patterns. This is the "meta" layer — Grug looking at its own trail.

```julia
function _reflect_on_output()::Dict{String, Any}
    hints = SelfObserver.peek_pattern(
        _MLP_OBSERVER_STORE,
        "system",           # node_id for system-level reflection
        "output_";          # key prefix
        max_entries = 20
    )
    isempty(hints) && return Dict{String, Any}("status" => "no_observations_yet")

    # Count connector usage
    connectors_seen = Dict{String, Int}()
    frames_seen = Dict{String, Int}()
    for h in hints
        haskey(h.payload_strings, "connector_used") &&
            (connectors_seen[h.payload_strings["connector_used"]] =
                get(connectors_seen, h.payload_strings["connector_used"], 0) + 1)
        haskey(h.payload_strings, "frame") &&
            (frames_seen[h.payload_strings["frame"]] =
                get(frames_seen, h.payload_strings["frame"], 0) + 1)
    end

    # Detect overuse: any single connector > 50% of recent observations
    total = sum(values(connectors_seen))
    overused_connectors = [c for (c, n) in connectors_seen if total > 0 && n / total > 0.5]
    overused_frames = [f for (f, n) in frames_seen if total > 0 && n / total > 0.5]

    return Dict{String, Any}(
        "recent_outputs"      => length(hints),
        "connectors_seen"     => connectors_seen,
        "frames_seen"         => frames_seen,
        "overused_connectors" => overused_connectors,
        "overused_frames"     => overused_frames,
    )
end
```

### Step 3: Adjust based on reflection (adaptive pool weighting)

This is where the alchemy becomes real. Instead of uniform random from pools,
_weight against overused shapes_:

```julia
# When picking from a pool, if reflection says connector X is overused,
# temporarily suppress its weight.
function _pick_connector_adaptive()::String
    reflection = _reflect_on_output()
    overused = get(reflection, "overused_connectors", String[])
    
    if isempty(overused)
        return _pick_connector()  # normal weighted random
    end
    
    # Suppress overused connectors by zeroing their weight temporarily
    weights = copy(_CLAIM_CONNECTOR_WEIGHTS)
    for (i, c) in enumerate(_CLAIM_CONNECTORS)
        if c in overused
            weights[i] *= 0.1  # don't zero — just suppress heavily
        end
    end
    # Renormalize
    total = sum(weights)
    weights = weights ./ total
    
    r = rand()
    cum = 0.0
    for (i, w) in enumerate(weights)
        cum += w
        r <= cum && return _CLAIM_CONNECTORS[i]
    end
    return _CLAIM_CONNECTORS[1]
end
```

## The Deeper Point: This Isn't Just About Repetition

Once the output observation loop exists, it becomes a *general-purpose* meta-cognitive
foundation:

- **Code as linguistic tool**: If Grug observes its own Julia output and notices
  "I keep using for loops, never map/filter," that observation can drive a
  skeleton pool for code-style variety. Same machinery, different surface.

- **Conversation as linguistic tool**: If Grug notices "I keep asking questions,
  never making statements," the same reflection→adjustment loop can shift
  conversational stance.

- **Any symbolic manipulation**: The pattern is observe → reflect → adjust.
  Code, prose, math, conversation — same loop. The tool isn't "a code generator,"
  the tool is *the ability to notice what you're doing and change it*.

## Implementation Order

1. **Output observation** — wire SelfObserver.observe! into the emit path (5 min)
2. **Reflection function** — _reflect_on_output() that peeks and detects patterns (10 min)
3. **Adaptive connector pick** — _pick_connector_adaptive() replacing _pick_connector() (5 min)
4. **Adaptive pool pick** — same idea for skeleton pools, weight against overused shapes (5 min)
5. **Test** — verify reflection detects overuse and adjustment suppresses it (5 min)

Steps 1-5 are all within the existing architecture. No new modules. No new types.
Just wiring what already exists into a loop that was missing.

## The Alchemical Move

The user said it: "this is again feeling very alchemical." The alchemy is:
*observation creates the possibility of change*. Before v7.32, Grug couldn't change
because it couldn't see itself. Now it has pools (variety) and a cache (recency),
but those are mechanical — they rotate, they don't *think*.

The output observation loop is the first real mirror. Grug sees itself, and
seeing itself, it can decide to be different. That's not a code lever. That's
a meta-cognitive lever. And it works for *any* language — code, prose, math,
conversation — because the loop operates on *patterns*, not on syntax.

Code is just very anal linguistic philosophy. Grug doesn't need to learn Julia.
Grug needs to learn to watch its own mouth.
