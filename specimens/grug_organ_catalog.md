# 🧠 GrugBot420 — Complete Organ Catalog

> *"cave too big. Must make small caves inside big cave."*

## Codebase Vital Signs

| Metric | Value |
|--------|-------|
| **Total Source Files** | 35 Julia modules |
| **Total Lines of Code** | 41,269 |
| **Total Functions** | ~689 |
| **Total Structs** | ~158 |
| **Total Size** | 1.84 MB |

---

## Organ Systems — Grouped by Biological Metaphor

### 🧠 Central Nervous System (Cognition & Routing)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Brain Stem** | `BrainStem.jl` | 333 | 4 | 8 | "BrainStem is cave router. Only ONE cave talks at a time. Others shut up." |
| **Engine** (Cortex) | `engine.jl` | 4,478 | 6 | 73 | Core scanning, voting, node creation, pattern matching engine |
| **Hippocampal Modulator** | `HippocampalModulator.jl` | 436 | 3 | 11 | "old way, votes go straight to AIML. All votes, all at once, good. new way, votes write to a LOG." |
| **Self Observer** (Subconscious) | `SelfObserver.jl` | 975 | 7 | 25 | "cave have loud thoughts (vote, route, rank). Loud thoughts decide. cave ALSO have quiet thoughts in back of head." |
| **Tonal Judge** (Prosody Cortex) | `TonalJudge.jl` | 570 | 3 | 13 | Token-level tonal reading, common-sense mode selection, frame hints |
| **Action-Tone Predictor** | `ActionTonePredictor.jl` | 1,768 | 3 | 22 | Predicts action (ASSERT/QUERY/COMMAND/NEGATE) and tone from raw input |

### 👁️ Sensory Organs (Input Processing & Perception)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Eye System** | `EyeSystem.jl` | 443 | 5 | 6 | Visual attention, peripheral processing, edge blurring |
| **Image SDF** (Visual Cortex) | `ImageSDF.jl` | 786 | 4 | 9 | JIT GPU-accelerated image → nonlinear SDF parameter conversion |
| **Input Queue** (Sensory Gating) | `InputQueue.jl` | 256 | 3 | 13 | "queue is like waiting line at cave. Inputs wait their turn, processed in order." |
| **Input Decomposer** | `InputDecomposer.jl` | 1,185 | 3 | 26 | "when user say one thing, cave scan once, one vote pool, easy. But user say MANY things..." |
| **Sigil Promoter** (Sensory Rewriting) | `SigilPromoter.jl` | 635 | 4 | 10 | "user say 'two plus two', user say '2 + 2', user say '2 plus two'. All same. Promoter make same." |
| **Pattern Scanner** (Retina) | `patternscanner.jl` | 366 | 2 | 7 | Low-level pattern matching and scanning primitives |

### 🗳️ Voting & Democratic Systems (Neural Democracy)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Vote Orchestrator** | `VoteOrchestrator.jl` | 816 | 6 | 19 | "old scan go one rock at time. Too slow. New scan use many hand." |
| **Full Lobe Scanner** | `FullLobeScanner.jl` | 844 | 7 | 32 | "This scan WHOLE lobe. Not just peek. ALL rocks get look. But not all rocks at once! Only 1000 lit up at time." |
| **Multipart Orchestrator** | `MultipartOrchestrator.jl` | 547 | 2 | 13 | "AIML always get many votes. Old way — many rocks, many opinions, no structure." |
| **Relational Jitter** | `RelationalJitter.jl` | 627 | 3 | 12 | "some rocks always land on exact center of target. Too clean! Add tiny shake to rock right before it lands." |

