#!/usr/bin/env python3
"""
Build comprehensive v7.27 test specimen for grugbot.
Extends the v724 specimen with:
- phase_accumulator (time crystal) with pre-seeded snapshots
- More automaton rules covering all 6 ActionFamilies
- Additional nodes that trigger escalations
- MLP observer store with enough entries to activate adjustments
- Rich message history for context intensity testing

v2: Fixed phase_accumulator format (Vector of Dicts, not Dict of Dicts).
    Fixed invalid action names (reflect->ponder, compute->calculate).
    Fixed message IDs (integers, not strings).
"""
import json
import time

BASE = "specimens/comprehensive_v724_v4.specimen.json"
OUTPUT = "specimens/comprehensive_v727_test.specimen.json"

with open(BASE, 'r') as f:
    spec = json.load(f)

# ============================================================
# 1. UPDATE _meta AND version
# ============================================================
spec["_meta"] = {
    "format": "grugbot420-specimen-v2.8",
    "saved_at": time.strftime("%Y-%m-%dT%H:%M:%S"),
    "version": "7.27"
}
spec["version"] = "7.27"

# ============================================================
# 2. ADD PHASE ACCUMULATOR (TIME CRYSTAL)
# ============================================================
# FORMAT: snapshots is a VECTOR of Dicts matching phase_accumulator_from_dict!
# Keys: id, phase_vector (12 floats), trigger_action (Symbol string),
#   rule_id, atp_confidence, timestamp, pull_count, last_pull_time

now = time.time()

spec["phase_accumulator"] = {
    "snapshots": [
        {
            "id": "phase_001",
            "phase_vector": [0.05, 0.55, 0.05, 0.02, 0.25, 0.08,
                             0.02, 0.50, 0.15, 0.03, 0.20, 0.10],
            "trigger_action": "ACTION_QUERY",
            "rule_id": "query_step",
            "atp_confidence": 0.72,
            "timestamp": now - 3600,
            "pull_count": 0,
            "last_pull_time": 0.0
        },
        {
            "id": "phase_002",
            "phase_vector": [0.10, 0.05, 0.10, 0.05, 0.10, 0.60,
                             0.30, 0.05, 0.10, 0.45, 0.05, 0.05],
            "trigger_action": "ACTION_ESCALATE",
            "rule_id": "escalate_emergency",
            "atp_confidence": 0.88,
            "timestamp": now - 1800,
            "pull_count": 0,
            "last_pull_time": 0.0
        },
        {
            "id": "phase_003",
            "phase_vector": [0.55, 0.10, 0.05, 0.10, 0.15, 0.05,
                             0.05, 0.10, 0.55, 0.05, 0.15, 0.10],
            "trigger_action": "ACTION_ASSERT",
            "rule_id": "assert_step",
            "atp_confidence": 0.65,
            "timestamp": now - 900,
            "pull_count": 0,
            "last_pull_time": 0.0
        },
        {
            "id": "phase_004",
            "phase_vector": [0.05, 0.10, 0.55, 0.05, 0.10, 0.15,
                             0.10, 0.05, 0.10, 0.55, 0.10, 0.10],
            "trigger_action": "ACTION_COMMAND",
            "rule_id": "command_step",
            "atp_confidence": 0.70,
            "timestamp": now - 600,
            "pull_count": 0,
            "last_pull_time": 0.0
        },
        {
            "id": "phase_005",
            "phase_vector": [0.10, 0.15, 0.05, 0.10, 0.45, 0.15,
                             0.02, 0.20, 0.10, 0.03, 0.15, 0.50],
            "trigger_action": "ACTION_SPECULATE",
            "rule_id": "speculate_step",
            "atp_confidence": 0.58,
            "timestamp": now - 300,
            "pull_count": 0,
            "last_pull_time": 0.0
        }
    ],
    "pull_threshold": 0.55,
    "surface_count": 3,
    "enabled": True,
    "total_pulls": 0,
    "total_snapshots_recorded": 5
}

