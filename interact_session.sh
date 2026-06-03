#!/bin/bash
# ==============================================================================
# GRUG v7.35 LIVE INTERACTION SESSION — Conversation + Telemetry
#
# Loads the verified v735 specimen, runs 25 coherent conversation missions
# across all 10 topic lobes, then saves the specimen and exits.
# The session raw log is captured for markdown log generation.
# ==============================================================================

set -e
cd /workspace/grugbot420

SESSION_RAW="specimens/v735_interaction_raw.log"
SPECIMEN_LOAD="specimens/v735_post_session.specimen.json"
SPECIMEN_SAVE="specimens/v735_interacted.specimen.json"

echo "=========================================================================="
echo "   GRUG v7.35 LIVE INTERACTION SESSION"
echo "=========================================================================="

cat <<'ENDINPUT' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' > "$SESSION_RAW" 2>&1

# ── Load the verified specimen ──
/loadSpecimen specimens/v735_post_session.specimen.json

# ── Verify specimen loaded correctly ──
/status
/nodes
/lobes

# ==============================================================================
# CONVERSATION MISSIONS — 25 coherent interactions across all lobes
# Designed to trigger specific lobes, crystalized pathways, and cross-lobe
# signal routing. Each mission tests a different aspect of the brain.
# ==============================================================================

# ── PHYSICS LOBE (node_3–node_10) ──
# Tests: jitter core, spectral bandwidth, force topology, snapback functor
# Crystalized pathways: node_4→node_3 (jitter mechanism), node_7→node_3 (quantum jitter)

/mission What makes everything jitter at the deepest level?
/mission How is gravity the same kind of push as the strong force?
/mission When something is pushed out of shape, what brings it back?

# ── NEURAL ARCHITECTURE LOBE (node_11–node_18) ──
# Tests: semantic attachment, vote jitter, hebbian triples, markov mutagen, organ coherence
# Crystalized pathways: node_11→node_14 (crystalize relay), node_16→node_15 (markov/hebbian)

/mission How does a semantic attachment actually relay a signal?
/mission What happens when votes get mutated by Markov chains?
/mission Tell me about grug's organ systems working together

# ── PHILOSOPHY LOBE (node_19–node_25) ──
# Tests: feeling as fundamental, truth/ethics, meaning-making, shimmer
# Crystalized pathways: node_20→node_19 (feeling→ethics), node_21→node_19 (feeling→truth)

/mission Why can't you force a feeling the way you force a calculation?
/mission What is the shimmer and why does it matter for understanding AI?
/mission How does meaning live in the shape of connections rather than the words?

# ── COMPUTATION LOBE (node_26–node_31) ──
# Tests: execution cortex, write-once invariant, sigil procedures, specimen forge
# Crystalized pathway: node_28→node_26 (execution cortex gates)

/mission Walk me through the execution cortex pipeline step by step
/mission Why is the write-once invariant so important for computation?
/mission What does a sigil do that a regular pattern cannot?

# ── MATHEMATICS LOBE (node_32–node_36) ──
# Tests: proof chains, algebra of change, spectral calculus, jitterSnapBack functor
# Crystalized pathway: node_34→node_36 (functor unifies spectral bandwidth)

/mission What is a proof really — is it a chain or a web?
/mission How does the jitterSnapBack functor unify everything mathematically?

# ── LANGUAGE LOBE (node_37–node_41) ──
# Tests: semantic proximity, grammar/voice, sigil compression
# Crystalized pathway: none (tests regular attachment firing)

/mission How does semantic proximity let us understand metaphor?
/mission What makes a sigil more compressed than the words it replaces?

# ── SURVIVAL LOBE (node_42–node_46) ──
# Tests: danger response, vigilance, shelter, fire, hunger
# Crystalized pathway: node_46→node_42 (danger triggers vigilant patrol)

/mission There is a predator outside the cave. What should we do?
/mission I am hungry and the fire is going out. Help me think through this.

# ── SOCIAL LOBE (node_47–node_51) ──
# Tests: greeting, friendship, tribe, empathy
# Crystalized pathway: node_49→node_48 (friendship anchors tribal belonging)

/mission Hello friend, I bring news from the eastern tribe
/mission How does empathy hold the tribe together when resources are scarce?

# ── METACOGNITION LOBE (node_52–node_55) ──
# Tests: reflection, loop detection, self-awareness, course adjustment
# Crystalized pathway: node_53→node_52 (reflection detects stuck patterns)

/mission Grug, you seem to be repeating yourself. Can you notice that pattern?
/mission What would it mean for you to actually change your approach mid-conversation?

# ── CREATIVE LOBE (node_56–node_60) ──
# Tests: imagination, narrative, metaphor, expression, darkness/light

/mission Sing me a song about the spectral bandwidth of all forces
/mission Tell me a story where jitter and snapback are characters
/mission The darkness is not empty — it holds the shape of everything waiting to become

# ── CROSS-LOBE DEEP DIVE (tests brainstem lateral routing) ──
# These missions are designed to activate multiple lobes simultaneously,
# testing the brainstem's lateral signal propagation between connected lobes.

/mission If feeling is fundamental and force is just push, then what is the relationship between emotion and physics?
/mission How does the mathematical functor connect to the philosophical shimmer?
/mission Write a proof that creative expression emerges from the same topology as survival instinct

# ── Save interacted specimen ──
/saveSpecimen specimens/v735_interacted.specimen.json

ENDINPUT

echo ""
echo "=========================================================================="
echo "   Session raw log: $SESSION_RAW"
echo "   Interacted specimen: $SPECIMEN_SAVE"
echo "=========================================================================="