### 🧬 Memory & Knowledge Systems (Hippocampal-Entorhinal Complex)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Lobe** (Cortical Region) | `Lobe.jl` | 550 | 2 | 18 | "cave too big. Must make small caves inside big cave. Each small cave has ONE subject." |
| **Lobe Table** (Hippocampal Index) | `LobeTable.jl` | 636 | 4 | 27 | "flat lists are dumb rock piles. Hash tables are smart rock organizers." |
| **Lobe Orchestrator** | `LobeOrchestrator.jl` | 423 | 1 | 8 | Averages-curve lobe selection (replaces hard mute gate) |
| **AIML Node System** (Episodic Memory) | `AIMLNodeSystem.jl` | 980 | 2 | 28 | "old AIML one giant blob. Bad. Now each lobe gets own AIML tribe. AIML node has own strength. Can get stronger. Can get weaker. Can die." |
| **Thesaurus** | `Thesaurus.jl` | 698 | 2 | 17 | "words is words, but concepts is bigger ideas. This module compare them all." |
| **Sigil Registry** (Lexicon) | `SigilRegistry.jl` | 996 | 8 | 17 | "every smart system have many small word-pictures (verbs, thesaurus, nouns). Sigil is one little name shared by all." |
| **Semantic Verbs** | `SemanticVerbs.jl` | 391 | 0 | 12 | Runtime-mutable verb classes (causal/spatial/temporal) |

### 🦠 Immune System (Anomaly Detection & Defense)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Immune System** | `ImmuneSystem.jl` | 897 | 3 | 19 | Automata-based anomaly handling, quarantine, AST scanning |
| **Immune Thread Pool** | `ImmuneThreadPool.jl` | 1,691 | 17 | 42 | 8 dedicated side threads for immune system processing — load balancer, rate limiter, tripwire monitor, token bucket |

### 🔄 Cellular Lifecycle (Growth, Death & Maintenance)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Mitosis Mode** (Cell Division) | `MitosisMode.jl` | 926 | 2 | 18 | Lazy fuzzy conservative autocatalytic node growth |
| **Phagy Mode** (Apoptosis/Autophagy) | `PhagyMode.jl` | 2,873 | 2 | 30 | Idle-time automata maintenance system (cell death/cleanup) |
| **Chatter Mode** (Synaptic Pruning) | `ChatterMode.jl` | 1,019 | 5 | 22 | Idle-time vote-swap gossip between nodes |

### ⚡ Transient Cognition (Short-Term Processing)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Ephemeral MLP** (Working Memory) | `EphemeralMLP.jl` | 2,122 | 11 | 44 | "vote list is like river. Rocks fall in river, river carries rocks. Sigmoid for familiar, ReLU for novel." |
| **Ephemeral Automaton** (Executive Loop) | `EphemeralAutomaton.jl` | 1,870 | 10 | 45 | "most rocks just react. Question come in, rock match pattern, rock fire. NOT this. This is MULTI-STEP thinking." |

### 🧮 Computation (Prefrontal Cortex — Symbolic Reasoning)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Arithmetic Engine** | `ArithmeticEngine.jl` | 439 | 3 | 11 | "sigils are MACROS. When user say 'what is 2+2', promoter rewrite to sigil, this module bridge sigil capture to spoken answer." |

### 🎭 Output Assembly (Motor Cortex — Speech Production)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Main** (AIML Output Scaffolding) | `Main.jl` | 9,115 | 2 | 39 | The AIML output scaffolding pipeline — frame skeletons, claim connectors, voice registers, conversational reply assembly |

### 🎲 Stochastic Utilities (Neural Noise)

| Organ | Module | Lines | Structs | Functions | GRUG Say |
|-------|--------|------:|--------:|----------:|----------|
| **Coin Flip Helper** | `stochastichelper.jl` | 168 | 2 | 6 | Stochastic coinflip utilities — biased coin, weighted random selection |

---

## Flat Summary — All 35 Modules by Size