# ============================================================
# 3. EXPAND AUTOMATON RULES — cover all 6 ActionFamilies
# ============================================================
spec["automaton_rules"] = [
    {"id": "query_step", "trigger_action": "ACTION_QUERY", "min_confidence": 0.4,
     "jitter_targets": [], "steps": [{"label": "query_pattern", "payload": "question-detected", "op": "literal"}]},
    {"id": "speculate_step", "trigger_action": "ACTION_SPECULATE", "min_confidence": 0.5,
     "jitter_targets": [], "steps": [{"label": "speculate_pattern", "payload": "wonder-detected", "op": "literal"}]},
    {"id": "assert_step", "trigger_action": "ACTION_ASSERT", "min_confidence": 0.35,
     "jitter_targets": [], "steps": [{"label": "assert_pattern", "payload": "fact-asserted", "op": "literal"}]},
    {"id": "command_step", "trigger_action": "ACTION_COMMAND", "min_confidence": 0.45,
     "jitter_targets": [], "steps": [{"label": "command_pattern", "payload": "directive-received", "op": "literal"}]},
    {"id": "negate_step", "trigger_action": "ACTION_NEGATE", "min_confidence": 0.50,
     "jitter_targets": [], "steps": [{"label": "negate_pattern", "payload": "negation-detected", "op": "literal"}]},
    {"id": "escalate_emergency", "trigger_action": "ACTION_ESCALATE", "min_confidence": 0.55,
     "jitter_targets": [], "steps": [{"label": "escalate_pattern", "payload": "emergency-escalation", "op": "literal"}]}
]

# ============================================================
# 4. ADD MORE NODES — escalation-triggers + learning-test nodes
# ============================================================
# All action_packet actions validated against engine whitelist:
# acknowledge, alert, analyze, calculate, caution, clarify, comfort,
# define, describe, elaborate, explain, fight, flag, flee, greet,
# hide, laugh, notify, ponder, reason, reassure, smile, support,
# validate, warn, welcome

