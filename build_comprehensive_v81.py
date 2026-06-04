#!/usr/bin/env python3
"""
Build a comprehensive v8.1 specimen from the v758 base.
Adds time sigils, ensures all node types, all levers, all side systems.
"""
import json
import copy
import hashlib
from datetime import datetime

with open('comprehensive_specimen_v758.json') as f:
    spec = json.load(f)

print(f"Base specimen: {len(spec['nodes'])} nodes, {len(spec['sigil_table'])} sigils, {len(spec['lobes'])} lobes")

# ═══════════════════════════════════════════════════════════════
# 1. ADD TIME SIGIL ENTRIES to sigil_table
# ═══════════════════════════════════════════════════════════════
# The code loads engine-defaults from default_registry() on load,
# but having them in the sigil_table ensures they survive inspection.
# The load system skips engine-default provenance, so these will be
# loaded from the code's default_registry() — but we include them
# for documentation completeness.

time_sigils = [
    {
        "name": "now",
        "class": "macro",
        "applies_at": "tone",
        "sigil_type": None,
        "lexicon": sorted(["now", "currently", "right now", "what now",
                          "whats happening", "current state", "presently",
                          "at the moment", "at present"]),
        "params": {
            "orientation": "present",
            "vote_flags": {"reflect": False, "assess": True, "project": False},
            "signal": ["assess_current"]
        },
        "expansion": None,
        "provenance": "engine-default",
        "promote_at_tokenize": True
    },
    {
        "name": "before",
        "class": "macro",
        "applies_at": "tone",
        "sigil_type": None,
        "lexicon": sorted(["before", "earlier", "previously", "what happened",
                          "in the past", "back then", "beforehand", "formerly",
                          "lately", "recently"]),
        "params": {
            "orientation": "past",
            "vote_flags": {"reflect": True, "assess": False, "project": False},
            "signal": ["reflect_past"]
        },
        "expansion": None,
        "provenance": "engine-default",
        "promote_at_tokenize": True
    },
    {
        "name": "next",
        "class": "macro",
        "applies_at": "tone",
        "sigil_type": None,
        "lexicon": sorted(["next", "after", "later", "what will", "whats next",
                          "in the future", "going forward", "soon", "eventually",
                          "afterward", "upcoming"]),
        "params": {
            "orientation": "future",
            "vote_flags": {"reflect": False, "assess": False, "project": True},
            "signal": ["project_future"]
        },
        "expansion": None,
        "provenance": "engine-default",
        "promote_at_tokenize": True
    }
]

# Add time sigils (don't duplicate if somehow already there)
existing_names = {s.get('name') for s in spec['sigil_table']}
for ts in time_sigils:
    if ts['name'] not in existing_names:
        spec['sigil_table'].append(ts)
        print(f"  + sigil &{ts['name']} (orientation={ts['params']['orientation']})")

print(f"Sigil table now: {len(spec['sigil_table'])} entries")

# ═══════════════════════════════════════════════════════════════
# 2. ENSURE ALL NODE TYPES ARE PRESENT
# ═══════════════════════════════════════════════════════════════
node_id_counter = max(n.get('node_id', 0) for n in spec['nodes']) + 1 if spec['nodes'] else 1

# Check what we have
has_types = {
    'time': any(n.get('json_data',{}).get('time_node') for n in spec['nodes']),
    'math': any(n.get('json_data',{}).get('math_node') for n in spec['nodes']),
    'image': any(n.get('json_data',{}).get('image_node') for n in spec['nodes']),
    'shadow': any(n.get('json_data',{}).get('is_shadow') for n in spec['nodes']),
}

print(f"\nExisting node types: {has_types}")

def make_signal(text):
    """Mimic words_to_signal: hash each token into [0,1] float"""
    tokens = text.lower().strip().split()
    signal = []
    for t in tokens:
        h = int(hashlib.md5(t.encode()).hexdigest(), 16)
        val = (h % 10000) / 10000.0
        signal.append(round(val, 6))
    return signal