| # | Module | Lines | Functions | Structs | Biological Organ |
|---|--------|------:|----------:|--------:|------------------|
| 1 | `Main.jl` | 9,115 | 39 | 2 | Motor Cortex (Speech Production) |
| 2 | `engine.jl` | 4,478 | 73 | 6 | Cerebral Cortex (Core Cognition) |
| 3 | `PhagyMode.jl` | 2,873 | 30 | 2 | Apoptosis / Autophagy (Cell Death) |
| 4 | `EphemeralMLP.jl` | 2,122 | 44 | 11 | Working Memory (Transient Neural Net) |
| 5 | `EphemeralAutomaton.jl` | 1,870 | 45 | 10 | Executive Loop (Multi-Step Reasoning) |
| 6 | `ImmuneThreadPool.jl` | 1,691 | 42 | 17 | White Blood Cell Fleet (8 Thread Immune Pool) |
| 7 | `ActionTonePredictor.jl` | 1,768 | 22 | 3 | Premotor Cortex (Action/Tone Prediction) |
| 8 | `InputDecomposer.jl` | 1,185 | 26 | 3 | Auditory Cortex (Compound Query Splitting) |
| 9 | `ChatterMode.jl` | 1,019 | 22 | 5 | Synaptic Pruning (Idle Gossip) |
| 10 | `SigilRegistry.jl` | 996 | 17 | 8 | Lexicon (Unified Symbol Registry) |
| 11 | `SelfObserver.jl` | 975 | 25 | 7 | Subconscious (Fuzzy Temporal Recall) |
| 12 | `AIMLNodeSystem.jl` | 980 | 28 | 2 | Episodic Memory (Per-Lobe AIML Tribes) |
| 13 | `MitosisMode.jl` | 926 | 18 | 2 | Cell Division (Autocatalytic Node Growth) |
| 14 | `ImmuneSystem.jl` | 897 | 19 | 3 | Adaptive Immune System (Anomaly Defense) |
| 15 | `FullLobeScanner.jl` | 844 | 32 | 7 | Thalamus (Whole-Lobe Sensory Relay) |
| 16 | `VoteOrchestrator.jl` | 816 | 19 | 6 | Basal Ganglia (Parallel Vote Casting) |
| 17 | `ImageSDF.jl` | 786 | 9 | 4 | V1/V2 Visual Cortex (SDF Processing) |
| 18 | `Thesaurus.jl` | 698 | 17 | 2 | Semantic Memory (Concept Comparison) |
| 19 | `LobeTable.jl` | 636 | 27 | 4 | Hippocampal Index (Chunked Hash Storage) |
| 20 | `SigilPromoter.jl` | 635 | 10 | 4 | Sensory Rewriting (Canonicalization) |
| 21 | `RelationalJitter.jl` | 627 | 12 | 3 | Neural Noise (Score Perturbation) |
| 22 | `Lobe.jl` | 550 | 18 | 2 | Cortical Column (Subject Partition) |
| 23 | `MultipartOrchestrator.jl` | 547 | 13 | 2 | Association Cortex (Vote Coalescing) |
| 24 | `TonalJudge.jl` | 570 | 13 | 3 | Prosody Cortex (Tone Reading) |
| 25 | `SemanticVerbs.jl` | 391 | 12 | 0 | Broca's Area (Verb Classification) |
| 26 | `BrainStem.jl` | 333 | 8 | 4 | Brain Stem (Winner-Take-All Dispatch) |
| 27 | `patternscanner.jl` | 366 | 7 | 2 | Retina (Low-Level Pattern Matching) |
| 28 | `HippocampalModulator.jl` | 436 | 11 | 3 | Hippocampus (Action Log & Planning) |
| 29 | `LobeOrchestrator.jl` | 423 | 8 | 1 | Thalamic Relay (Lobe Selection) |
| 30 | `ArithmeticEngine.jl` | 439 | 11 | 3 | Prefrontal Cortex (Symbolic Reasoning) |
| 31 | `EyeSystem.jl` | 443 | 6 | 5 | Superior Colliculus (Visual Attention) |
| 32 | `InputQueue.jl` | 256 | 13 | 3 | Sensory Gating (Input Queue + Inhibition) |
| 33 | `GrugBot420.jl` | 410 | 0 | 0 | Top-Level Module Shell |
| 34 | `stochastichelper.jl` | 168 | 6 | 2 | Neural Noise Generator (Coin Flip) |
| 35 | `CoinFlipHeader.jl` | *(included above)* | — | — | *(same as stochastichelper)* |

---

## The Full Neuromorphic Map — System Interactions

