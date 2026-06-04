# GRUG QOL BACKLOG

## 1. Strip Legacy Harnesses
remove "this is the picture" / "here's what i found" type framing scaffolding from responses. grug can use language now. the answer speaks for itself.

## 2. Tonal Emoji Prefix
mood indicator emoji at the start of responses. overall emotional register of the output. could map to :tone applies_at sigil downstream.

## 3. Confidence-Tiered Output
- STAGE 1: answer (top confidence lock-ins, no harness, just says the thing)
- STAGE 2: "also: <X>" (runners-up, lost the floor but respectable confidence)
- STAGE 3: "perhaps: <X>" (low-confidence residue, barely registered but didn't flatline)
- below stage 3: noise, discarded

## 4. Idle Vote-Sweep Auto-Link
- sweep random vote records cross-lobe during idle
- accumulate semantic overlap evidence
- HIGH_CORRELATION_THRESHOLD gate (super high, no weak correlations)
- lazy coinflip ON TOP even if threshold met. base probability ~0.1-0.2, scales modestly with overlap strength
- nothing attaches in a rush. nothing is guaranteed. conservative.
- cross-lobe requirement — same lobe is expected, different lobe overlap is genuine emergent relation

## 5. Pineal — Synchronized Entropy Broadcast
- global non-repeating entropy source
- broadcasts synchronized jitter to ALL stochastic gates simultaneously
- NOT distributed noise — coherent perturbation
- bridge coinflips, idle sweeps, auto-link coinflips all draw from same pulse at same tick
- this is what makes the system act as one entity rather than many parts
- free will = deterministic logic + coherent global jitter
- the synchronization is what turns noise into something that looks like a unified agent choosing
- partially seeds, not fully controls (deterministic logic still does the real work)

## 6. Endocrine Lever — Slow Parameter Modulation
- NOT a new subsystem. just automated tuning of EXISTING tunables
- slow modulation layer that changes how fast systems operate over longer timescales
- "hormones" are gain knobs, not signals — change sensitivity without sending messages
- conditions the system already tracks trigger parameter changes:
    HIGH ACTIVITY  → lower conf threshold, raise coinflip prob, raise sweep freq
    LOW ACTIVITY   → raise conf threshold, lower coinflip prob, raise auto-link conservatism
    HIGH ERROR     → raise conf threshold, lower crystal floor, raise auto-link threshold
    SUSTAINED HI-C → lower crystal floor, raise coinflip prob, lower auto-link threshold
- cascading: one condition → one param change → new state → new condition → next param change
- feeds back into pineal: endocrine changes how SENSITIVE each stochastic gate is to the synchronized jitter
- pineal = when the system CAN choose freely (coherent jitter)
- endocrine = when the system SHOULD choose freely (contextual gain)

## 7. Time Node Sigil Entries — TIME COHERENCE SIGNALING
- READY TO BUILD — simple addition, all sigil registry machinery exists
- time nodes get their own sigil entries that user can extend
- three base entries: :now (present), :before (past), :next (future)
- applies_at = :tone — signals AIML reasoning mode to orchestrator + hippocampal lever
- each entry carries:
    :orientation  => :past/:present/:future
    :vote_flags   => Dict(:reflect, :assess, :project)
    :signal       => [:reflect_past] / [:assess_current] / [:project_future]
- promoter already handles shape-matching and binding
- only new wiring: when time node fires, read vote_flags from binding,
  signal orchestrator and hippocampal lever accordingly
- user adds entries to grow the vocabulary (:lately, :soon, :eventually, etc.)
- "what now?" → promoter matches "now" → &now → present orientation → AIML assesses current state
- hippocampal lever correlates current state with stored context

## 8. Compound Query Routing + Step Coherence Lever
- compound inputs like "what now? also what is 2+2 and what is a dinosaur"
  contain multiple domain fragments in one utterance
- dynamic relationals ("also", "and", "but") act as seam tokens between fragments
- splitter breaks input on seam tokens, each fragment gets its own binding set
- router maps binding signatures to lobes:
    &now / &before / &next  → temporal lobe
    &n &op &n               → arithmetic lobe
    &word / &noun           → knowledge/fact lobe
- step coherence lever = ordered queue of fragments
- each fragment processes independently in its lobe
- results return to coherence lever, reassembled in original order
- not hard: promoter already produces binding signatures, seam tokens already exist
- needs: splitter, router, coherence queue