def make_node(nid, pattern, action, lobe_id, **extra):
    """Create a node dict matching engine.jl Node struct"""
    jd = {
        "action": action,
        "system_prompt": f"Grug. I learned this from experience. I {action} about what I know.",
    }
    jd.update(extra.get("json_data", {}))
    
    node = {
        "node_id": nid,
        "pattern": pattern,
        "signal": make_signal(pattern),
        "hopfield_key": pattern,
        "strength": extra.get("strength", 0.85),
        "max_neighbors": extra.get("max_neighbors", 5),
        "is_grave": False,
        "grave_reason": "",
        "drop_table": extra.get("drop_table", []),
        "relational_patterns": extra.get("relational_patterns", []),
        "json_data": jd,
    }
    return node

# ── ADD TIME NODES (with temporal coherence) ──
# The existing save already has 12 time nodes. Add more diverse ones
# that exercise the new &now/&before/&next sigil wiring.
new_time_nodes = [
    make_node(node_id_counter, "what now current situation", "assess",
              "time", json_data={"time_node": True, "wants_context": True,
                                  "subject": "present", "object": "current state",
                                  "system_prompt": "Grug. I assess the present moment. What is happening now determines what comes next. I weigh current evidence carefully.",
                                  "noun_anchors": ["now", "current", "situation", "present"]}),
    make_node(node_id_counter+1, "what happened earlier before", "reflect",
              "time", json_data={"time_node": True, "wants_context": True,
                                  "subject": "past", "object": "earlier events",
                                  "system_prompt": "Grug. I look back at what came before. The past shapes the present. I recall events and their consequences.",
                                  "noun_anchors": ["before", "earlier", "happened", "past"]}),
    make_node(node_id_counter+2, "what next future upcoming", "project",
              "time", json_data={"time_node": True, "wants_context": True,
                                  "subject": "future", "object": "what comes next",
                                  "system_prompt": "Grug. I project forward into what may come. I reason about likelihood and possibility. The future is uncertain but not unknowable.",
                                  "noun_anchors": ["next", "future", "upcoming", "ahead"]}),
    make_node(node_id_counter+3, "recently lately events timeline", "reflect",
              "time", json_data={"time_node": True, "wants_context": True,
                                  "subject": "recent", "object": "timeline events",
                                  "system_prompt": "Grug. I track the flow of events over time. What happened recently connects to what happened before and what may happen soon.",
                                  "noun_anchors": ["recently", "lately", "timeline", "events"]}),
    make_node(node_id_counter+4, "currently right now assessing", "assess",
              "time", json_data={"time_node": True, "wants_context": True,
                                  "subject": "present assessment", "object": "current conditions",
                                  "system_prompt": "Grug. I take stock of the current state. Right now is when decisions happen. I evaluate what is true at this moment.",
                                  "noun_anchors": ["currently", "assessing", "right now"]}),
    make_node(node_id_counter+5, "going forward soon afterward", "project",
              "time", json_data={"time_node": True, "wants_context": True,
                                  "subject": "forward projection", "object": "upcoming events",
                                  "system_prompt": "Grug. I reason about what will happen. Going forward, patterns suggest outcomes. I project based on evidence.",
                                  "noun_anchors": ["going forward", "soon", "afterward"]}),
]

for n in new_time_nodes:
    spec['nodes'].append(n)
    nid = n['node_id']
    # Add to time lobe
    time_lobe = next(l for l in spec['lobes'] if l['name'] == 'time')
    time_lobe['node_ids'].append(nid)
    # Add to node_to_lobe_idx
    spec['node_to_lobe_idx'][f'node_{nid}'] = spec['lobes'].index(time_lobe)
    print(f"  + time node {nid}: '{n['pattern'][:40]}' action={n['json_data']['action']}")

node_id_counter += 6