new_nodes = [
    # Greeting cluster (SocialLobe)
    {"id": "node_greet_hi", "pattern": "hi", "signal": [0.45], "action_packet": "greet[be warm]^4 | welcome[smile]^2 | smile^1",
     "json_data": {"system_prompt": "Grug wave back happy", "lobe_hint": "SocialLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_greet_hey", "pattern": "hey", "signal": [0.42], "action_packet": "greet[be warm]^4 | welcome[smile]^2 | smile^1",
     "json_data": {"system_prompt": "Grug say hey back", "lobe_hint": "SocialLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_greet_morning", "pattern": "morning", "signal": [0.38], "action_packet": "greet[be warm]^4 | welcome[smile]^2 | smile^1",
     "json_data": {"system_prompt": "Grug say good morning", "lobe_hint": "SocialLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 4.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Question cluster (ReasoningLobe / PhilosophyLobe)
    {"id": "node_q_what", "pattern": "what", "signal": [0.50], "action_packet": "describe[clear,plain]^4 | explain[step by step]^3 | clarify^1",
     "json_data": {"system_prompt": "Grug answer what question carefully", "lobe_hint": "ReasoningLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_q_why", "pattern": "why", "signal": [0.55], "action_packet": "explain[deeply]^4 | reason[carefully]^3 | ponder^1",
     "json_data": {"system_prompt": "Grug think about why things are", "lobe_hint": "PhilosophyLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_q_how", "pattern": "how", "signal": [0.48], "action_packet": "explain[step by step]^5 | describe[clearly]^3 | elaborate^1",
     "json_data": {"system_prompt": "Grug show how thing works", "lobe_hint": "ScienceLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Danger/Emergency cluster (SurvivalLobe) — triggers ESCALATE
    {"id": "node_danger_emergency", "pattern": "emergency", "signal": [0.70], "action_packet": "alert[urgent,loud]^5 | warn[immediate]^4 | notify^2",
     "json_data": {"system_prompt": "Grug sound alarm! Emergency!", "lobe_hint": "SurvivalLobe"},
     "drop_table": [], "throttle": 0.3, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 8.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_danger_help", "pattern": "help", "signal": [0.60], "action_packet": "alert[now]^5 | support[strong]^4 | notify^2",
     "json_data": {"system_prompt": "Grug help! Something wrong!", "lobe_hint": "SurvivalLobe"},
     "drop_table": [], "throttle": 0.3, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 7.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Philosophy cluster (PhilosophyLobe) — triggers SPECULATE
    # FIXED: 'reflect' is not a valid action, replaced with 'ponder'
    {"id": "node_phil_meaning", "pattern": "meaning", "signal": [0.45], "action_packet": "ponder[deeply]^4 | reason[carefully]^3 | analyze^1",
     "json_data": {"system_prompt": "Grug stare at fire. Think about meaning of things.", "lobe_hint": "PhilosophyLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_phil_exist", "pattern": "exist", "signal": [0.42], "action_packet": "ponder[existential]^4 | reason[metaphysical]^3 | analyze[deep]^1",
     "json_data": {"system_prompt": "Grug wonder why things exist at all.", "lobe_hint": "PhilosophyLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 4.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Command cluster (ReasoningLobe) — triggers COMMAND
    {"id": "node_cmd_tell", "pattern": "tell", "signal": [0.50], "action_packet": "describe[clearly]^4 | explain[simply]^3 | elaborate^1",
     "json_data": {"system_prompt": "Grug tell what Grug knows", "lobe_hint": "ReasoningLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_cmd_show", "pattern": "show", "signal": [0.48], "action_packet": "describe[clearly]^4 | elaborate[detailed]^3 | explain^1",
     "json_data": {"system_prompt": "Grug show what Grug means", "lobe_hint": "ReasoningLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Math cluster (MathLobe) — for arithmetic engine testing
    {"id": "node_math_plus", "pattern": "plus", "signal": [0.55], "action_packet": "calculate[show work,dont guess]^5 | reason[step by step]^3 | explain^1",
     "json_data": {"system_prompt": "Grug count carefully. Add numbers step by step.", "lobe_hint": "MathLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 7.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    # FIXED: 'compute' is not a valid action, replaced with 'calculate'
    {"id": "node_math_multiply", "pattern": "multiply", "signal": [0.52], "action_packet": "calculate[show work,dont guess]^5 | reason[carefully]^3 | analyze^1",
     "json_data": {"system_prompt": "Grug multiply. Many times many. Count all.", "lobe_hint": "MathLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Assertion/fact cluster (ScienceLobe) — triggers ASSERT
    {"id": "node_assert_fact", "pattern": "fact", "signal": [0.45], "action_packet": "describe[accurate]^5 | explain[verified]^3 | clarify^1",
     "json_data": {"system_prompt": "Grug state what is true. Fact is fact.", "lobe_hint": "ScienceLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_assert_truth", "pattern": "truth", "signal": [0.40], "action_packet": "describe[honest]^4 | reason[carefully]^3 | ponder^1",
     "json_data": {"system_prompt": "Grug seek truth. Truth important to Grug.", "lobe_hint": "PhilosophyLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Emotion cluster (EmotionLobe) — for emotional response testing
    {"id": "node_emo_sad", "pattern": "sad", "signal": [0.50], "action_packet": "comfort[gently]^5 | support[warm]^3 | reassure^1",
     "json_data": {"system_prompt": "Grug understand sad. Grug pat back.", "lobe_hint": "EmotionLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_emo_afraid", "pattern": "afraid", "signal": [0.55], "action_packet": "comfort[brave]^4 | support[steady]^3 | reassure[safe]^2",
     "json_data": {"system_prompt": "Grug understand fear. Grug hold torch high.", "lobe_hint": "EmotionLobe"},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
]

existing_ids = {n["id"] for n in spec["nodes"]}
for n in new_nodes:
    if n["id"] not in existing_ids:
        spec["nodes"].append(n)

# Update node_to_lobe_idx and node_to_group_idx for new nodes
lobe_map = {
    "SocialLobe": "SocialLobe",
    "ReasoningLobe": "ReasoningLobe",
    "SurvivalLobe": "SurvivalLobe",
    "PhilosophyLobe": "PhilosophyLobe",
    "MathLobe": "MathLobe",
    "ScienceLobe": "ScienceLobe",
    "EmotionLobe": "EmotionLobe"
}
for n in new_nodes:
    hint = n["json_data"].get("lobe_hint", "default")
    lobe_id = lobe_map.get(hint, "default")
    spec["node_to_lobe_idx"][n["id"]] = lobe_id
    if n["id"] not in spec.get("node_to_group_idx", {}):
        spec["node_to_group_idx"][n["id"]] = lobe_id.replace("Lobe", "")

# ============================================================
# 5. REMOVE HOPFIELD CACHE (legacy, commented out of project)
# ============================================================
spec["hopfield_cache"] = []

# ============================================================
# 6. EXPAND MLP OBSERVER STORE — enough to enable adjustments
# ============================================================
spec["mlp_observer_store"] = {
    "key_count": 5,
    "total_entries": 8,
    "entries": {
        "greet": {"observations": 3, "last_novelty": 0.3, "last_quality": 0.7},
        "describe": {"observations": 2, "last_novelty": 0.5, "last_quality": 0.6},
        "explain": {"observations": 1, "last_novelty": 0.4, "last_quality": 0.8},
        "calculate": {"observations": 1, "last_novelty": 0.2, "last_quality": 0.9},
        "alert": {"observations": 1, "last_novelty": 0.6, "last_quality": 0.5}
    }
}

# ============================================================
# 7. FIX MESSAGE HISTORY — use integer IDs
# ============================================================
next_msg_id = spec.get("id_counters", {}).get("msg_id_counter", 100)
messages = []
for i, (text, intensity) in enumerate([
    ("hello grug", 0.7),
    ("what is the meaning of life", 0.8),
    ("tell me about fire", 0.6),
    ("calculate 15 plus 27", 0.9),
    ("why do we exist", 0.75),
    ("EMERGENCY something is wrong", 0.95),
    ("I feel sad today", 0.65),
    ("show me how the eye works", 0.7),
    ("truth is subjective", 0.6),
    ("Grug, are you afraid of the dark?", 0.55),
]):
    messages.append({
        "id": next_msg_id + i,
        "sender": "User",
        "text": text,
        "is_pin": False,
        "intensity": intensity,
        "selected": False
    })
spec["message_history"].extend(messages)

# ============================================================
# 8. UPDATE CHATTER GROUPS — include new nodes
# ============================================================
for group in spec.get("chatter_groups", []):
    if "greet" in group.get("action_hint", "") or "welcome" in group.get("action_hint", ""):
        for nid in ["node_greet_hi", "node_greet_hey", "node_greet_morning"]:
            if nid not in group.get("member_ids", []):
                group.setdefault("member_ids", []).append(nid)
    if "alert" in group.get("action_hint", "") or "warn" in group.get("action_hint", ""):
        for nid in ["node_danger_emergency", "node_danger_help"]:
            if nid not in group.get("member_ids", []):
                group.setdefault("member_ids", []).append(nid)
    if "comfort" in group.get("action_hint", ""):
        for nid in ["node_emo_sad", "node_emo_afraid"]:
            if nid not in group.get("member_ids", []):
                group.setdefault("member_ids", []).append(nid)

# ============================================================
# 9. ENSURE ID COUNTERS ARE HIGH ENOUGH
# ============================================================
spec["id_counters"]["node_id_counter"] = max(spec["id_counters"]["node_id_counter"], 40)
spec["id_counters"]["msg_id_counter"] = max(spec["id_counters"]["msg_id_counter"], 110)

# ============================================================
# WRITE
# ============================================================
with open(OUTPUT, 'w') as f:
    json.dump(spec, f, indent=2)

print(f"\n✅ Comprehensive v7.27 specimen written to {OUTPUT}")
print(f"   Top-level keys: {len(spec)}")
print(f"   Nodes: {len(spec['nodes'])}")
print(f"   Automaton rules: {len(spec['automaton_rules'])}")
print(f"   Phase snapshots: {len(spec['phase_accumulator']['snapshots'])}")
print(f"   Messages: {len(spec['message_history'])}")
