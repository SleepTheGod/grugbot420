# GrugBot420 Comprehensive Test Log — v81 Specimen
_Generated: 2026-06-11 19:38:40_

Specimen: `/workspace/grugbot420/comprehensive_specimen_v81.json`
Baseline alive: 138 | Final alive: 138 | Delta: 0
## 1. Arithmetic Engine
- `what is 2+2` → 4: ✅ | 15.91s
- `what is 3 plus 4` → 7: ✅ | 0.68s
- `what is 10 minus 3` → 7: ✅ | 0.19s
- `what is 5 times 6` → 30: ✅ | 0.22s

## 2. AutoGrowth + AutoLinker
Before: alive=138
AutoGrowth: === AUTOGROWTH STATUS ===
  evidence_floor=2.0, frequency_floor=3
  evidence_scale=8.0, coinflip_cap=0.25
  decay_halflife=3600.0s, decay_interval=60.0s
  evidence_cap=500, population_cap=10000
  ── v10 MLP head thresholds ──
  semantic_gap<0.35, relevance_dropout<0.3
  disambiguation_pressure>0.65, coherence_drop<-0.15
  ── v10 Curiosity accumulator ──
  overflow_threshold=0.85, cooldown=300.0s
  pending_evidence=6 entries
  top candidates:
    'what times' type=match intensity=0.45 freq=1 lobe=default sources=[strain]
    'what minus' type=match intensity=0.36 freq=1 lobe=MathLobe sources=[strain]
    'what plus' type=match intensity=0.29 freq=1 lobe=MathLobe sources=[strain]
    '2+2' type=match intensity=0.27 freq=2 lobe=default sources=[hash_rarity,silence_map]
    'sigil:n' type=sigil intensity=0.19 freq=1 lobe=default sources=[sigil_gap]
  co_occurrence_pairs=0
  curiosity: intensity=0.369 buffer=1 overflows=0
  (no autogrowth events yet)
AutoLinker: ╔══════════════════════════════════════════════════╗
║          AUTOLINKER — Evidence Status            ║
╠══════════════════════════════════════════════════╣
║  evidence_records=4999
║  cross_lobe_pairs=4239
║  above_floor=3455 (eligible for coinflip)
║  total_auto_links=1
║
║  CONSTANTS:
║    evidence_floor=3.0 (cross-lobe)
║    same_lobe_floor=5.0
║    frequency_floor=4
║    coinflip_cap=20.0%
║    cross_lobe_bonus=1.5x
║    same_lobe_penalty=0.5x
║    decay_half_life=7200.0s
║    disambiguation_bridge_thresh=0.6
║    relevance_cross_lobe_thresh=0.45
║    chatter_residual_increment=0.6
║    disambiguation_bridge_increment=0.4
║    relevance_cross_lobe_increment=0.5
║
║  TOP CANDIDATES:
║    [XLOBE] node_28 ↔ node_76 | intensity=64.0 freq=32
║    [XLOBE] node_26 ↔ node_76 | intensity=56.0 freq=28
║    [XLOBE] node_26 ↔ node_68 | intensity=56.0 freq=28
║    [XLOBE] node_26 ↔ node_28 | intensity=56.0 freq=28
║    [XLOBE] node_101 ↔ node_28 | intensity=48.0 freq=24
║
║  RECENT LINKS:
║    [XLOBE✓] node_28 ↔ node_68 | p=0.2 source=opposing_lobe_co_act
╚══════════════════════════════════════════════════╝
After: alive=138 (delta=0)
AutoGrowth: === AUTOGROWTH STATUS ===
  evidence_floor=2.0, frequency_floor=3
  evidence_scale=8.0, coinflip_cap=0.25
  decay_halflife=3600.0s, decay_interval=60.0s
  evidence_cap=500, population_cap=10000
  ── v10 MLP head thresholds ──
  semantic_gap<0.35, relevance_dropout<0.3
  disambiguation_pressure>0.65, coherence_drop<-0.15
  ── v10 Curiosity accumulator ──
  overflow_threshold=0.85, cooldown=300.0s
  pending_evidence=12 entries
  top candidates:
    'photosynthesis' type=match intensity=1.05 freq=2 lobe=default sources=[hash_rarity,silence_map]
    'physics' type=match intensity=0.84 freq=2 lobe=default sources=[hash_rarity,silence_map]
    'quantum' type=match intensity=0.84 freq=2 lobe=default sources=[hash_rarity,silence_map]
    'tell' type=match intensity=0.84 freq=2 lobe=default sources=[hash_rarity,silence_map]
    'sigil:n' type=sigil intensity=0.55 freq=3 lobe=default sources=[sigil_gap]
  co_occurrence_pairs=3
  curiosity: intensity=0.728 buffer=5 overflows=0
  (no autogrowth events yet)