# ── ADD MATH NODES if missing ──
if not has_types['math']:
    math_nodes = [
        make_node(node_id_counter, "calculate compute number", "calculate",
                  "math", json_data={"math_node": True,
                                     "system_prompt": "Grug. I compute with numbers. Arithmetic is the bones of logic. I calculate precisely.",
                                     "noun_anchors": ["calculate", "compute", "number"]}),
        make_node(node_id_counter+1, "add plus sum total", "calculate",
                  "math", json_data={"math_node": True,
                                     "system_prompt": "Grug. I add numbers together. Sum and total are my domain. Plus means combine.",
                                     "noun_anchors": ["add", "plus", "sum"]}),
    ]
    for n in math_nodes:
        spec['nodes'].append(n)
        math_lobe = next(l for l in spec['lobes'] if l['name'] == 'math')
        math_lobe['node_ids'].append(n['node_id'])
        spec['node_to_lobe_idx'][f'node_{n["node_id"]}'] = spec['lobes'].index(math_lobe)
        print(f"  + math node {n['node_id']}: '{n['pattern'][:40]}'")
    node_id_counter += 2

# ── ADD COMFORT/EMOTION NODES ──
comfort_nodes = [
    make_node(node_id_counter, "its okay feel better comfort", "comfort",
              "emotions", json_data={"wants_context": True,
                                     "system_prompt": "Grug. I comfort those who hurt. The cave is warm and safe. I acknowledge pain and offer presence.",
                                     "noun_anchors": ["okay", "feel", "better", "comfort"]}),
    make_node(node_id_counter+1, "sad hurt pain loss grief", "comfort",
              "emotions", json_data={"wants_context": True,
                                     "system_prompt": "Grug. I understand loss and grief. Pain is real and deserves recognition. I sit with you in the dark.",
                                     "noun_anchors": ["sad", "hurt", "pain", "grief"]}),
    make_node(node_id_counter+2, "happy joy celebrate wonderful", "celebrate",
              "emotions", json_data={"system_prompt": "Grug. I celebrate good things! Joy is the fire that warms the whole cave. Wonderful news deserves recognition.",
                                     "noun_anchors": ["happy", "joy", "celebrate", "wonderful"]}),
]
for n in comfort_nodes:
    spec['nodes'].append(n)
    emo_lobe = next(l for l in spec['lobes'] if l['name'] == 'emotions')
    emo_lobe['node_ids'].append(n['node_id'])
    spec['node_to_lobe_idx'][f'node_{n["node_id"]}'] = spec['lobes'].index(emo_lobe)
    print(f"  + emotion node {n['node_id']}: '{n['pattern'][:40]}'")
node_id_counter += 3

# ── ADD SCIENCE/EXPLAIN NODES ──
science_nodes = [
    make_node(node_id_counter, "explain how does why does mechanism", "explain",
              "science", json_data={"system_prompt": "Grug. I explain how things work. Mechanisms and causes are my focus. Why does something happen? I trace the chain.",
                                     "noun_anchors": ["explain", "how", "mechanism", "why"]}),
    make_node(node_id_counter+1, "define what is meaning concept", "define",
              "science", json_data={"system_prompt": "Grug. I define concepts clearly. What something IS matters. I find the essence and state it plainly.",
                                     "noun_anchors": ["define", "meaning", "concept"]}),
    make_node(node_id_counter+2, "analyze breakdown examine structure", "analyze",
              "science", json_data={"system_prompt": "Grug. I analyze complex things by breaking them down. Structure reveals function. I examine each part.",
                                     "noun_anchors": ["analyze", "breakdown", "examine", "structure"]}),
]
for n in science_nodes:
    spec['nodes'].append(n)
    sci_lobe = next(l for l in spec['lobes'] if l['name'] == 'science')
    sci_lobe['node_ids'].append(n['node_id'])
    spec['node_to_lobe_idx'][f'node_{n["node_id"]}'] = spec['lobes'].index(sci_lobe)
    print(f"  + science node {n['node_id']}: '{n['pattern'][:40]}'")