```
                    ┌─────────────────────────────────────────┐
                    │           GRUGBOT420 ORGANISM            │
                    └─────────────────────────────────────────┘

  INPUT ──► InputQueue ──► SigilPromoter ──► InputDecomposer
              │                                    │
              │  NegativeThesaurus                 │  Compound split
              │  (inhibition gate)                 │
              ▼                                    ▼
         ImmuneSystem ──► ImmuneThreadPool         │
         (anomaly scan)   (8 side threads)         │
              │                                    │
              ▼                                    ▼
         BrainStem ◄── LobeOrchestrator ◄── Lobe (subject caves)
         (dispatch)    (lobe selection)       │
              │                               ├── LobeTable (hash index)
              │                               └── AIMLNodeSystem (episodic tribes)
              ▼
         VoteOrchestrator ──► FullLobeScanner
         (parallel vote)      (1000-node scan cap)
              │                    │
              ├── RelationalJitter (score perturbation)
              │
              ▼
         HippocampalModulator (action log, vote scoping)
              │
              ├── EphemeralMLP (working memory: sigmoid/ReLU)
              │       └── EphemeralAutomaton (multi-step reasoning)
              │
              ├── SelfObserver (subconscious hints)
              │
              ▼
         ActionTonePredictor ──► TonalJudge
         (ASSERT/QUERY/etc.)    (prosody + frame hints)
              │
              ▼
         MultipartOrchestrator (vote coalescing)
              │
              ▼
         Main.jl — AIML Output Scaffolding Pipeline
         (frame skeletons → claim → support → connectors → voice register)
              │
              ▼
         OUTPUT ◄── ArithmeticEngine (if sigil-triggered)

  ─── BACKGROUND ORGANS (idle-time) ───

         PhagyMode ──► (autophagy: prune dead/weak nodes)
         MitosisMode ──► (cell division: grow new nodes)
         ChatterMode ──► (synaptic gossip: vote-swap between nodes)

  ─── VISUAL PIPELINE ───

         EyeSystem ──► ImageSDF ──► (GPU SDF params)

  ─── SHARED INFRASTRUCTURE ───

         SigilRegistry (unified symbol lookup)
         Thesaurus (concept similarity)
         SemanticVerbs (causal/spatial/temporal classes)
         stochastichelper (biased coin flips)
         engine.jl (core Node, Vote, pattern matching)
```

---

## GRUG Say — Greatest Hits

The codebase is written in Grug's own voice. Here are the best one-liners:

- *"BrainStem is cave router. Only ONE cave talks at a time. Others shut up."*
- *"cave too big. Must make small caves inside big cave."*
- *"old AIML one giant blob. Bad. Now each lobe gets own AIML tribe."*
- *"flat lists are dumb rock piles. Hash tables are smart rock organizers."*
- *"old scan go one rock at time. Too slow. New scan use many hand."*
- *"some rocks always land on exact center of target. Too clean! Add tiny shake to rock right before it lands."*
- *"vote list is like river. Rocks fall in river, river carries rocks downstream."*
- *"most rocks just react. Question come in, rock match pattern, rock fire. NOT this. This is MULTI-STEP thinking."*
- *"cave have loud thoughts (vote, route, rank). Loud thoughts decide. cave ALSO have quiet thoughts in back of head."*
- *"user say 'two plus two', user say '2 + 2', user say '2 plus two'. All same. Promoter make same."*
- *"This scan WHOLE lobe. Not just peek. ALL rocks get look. But not all rocks at once! Only 1000 lit up at time."*
- *"when user say one thing, cave scan once, one vote pool, easy. But user say MANY things..."*
- *"words is words, but concepts is bigger ideas. This module compare them all."*
- *"every smart system have many small word-pictures (verbs, thesaurus, nouns). Sigil is one little name shared by all."*
- *"dead node is memory of failure, not bloat. Cap is for living."*
- *"NO SILENT FAILURES. If invariant broken, scream loud."*

---

*Catalog generated from GrugBot420 source at commit 566195d (v7.34 decoherence fix).*
*41,269 lines. 35 modules. 689 functions. 158 structs. One very determined caveman.*