AutoLinker: ╔══════════════════════════════════════════════════╗
║          AUTOLINKER — Evidence Status            ║
╠══════════════════════════════════════════════════╣
║  evidence_records=5000
║  cross_lobe_pairs=4653
║  above_floor=2808 (eligible for coinflip)
║  total_auto_links=1
║
║  CONSTANTS:
║    evidence_floor=3.0 (cross-lobe)
║    same_lobe_floor=5.0
║    frequency_floor=4
║    coinflip_cap=20.0%
║    cross_lobe_bonus=1.5x
║    same_lobe_penalty=0.5x
║    decay_half_life=7200.0s
║    disambiguation_bridge_thresh=0.6
║    relevance_cross_lobe_thresh=0.45
║    chatter_residual_increment=0.6
║    disambiguation_bridge_increment=0.4
║    relevance_cross_lobe_increment=0.5
║
║  TOP CANDIDATES:
║    [XLOBE] node_28 ↔ node_76 | intensity=68.0 freq=34
║    [XLOBE] node_26 ↔ node_68 | intensity=64.0 freq=32
║    [XLOBE] node_26 ↔ node_28 | intensity=64.0 freq=32
║    [XLOBE] node_101 ↔ node_28 | intensity=56.0 freq=28
║    [XLOBE] node_28 ↔ node_83 | intensity=56.0 freq=28
║
║  RECENT LINKS:
║    [XLOBE✓] node_28 ↔ node_68 | p=0.2 source=opposing_lobe_co_act
╚══════════════════════════════════════════════════╝

## 3. Hippocampal Ask/Answer
- `what is fire and why does it burn`: ✅ | 0.41s
- `tell me about water and what is 3 plus 5`: ✅ | 0.34s

## 4. Flashcards (PettyLearner)
Pre math flashcards: 0
Post math flashcards: 0 (delta=0)
PettyLearner: === PETTY LEARNER STATUS ===
  max_uncovered_tokens: 1
  similarity_floor:     0.7
  min_token_length:     3
  max_arith_ops:        2
  paths: :thesaurus, :flashcard, :lobe_whitelist


## 5. Thesaurus Expansion
- synonym_lookup(fire,flame): 0.95
- word_similarity(rock,stone): 0.0
- word_similarity(happy,sad): 0.0

## 6. Language-Side Resource (SemanticVerbs)
- verb_class_of('is'): spatial
- verb_class_of('causes'): causal
- verb_class_of('contains'): nothing
- verb_class_of('belongs to'): nothing
- add_relation_class!: ✅

## 7. Mitosis Growth
```
Mitosis: no events yet. Cave has not grown on its own.
```

## 8. Phagy (Node Cleanup)
- phagy_log_rotate: ERR:MethodError(Main.GrugBot420.PhagyMode.phagy_log_rotate!, (), 0x000000000000bd0c)
- Alive nodes: 138

## 9. Immune System
- ledger_entries: 0
- coinflip_probability: 0.5
- automata_ratio: 1//3
- event_counts: Dict{Symbol, Int64}()
- hopfield_signatures: 0
- maturity_threshold: 1000
- quarantine_depth: 0

## 10. Multipart Coherence
- `what is 2+2 also what is a cat`: ✅ | 0.25s | excerpt: Thinking it through: Grug studied define. It follows the hidden rules of the world. Grug watch and study. From another angle: Define is something grug can observe and realize. Grug watch, grug test, g
- `what is fire and why does it burn`: ✅ | 0.3s | excerpt: Here is the picture:  Alongside this: hunger causes are bound by invisible chain. One thing pushes, another thing moves. Grug learned to trace the chain back to its start. — Grug knows feeling is neve
- `tell me about water and what is 5 plus 3`: ✅ | 0.17s | excerpt: Here is the picture: 5 plus 3 equals 8 —  Another node chimes in: summer autumn are linked by the river of when. Time moves like water, always forward, never backward. Grug remember what was, grug exa