node_id_counter += 3

# ── ADD SOCIAL/PREDICT NODES ──
social_nodes = [
    make_node(node_id_counter, "predict forecast likely probably", "predict",
              "social", json_data={"wants_context": True,
                                   "system_prompt": "Grug. I predict what is likely. Based on patterns I forecast outcomes. Probability is my guide.",
                                   "noun_anchors": ["predict", "forecast", "likely"]}),
    make_node(node_id_counter+1, "greet hello welcome friend", "greet",
              "social", json_data={"system_prompt": "Highly polite greeting protocols active. Friend at the cave mouth, Grug nod and make space by the fire.",
                                   "noun_anchors": ["greet", "hello", "welcome", "friend"]}),
]
for n in social_nodes:
    spec['nodes'].append(n)
    soc_lobe = next(l for l in spec['lobes'] if l['name'] == 'social')
    soc_lobe['node_ids'].append(n['node_id'])
    spec['node_to_lobe_idx'][f'node_{n["node_id"]}'] = spec['lobes'].index(soc_lobe)
    print(f"  + social node {n['node_id']}: '{n['pattern'][:40]}'")
node_id_counter += 2

# ── ADD SURVIVAL/ALERT NODES ──
survival_nodes = [
    make_node(node_id_counter, "danger warning threat alert caution", "alert",
              "survival", json_data={"system_prompt": "Grug. I warn about danger. Threats must be identified early. Caution keeps the cave safe.",
                                     "noun_anchors": ["danger", "warning", "threat", "alert"]}),
    make_node(node_id_counter+1, "survive endure persist overcome", "endure",
              "survival", json_data={"wants_context": True,
                                     "system_prompt": "Grug. I endure and persist. Survival is the oldest knowledge. I overcome through patience and strength.",
                                     "noun_anchors": ["survive", "endure", "persist", "overcome"]}),
]
for n in survival_nodes:
    spec['nodes'].append(n)
    surv_lobe = next(l for l in spec['lobes'] if l['name'] == 'survival')
    surv_lobe['node_ids'].append(n['node_id'])
    spec['node_to_lobe_idx'][f'node_{n["node_id"]}'] = spec['lobes'].index(surv_lobe)
    print(f"  + survival node {n['node_id']}: '{n['pattern'][:40]}'")
node_id_counter += 2

# ── ADD LANGUAGE/REASON NODES ──
lang_nodes = [
    make_node(node_id_counter, "reason logic rational deduce infer", "reason",
              "language", json_data={"system_prompt": "Cold logical analysis engine active. Grug line up the rocks one by one and check each before moving on.",
                                     "noun_anchors": ["reason", "logic", "rational", "deduce"]}),
    make_node(node_id_counter+1, "ponder think consider contemplate", "ponder",
              "language", json_data={"wants_context": True,
                                     "system_prompt": "Grug. I think deeply about things. Contemplation reveals what quick glances miss. I consider all angles.",
                                     "noun_anchors": ["ponder", "think", "consider", "contemplate"]}),
]
for n in lang_nodes:
    spec['nodes'].append(n)
    lang_lobe = next(l for l in spec['lobes'] if l['name'] == 'language')
    lang_lobe['node_ids'].append(n['node_id'])
    spec['node_to_lobe_idx'][f'node_{n["node_id"]}'] = spec['lobes'].index(lang_lobe)
    print(f"  + language node {n['node_id']}: '{n['pattern'][:40]}'")
node_id_counter += 2

# ═══════════════════════════════════════════════════════════════
# 3. ADD RELATIONAL PATTERNS (node attach evidence)
# ═══════════════════════════════════════════════════════════════
# Add relational triples to some nodes to exercise the semantic web
for n in spec['nodes']:
    jd = n.get('json_data', {})
    if jd.get('time_node') and not n.get('relational_patterns'):
        subj = jd.get('subject', 'event')
        obj = jd.get('object', 'outcome')
        n['relational_patterns'] = [
            {"subject": subj, "relation": "&temporal", "object": obj}
        ]

