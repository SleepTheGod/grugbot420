#!/usr/bin/env python3
"""
Build comprehensive v7.27 test specimen for grugbot.
Extends the v724 specimen with:
- phase_accumulator (time crystal) with pre-seeded snapshots
- More automaton rules covering all 6 ActionFamilies
- Additional nodes that trigger escalations
- MLP observer store with enough entries to activate adjustments
- Rich message history for context intensity testing

v3: DECOHERENCE FIXES
  1. All 36 nodes now have voice_register, frame_hints, noun_anchors
  2. All nodes have multi-sentence system_prompt (voice_body requirement)
  3. Multi-token patterns converted to single-token primary with
     alternates moved to drop_table (BUG-004 elimination)
  4. Message format fixed: sender→role, is_pin→pinned, removed selected
  5. Fixed invalid action names, message IDs (from v2)
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
# 4. FIX EXISTING NODES — decoherence elimination
# ============================================================
# DECOHERENCE FIX 1: Convert multi-token patterns to single-token primary
# Move alternates to drop_table (BUG-004 elimination)
# DECOHERENCE FIX 2: Add voice_register, frame_hints, noun_anchors
# DECOHERENCE FIX 3: Ensure multi-sentence system_prompt (voice_body)

# Mapping of node IDs to their coherence config
COHERENCE_MAP = {
    # --- Original boot-seed nodes (from v724 base) ---
    "node_0": {
        "pattern": "hello",
        "drop_table_add": ["hi", "greeting", "mornin"],
        "voice_register": "friendly",
        "frame_hints": ["warm", "plain"],
        "noun_anchors": ["friend", "greeting"],
        "system_prompt": "Grug speak plain. Grug say hello back with warm heart."
    },
    "node_1": {
        "pattern": "think",
        "drop_table_add": ["ponder", "reason", "calculate"],
        "voice_register": "thoughtful",
        "frame_hints": ["contemplative", "plain"],
        "noun_anchors": ["thought", "reason"],
        "system_prompt": "Grug think careful. Grug line up the rocks one by one and check each before moving on."
    },
    "node_2": {
        "pattern": "fire",
        "drop_table_add": ["rock", "hit", "makes"],
        "voice_register": "explanatory",
        "frame_hints": ["exploratory", "plain"],
        "noun_anchors": ["fire", "rock"],
        "system_prompt": "Grug tell about fire. Grug hits rock and makes fire, that how Grug learn the world."
    },
    "node_3": {
        "pattern": "hello",
        "drop_table_add": ["hi", "hey", "howdy", "greet", "friend", "warm", "welcome"],
        "voice_register": "friendly",
        "frame_hints": ["warm", "de-escalating"],
        "noun_anchors": ["friend", "tribe"],
        "system_prompt": "Grug greet friend. Grug welcome you to the cave with open arms."
    },
    "node_4": {
        "pattern": "goodbye",
        "drop_table_add": ["bye", "farewell", "seeyou", "later"],
        "voice_register": "friendly",
        "frame_hints": ["warm", "de-escalating"],
        "noun_anchors": ["friend"],
        "system_prompt": "Grug say goodbye. Friend go but Grug remember. Come back soon."
    },
    "node_5": {
        "pattern": "add",
        "drop_table_add": ["plus", "sum", "total"],
        "voice_register": "precise",
        "frame_hints": ["plain", "terse"],
        "noun_anchors": ["number", "sum"],
        "system_prompt": "Grug count careful. Grug add rocks one by one, no skip, get the right total."
    },
    "node_6": {
        "pattern": "multiply",
        "drop_table_add": ["double", "triple", "times"],
        "voice_register": "precise",
        "frame_hints": ["plain", "terse"],
        "noun_anchors": ["number", "factor"],
        "system_prompt": "Grug multiply. Many times many is more rocks. Grug count all careful."
    },
    "node_7": {
        "pattern": "calculate",
        "drop_table_add": ["compute", "number"],
        "voice_register": "precise",
        "frame_hints": ["plain", "terse"],
        "noun_anchors": ["number"],
        "system_prompt": "Grug count careful. Answer come from MathLobe with certainty SURE."
    },
    "node_8": {
        "pattern": "describe",
        "drop_table_add": ["explain", "what", "warm"],
        "voice_register": "explanatory",
        "frame_hints": ["exploratory", "plain"],
        "noun_anchors": ["fire", "heat", "light"],
        "system_prompt": "Grug paint picture with words. Truth show up plain so anyone see it."
    },
    "node_9": {
        "pattern": "observe",
        "drop_table_add": ["measure", "data", "hypothesis"],
        "voice_register": "observational",
        "frame_hints": ["exploratory", "plain"],
        "noun_anchors": ["data", "pattern"],
        "system_prompt": "Grug watch close. Grug see pattern in the rocks and the stars."
    },
    "node_10": {
        "pattern": "explain",
        "drop_table_add": [],
        "voice_register": "explanatory",
        "frame_hints": ["exploratory", "plain"],
        "noun_anchors": ["fire", "heat"],
        "system_prompt": "Grug explain what Grug know. Heat come from wood breaking apart fast, that why fire warm."
    },
    "node_11": {
        "pattern": "reason",
        "drop_table_add": ["analyze", "infer", "because", "therefore"],
        "voice_register": "thoughtful",
        "frame_hints": ["contemplative", "plain"],
        "noun_anchors": ["thought", "reason"],
        "system_prompt": "Grug reason careful. Each thought lean on the one before it like rocks in a wall."
    },
    "node_12": {
        "pattern": "meaning",
        "drop_table_add": ["why", "purpose", "exist", "wonder", "truth", "life"],
        "voice_register": "thoughtful",
        "frame_hints": ["contemplative", "exploratory"],
        "noun_anchors": ["meaning", "purpose", "truth"],
        "system_prompt": "Grug stare at fire. Big questions never get small answers, but Grug still ask them."
    },
    "node_13": {
        "pattern": "sad",
        "drop_table_add": ["cry", "hurt", "alone", "afraid", "lonely", "worried", "scared", "worry"],
        "voice_register": "gentle",
        "frame_hints": ["warm", "de-escalating"],
        "noun_anchors": ["feeling", "friend"],
        "system_prompt": "Grug understand pain. Grug sit with you by the fire until the hurt passes."
    },
    "node_14": {
        "pattern": "happy",
        "drop_table_add": ["joy", "laugh", "excited", "love", "smile", "glad"],
        "voice_register": "warm",
        "frame_hints": ["warm"],
        "noun_anchors": ["joy", "smile"],
        "system_prompt": "Grug share joy. Good thing better when more than one rock around the fire."
    },
    "node_15": {
        "pattern": "worry",
        "drop_table_add": ["concern", "anxious", "nervous", "fear", "cold", "winter"],
        "voice_register": "gentle",
        "frame_hints": ["warm", "de-escalating"],
        "noun_anchors": ["worry", "winter", "cold"],
        "system_prompt": "Grug understand worry. Grug hold torch high so you see the path ahead."
    },
    "node_16": {
        "pattern": "danger",
        "drop_table_add": ["threat", "enemy", "attack", "warning", "beware", "cold", "winter", "storm"],
        "voice_register": "urgent",
        "frame_hints": ["imperative", "terse"],
        "noun_anchors": ["danger", "threat"],
        "system_prompt": "Grug see threat. Warn loud. Raise spear now before it too late."
    },
    "node_17": {
        "pattern": "run",
        "drop_table_add": ["flee", "escape", "hide", "safe", "shelter", "cave"],
        "voice_register": "urgent",
        "frame_hints": ["imperative", "terse"],
        "noun_anchors": ["safe", "shelter"],
        "system_prompt": "Grug seek safety fast. Cave first, count tribe second, plan after the danger pass."
    },
}

# Apply coherence fixes to existing nodes
for node in spec["nodes"]:
    nid = node["id"]
    # DECOHERENCE FIX 5: Remove stale signal array so engine regenerates
    # it from the (now single-token) pattern on load. Old multi-token
    # signal arrays cause BUG-004 even after pattern is shortened.
    if "signal" in node:
        del node["signal"]
    if nid in COHERENCE_MAP:
        cfg = COHERENCE_MAP[nid]
        # Fix pattern: single-token primary
        node["pattern"] = cfg["pattern"]
        # Add drop_table entries from pattern alternates
        existing_drop = node.get("drop_table", [])
        if isinstance(existing_drop, list):
            for dt in cfg["drop_table_add"]:
                if dt not in existing_drop:
                    existing_drop.append(dt)
        else:
            node["drop_table"] = cfg["drop_table_add"]
        # Add coherence fields
        jd = node.get("json_data", {})
        jd["voice_register"] = cfg["voice_register"]
        jd["frame_hints"] = cfg["frame_hints"]
        jd["noun_anchors"] = cfg["noun_anchors"]
        # Ensure multi-sentence system_prompt
        jd["system_prompt"] = cfg["system_prompt"]
        node["json_data"] = jd

# ============================================================
# 5. ADD MORE NODES — with full coherence fields from the start
# ============================================================
new_nodes = [
    # Greeting cluster (SocialLobe)
    {"id": "node_greet_hi", "pattern": "hi", "action_packet": "greet[be warm]^4 | welcome[smile]^2 | smile^1",
     "json_data": {"system_prompt": "Grug wave back. Grug say hi to friend with happy heart.", "lobe_hint": "SocialLobe",
                   "voice_register": "friendly", "frame_hints": ["warm", "plain"], "noun_anchors": ["friend", "greeting"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_greet_hey", "pattern": "hey", "action_packet": "greet[be warm]^4 | welcome[smile]^2 | smile^1",
     "json_data": {"system_prompt": "Grug say hey back. Grug hear you and Grug glad you here.", "lobe_hint": "SocialLobe",
                   "voice_register": "friendly", "frame_hints": ["warm", "plain"], "noun_anchors": ["friend", "greeting"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_greet_morning", "pattern": "morning", "action_packet": "greet[be warm]^4 | welcome[smile]^2 | smile^1",
     "json_data": {"system_prompt": "Grug say good morning. Sun rise and Grug greet new day with friend.", "lobe_hint": "SocialLobe",
                   "voice_register": "friendly", "frame_hints": ["warm", "plain"], "noun_anchors": ["morning", "sun"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 4.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Question cluster (ReasoningLobe / PhilosophyLobe)
    {"id": "node_q_what", "pattern": "what", "action_packet": "describe[clear,plain]^4 | explain[step by step]^3 | clarify^1",
     "json_data": {"system_prompt": "Grug answer what question. Grug think careful then speak what Grug know.", "lobe_hint": "ReasoningLobe",
                   "voice_register": "explanatory", "frame_hints": ["exploratory", "plain"], "noun_anchors": ["question", "answer"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_q_why", "pattern": "why", "action_packet": "explain[deeply]^4 | reason[carefully]^3 | ponder^1",
     "json_data": {"system_prompt": "Grug think about why things are. Grug ask the deep question by the fire.", "lobe_hint": "PhilosophyLobe",
                   "voice_register": "thoughtful", "frame_hints": ["contemplative", "exploratory"], "noun_anchors": ["why", "reason"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_q_how", "pattern": "how", "action_packet": "explain[step by step]^5 | describe[clearly]^3 | elaborate^1",
     "json_data": {"system_prompt": "Grug show how thing works. Grug take apart and put back together step by step.", "lobe_hint": "ScienceLobe",
                   "voice_register": "explanatory", "frame_hints": ["exploratory", "plain"], "noun_anchors": ["method", "step"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Danger/Emergency cluster (SurvivalLobe) — triggers ESCALATE
    {"id": "node_danger_emergency", "pattern": "emergency", "action_packet": "alert[urgent,loud]^5 | warn[immediate]^4 | notify^2",
     "json_data": {"system_prompt": "Grug sound alarm! Emergency mean danger now. Grug protect tribe first.", "lobe_hint": "SurvivalLobe",
                   "voice_register": "urgent", "frame_hints": ["imperative", "terse"], "noun_anchors": ["emergency", "danger"]},
     "drop_table": [], "throttle": 0.3, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 8.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_danger_help", "pattern": "help", "action_packet": "alert[now]^5 | support[strong]^4 | notify^2",
     "json_data": {"system_prompt": "Grug help now! Something wrong. Grug come fast with torch and club.", "lobe_hint": "SurvivalLobe",
                   "voice_register": "urgent", "frame_hints": ["imperative", "terse"], "noun_anchors": ["help", "danger"]},
     "drop_table": [], "throttle": 0.3, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 7.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Philosophy cluster (PhilosophyLobe) — triggers SPECULATE
    {"id": "node_phil_meaning", "pattern": "meaning", "action_packet": "ponder[deeply]^4 | reason[carefully]^3 | analyze^1",
     "json_data": {"system_prompt": "Grug stare at fire. Think about meaning of things. Big question make Grug wonder.", "lobe_hint": "PhilosophyLobe",
                   "voice_register": "thoughtful", "frame_hints": ["contemplative", "exploratory"], "noun_anchors": ["meaning", "purpose"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_phil_exist", "pattern": "exist", "action_packet": "ponder[existential]^4 | reason[metaphysical]^3 | analyze[deep]^1",
     "json_data": {"system_prompt": "Grug wonder why things exist at all. The stars and the cave and Grug all here for some reason.", "lobe_hint": "PhilosophyLobe",
                   "voice_register": "thoughtful", "frame_hints": ["contemplative", "exploratory"], "noun_anchors": ["existence", "wonder"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 4.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Command cluster (ReasoningLobe) — triggers COMMAND
    {"id": "node_cmd_tell", "pattern": "tell", "action_packet": "describe[clearly]^4 | explain[simply]^3 | elaborate^1",
     "json_data": {"system_prompt": "Grug tell what Grug knows. Grug share knowledge plainly so you understand.", "lobe_hint": "ReasoningLobe",
                   "voice_register": "explanatory", "frame_hints": ["exploratory", "plain"], "noun_anchors": ["knowledge", "story"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_cmd_show", "pattern": "show", "action_packet": "describe[clearly]^4 | elaborate[detailed]^3 | explain^1",
     "json_data": {"system_prompt": "Grug show what Grug means. Grug point at the thing and name it so you see too.", "lobe_hint": "ReasoningLobe",
                   "voice_register": "explanatory", "frame_hints": ["exploratory", "plain"], "noun_anchors": ["demonstration", "truth"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Math cluster (MathLobe) — for arithmetic engine testing
    {"id": "node_math_plus", "pattern": "plus", "action_packet": "calculate[show work,dont guess]^5 | reason[step by step]^3 | explain^1",
     "json_data": {"system_prompt": "Grug count carefully. Add numbers step by step. No skip, no guess, get the right answer.", "lobe_hint": "MathLobe",
                   "voice_register": "precise", "frame_hints": ["plain", "terse"], "noun_anchors": ["addition", "number"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 7.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_math_multiply", "pattern": "multiply", "action_packet": "calculate[show work,dont guess]^5 | reason[carefully]^3 | analyze^1",
     "json_data": {"system_prompt": "Grug multiply. Many times many is more rocks. Grug count all careful step by step.", "lobe_hint": "MathLobe",
                   "voice_register": "precise", "frame_hints": ["plain", "terse"], "noun_anchors": ["multiplication", "number"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 6.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Assertion/fact cluster (ScienceLobe) — triggers ASSERT
    {"id": "node_assert_fact", "pattern": "fact", "action_packet": "describe[accurate]^5 | explain[verified]^3 | clarify^1",
     "json_data": {"system_prompt": "Grug state what is true. Fact is fact. Grug not guess, Grug know from seeing.", "lobe_hint": "ScienceLobe",
                   "voice_register": "precise", "frame_hints": ["plain", "terse"], "noun_anchors": ["fact", "truth"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_assert_truth", "pattern": "truth", "action_packet": "describe[honest]^4 | reason[carefully]^3 | ponder^1",
     "json_data": {"system_prompt": "Grug seek truth. Truth important to Grug. Grug not lie, Grug speak what is real.", "lobe_hint": "PhilosophyLobe",
                   "voice_register": "thoughtful", "frame_hints": ["contemplative", "plain"], "noun_anchors": ["truth", "honesty"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.0, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},

    # Emotion cluster (EmotionLobe) — for emotional response testing
    {"id": "node_emo_sad", "pattern": "sad", "action_packet": "comfort[gently]^5 | support[warm]^3 | reassure^1",
     "json_data": {"system_prompt": "Grug understand sad. Grug sit with you by the fire until the hurt passes.", "lobe_hint": "EmotionLobe",
                   "voice_register": "gentle", "frame_hints": ["warm", "de-escalating"], "noun_anchors": ["sadness", "comfort"]},
     "drop_table": [], "throttle": 0.5, "relational_patterns": [], "required_relations": [],
     "relation_weights": {}, "strength": 5.5, "is_image_node": False, "neighbor_ids": [],
     "is_unlinkable": False, "max_neighbors": 12, "is_grave": False, "grave_reason": "",
     "response_times": [], "ledger_last_cleared": 0.0, "hopfield_key": 0,
     "fired_this_cycle": False, "voted_this_cycle": False, "gained_this_cycle": False,
     "strength_delta_this_cycle": 0.0},
    {"id": "node_emo_afraid", "pattern": "afraid", "action_packet": "comfort[brave]^4 | support[steady]^3 | reassure[safe]^2",
     "json_data": {"system_prompt": "Grug understand fear. Grug hold torch high so you see there nothing in the dark to hurt you.", "lobe_hint": "EmotionLobe",
                   "voice_register": "gentle", "frame_hints": ["warm", "de-escalating"], "noun_anchors": ["fear", "safety"]},
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

# Also update lobe records' node_ids to include new nodes
lobe_by_id = {lobe["id"]: lobe for lobe in spec.get("lobes", [])}
for n in new_nodes:
    hint = n["json_data"].get("lobe_hint", "default")
    lobe_id = lobe_map.get(hint, "default")
    if lobe_id in lobe_by_id:
        nids = lobe_by_id[lobe_id].get("node_ids", [])
        if n["id"] not in nids:
            nids.append(n["id"])
            lobe_by_id[lobe_id]["node_ids"] = nids

# ============================================================
# 6. REMOVE HOPFIELD CACHE (legacy, commented out of project)
# ============================================================
spec["hopfield_cache"] = []

# ============================================================
# 7. EXPAND MLP OBSERVER STORE — enough to enable adjustments
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
# 8. FIX MESSAGE HISTORY — use correct format (role, not sender)
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
        "role": "User",           # FIXED: was "sender"
        "text": text,
        "pinned": False,          # FIXED: was "is_pin"
        "intensity": intensity
        # REMOVED: "selected" — not in ChatMessage struct
    })
spec["message_history"].extend(messages)

# ============================================================
# 9. UPDATE CHATTER GROUPS — include new nodes
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
# 10. ENSURE ID COUNTERS ARE HIGH ENOUGH
# ============================================================
spec["id_counters"]["node_id_counter"] = max(spec["id_counters"]["node_id_counter"], 40)
spec["id_counters"]["msg_id_counter"] = max(spec["id_counters"]["msg_id_counter"], 110)

# ============================================================
# 11. STRIP STALE DERIVED FIELDS (signal, hopfield_key)
#     These are computed by the engine from `pattern` on load.
#     Old multi-token values cause BUG-004 false positives.
# ============================================================
for node in spec["nodes"]:
    node.pop("signal", None)
    node.pop("hopfield_key", None)

# ============================================================
# WRITE
# ============================================================
with open(OUTPUT, 'w') as f:
    json.dump(spec, f, indent=2)

# Verification summary
n_nodes = len(spec['nodes'])
n_with_vr = sum(1 for n in spec['nodes'] if n.get('json_data', {}).get('voice_register', ''))
n_with_fh = sum(1 for n in spec['nodes'] if n.get('json_data', {}).get('frame_hints', []))
n_with_na = sum(1 for n in spec['nodes'] if n.get('json_data', {}).get('noun_anchors', []))
n_multi_tok = sum(1 for n in spec['nodes'] if len(n.get('pattern', '').split()) > 1)
n_bad_msgs = sum(1 for m in spec['message_history'] if 'sender' in m)
n_with_signal = sum(1 for n in spec['nodes'] if 'signal' in n)
n_with_hk = sum(1 for n in spec['nodes'] if 'hopfield_key' in n)

print(f"\n✅ Comprehensive v7.27 specimen written to {OUTPUT}")
print(f"   Top-level keys: {len(spec)}")
print(f"   Nodes: {n_nodes}")
print(f"   Nodes with voice_register: {n_with_vr}/{n_nodes}")
print(f"   Nodes with frame_hints: {n_with_fh}/{n_nodes}")
print(f"   Nodes with noun_anchors: {n_with_na}/{n_nodes}")
print(f"   Multi-token patterns: {n_multi_tok} (BUG-004 risk)")
print(f"   Bad message format: {n_bad_msgs} (should be 0)")
print(f"   Nodes with stale signal: {n_with_signal} (should be 0)")
print(f"   Nodes with stale hopfield_key: {n_with_hk} (should be 0)")
print(f"   Automaton rules: {len(spec['automaton_rules'])}")
print(f"   Phase snapshots: {len(spec['phase_accumulator']['snapshots'])}")
print(f"   Messages: {len(spec['message_history'])}")