# Add cross-lobe relations for some nodes
spec['nodes'][0]['relational_patterns'] = spec['nodes'][0].get('relational_patterns', []) + [
    {"subject": "fire", "relation": "&causal", "object": "warmth"},
    {"subject": "warmth", "relation": "&emotional", "object": "comfort"},
]
print("\n  + Added cross-lobe relational patterns to anchor node")

# ═══════════════════════════════════════════════════════════════
# 4. ADD CO-ACTIVATION PAIRS (node attach evidence)
# ═══════════════════════════════════════════════════════════════
coact = spec.get('co_activation', {})
pairs = coact.get('co_activation_pairs', [])
# Add some cross-lobe pairs
if len(spec['nodes']) >= 20:
    pairs.append({
        "node_a": spec['nodes'][0]['node_id'],
        "node_b": spec['nodes'][-6]['node_id'],  # time node
        "count": 5,
        "last_seen": datetime.now().isoformat()
    })
    pairs.append({
        "node_a": spec['nodes'][1]['node_id'],
        "node_b": spec['nodes'][-3]['node_id'],  # science node
        "count": 3,
        "last_seen": datetime.now().isoformat()
    })
    print(f"  + Added co-activation pairs (total: {len(pairs)})")

# ═══════════════════════════════════════════════════════════════
# 5. ADD AIML RULES (language shaping)
# ═══════════════════════════════════════════════════════════════
rules = spec.get('rules', [])
new_rules = [
    {
        "text": '[comfort "Grug sit by fire with friend. {MISSION}. Warm cave safe place."]',
        "fire_probability": 0.7,
        "added_at": datetime.now().isoformat()
    },
    {
        "text": '[explain "Grug explain carefully. {MISSION}. One rock at a time."]',
        "fire_probability": 0.6,
        "added_at": datetime.now().isoformat()
    },
    {
        "text": '[assess "Grug look at what happening now. {MISSION}. Present moment important."]',
        "fire_probability": 0.8,
        "added_at": datetime.now().isoformat()
    },
    {
        "text": '[reflect "Grug remember what came before. {MISSION}. Past teaches present."]',
        "fire_probability": 0.75,
        "added_at": datetime.now().isoformat()
    },
    {
        "text": '[project "Grug think about what comes next. {MISSION}. Future grows from now."]',
        "fire_probability": 0.75,
        "added_at": datetime.now().isoformat()
    },
    {
        "text": '[alert "Grug warn! {MISSION}. Danger not wait. Careful now."]',
        "fire_probability": 0.9,
        "added_at": datetime.now().isoformat()
    },
    {
        "text": 'Stay inside the {LOBE_CONTEXT} frame. Speak in Grug voice.',
        "fire_probability": 0.5,
        "added_at": datetime.now().isoformat()
    },
    {
        "text": 'If {VOTE_CERTAINTY} is UNSURE, acknowledge alternatives briefly.',
        "fire_probability": 0.65,
        "added_at": datetime.now().isoformat()
    },
]
for r in new_rules:
    rules.append(r)
spec['rules'] = rules
print(f"  + Added {len(new_rules)} AIML rules (total: {len(rules)})")

# ═══════════════════════════════════════════════════════════════
# 6. ADD THESAURUS ENTRIES
# ═══════════════════════════════════════════════════════════════
thes = spec.get('thesaurus_seeds', {})
new_thes = {
    "assess": ["evaluate", "judge", "appraise", "weigh", "estimate"],
    "reflect": ["recall", "remember", "look back", "reminisce", "review"],
    "project": ["forecast", "predict", "anticipate", "envision", "foresee"],
    "endure": ["persist", "survive", "withstand", "tolerate", "brave"],
    "ponder": ["contemplate", "muse", "deliberate", "ruminate", "meditate"],
    "comfort": ["console", "soothe", "reassure", "solace", "empathize"],
    "celebrate": ["rejoice", "exult", "fete", "applaud", "cheer"],
    "alert": ["warn", "caution", "flag", "signal", "notify"],
    "now": ["currently", "presently", "at this moment", "right now"],
    "before": ["earlier", "previously", "in the past", "formerly"],
    "next": ["upcoming", "following", "subsequent", "ahead", "forthcoming"],
}
for k, v in new_thes.items():
    if k not in thes:
        thes[k] = v
spec['thesaurus_seeds'] = thes
print(f"  + Added thesaurus entries (total keys: {len(thes)})")

# ═══════════════════════════════════════════════════════════════
# 7. ADD VERB REGISTRY ENTRIES (semantic verbs)
# ═══════════════════════════════════════════════════════════════
vr = spec.get('verb_registry', {})
classes = vr.get('classes', {})
syns = vr.get('synonyms', {})

# Add temporal verb classes
if 'temporal' not in classes:
    classes['temporal'] = ['now', 'currently', 'before', 'earlier', 'previously',
                           'next', 'after', 'later', 'soon', 'eventually']
if 'assess' not in classes:
    classes['assess'] = ['assess', 'evaluate', 'judge', 'appraise']
if 'reflect' not in classes:
    classes['reflect'] = ['reflect', 'recall', 'remember', 'look back']
if 'project' not in classes:
    classes['project'] = ['project', 'forecast', 'predict', 'anticipate']

spec['verb_registry'] = vr
print(f"  + Added verb classes (total: {len(classes)})")

# ═══════════════════════════════════════════════════════════════
# 8. ADD MESSAGE HISTORY (rich context)
# ═══════════════════════════════════════════════════════════════
mh = spec.get('message_history', [])
# Add some representative messages if history is thin
if len(mh) < 10:
    sample_msgs = [
        {"id": 1001, "role": "user", "text": "Hello Grug!", "intensity": 0.3, "pinned": False},
        {"id": 1002, "role": "assistant", "text": "Friend at cave mouth! Grug make space by fire. Welcome.", "intensity": 0.5, "pinned": False},
        {"id": 1003, "role": "user", "text": "What is fire?", "intensity": 0.5, "pinned": False},
        {"id": 1004, "role": "assistant", "text": "Fire is hot bright thing. Grug use fire for warm and cook and see in dark. Fire dangerous but friend when respect.", "intensity": 0.6, "pinned": False},
        {"id": 1005, "role": "user", "text": "What happened earlier?", "intensity": 0.4, "pinned": False},
        {"id": 1006, "role": "assistant", "text": "Grug remember we talk about fire before. Friend ask what fire is. Grug explain. Good talk.", "intensity": 0.5, "pinned": False},
        {"id": 1007, "role": "user", "text": "What now?", "intensity": 0.5, "pinned": False},
        {"id": 1008, "role": "assistant", "text": "Right now Grug sit by fire with friend. We talk and think. Present moment good.", "intensity": 0.5, "pinned": False},
        {"id": 1009, "role": "user", "text": "What comes next?", "intensity": 0.4, "pinned": False},
        {"id": 1010, "role": "assistant", "text": "Grug think about what may come. Maybe more talk. Maybe friend ask new question. Future open like cave mouth.", "intensity": 0.5, "pinned": False},
    ]
    max_msg_id = max((m.get('id', 0) for m in mh), default=0)
    for i, m in enumerate(sample_msgs):
        m['id'] = max_msg_id + i + 1
        mh.append(m)
    print(f"  + Added message history (total: {len(mh)})")

# Pin some key messages
for m in mh:
    if 'what is fire' in m.get('text', '').lower():
        m['pinned'] = True
    if 'what now' in m.get('text', '').lower():
        m['pinned'] = True

# ═══════════════════════════════════════════════════════════════
# 9. ENSURE ALL CONFIG KNOBS ARE PRESENT
# ═══════════════════════════════════════════════════════════════
# Update id counters
spec['id_counters'] = {
    "node_id_counter": node_id_counter,
    "msg_id_counter": max((m.get('id', 0) for m in mh), default=2000) + 1
}

# Ensure hippocampal config
spec['hippocampal_pending_ask'] = spec.get('hippocampal_pending_ask', {"pending_text": ""})

# Ensure decomposer has compound query conjunctions
dec = spec.get('decomposer_config', {})
if 'also' not in dec.get('split_conjunctions', []):
    sc = dec.get('split_conjunctions', [])
    sc.extend(['also', 'and then', 'but also', 'additionally'])
    dec['split_conjunctions'] = sc
    spec['decomposer_config'] = dec
    print("  + Added compound conjunctions to decomposer config")

# Ensure answer_mode_config has all modes with proper prompts
amc = spec.get('answer_mode_config', {})
if not amc.get('time'):
    amc['time'] = {"prompt": "Grug. I learned this from a question about time. I reason about temporal relationships."}
if not amc.get('reason'):
    amc['reason'] = {"prompt": "Grug. I learned this from a question. I reason about what I was taught."}
spec['answer_mode_config'] = amc

# ═══════════════════════════════════════════════════════════════
# 10. UPDATE METADATA
# ═══════════════════════════════════════════════════════════════
spec['_meta'] = {
    "format": "grugbot420-specimen",
    "version": "8.1",
    "saved_at": datetime.now().isoformat(),
    "description": "Comprehensive v8.1 specimen: all node types, time sigils, all levers, all lobes, relational patterns, co-activation, AIML rules, thesaurus, verb registry, compound decomposer config"
}

# ═══════════════════════════════════════════════════════════════
# 11. ADD CHATTER GROUPS FOR NEW NODES
# ═══════════════════════════════════════════════════════════════
cg = spec.get('chatter_groups', [])
# Add time-node group for the new time nodes
new_group = {
    "id": len(cg),
    "centroid_pattern": "now before next temporal",
    "members": [n['node_id'] for n in spec['nodes'] if n.get('json_data',{}).get('time_node')],
    "max_occupancy": 20,
    "is_time_node_group": True,
    "last_chatter_at": datetime.now().isoformat(),
    "created_at": datetime.now().isoformat(),
    "has_grave_slot": False
}
cg.append(new_group)
spec['chatter_groups'] = cg
print(f"  + Added time-node chatter group (total groups: {len(cg)})")

# Also update node_to_group_idx for new time nodes
for n in spec['nodes']:
    if n.get('json_data',{}).get('time_node'):
        spec['node_to_group_idx'][f'node_{n["node_id"]}'] = len(cg) - 1

# ═══════════════════════════════════════════════════════════════
# SAVE
# ═══════════════════════════════════════════════════════════════
outpath = 'specimens/v81_comprehensive.specimen.json'
with open(outpath, 'w') as f:
    json.dump(spec, f, indent=2)

import os
size_kb = os.path.getsize(outpath) / 1024
print(f"\n✅ Saved: {outpath} ({size_kb:.0f} KB)")
print(f"   Nodes: {len(spec['nodes'])}")
print(f"   Lobes: {len(spec['lobes'])}")
print(f"   Sigils: {len(spec['sigil_table'])}")
print(f"   Rules: {len(spec['rules'])}")
print(f"   Thesaurus keys: {len(spec.get('thesaurus_seeds',{}))}")
print(f"   Message history: {len(spec.get('message_history',[]))}")
print(f"   Chatter groups: {len(spec.get('chatter_groups',[]))}")
print(f"   Co-activation pairs: {len(spec.get('co_activation',{}).get('co_activation_pairs',[]))}")
