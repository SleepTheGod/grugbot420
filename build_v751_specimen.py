#!/usr/bin/env python3
"""Build v751 specimen with cross-lobe overlap nodes for UNSURE/question trigger testing."""
import json, time, copy

BASE = "specimens/v750_comprehensive.specimen.json"
OUT  = "specimens/v751_overlap.specimen.json"

with open(BASE) as f:
    d = json.load(f)

now = time.time()

# ── 1. Cross-lobe overlap nodes (n26–n36) ──────────────────────────────────
# These deliberately share keywords with nodes in OTHER lobes so that
# a single input activates multiple sure_votes from different nodes,
# triggering the UNSURE hedge: "I am not fully locked in — X also on the table."
#
# KEY FIX: Each node now has full json_data with system_prompt, proper
# neighbor_ids, drop_table, and all fields the Node constructor expects.

overlap_nodes = [
    # n26: L1 (math) — "logic reasoning proof truth" overlaps with n28 (L3 philosophy)
    {"id": "n26", "pattern": "logic reasoning proof truth mathematical",
     "strength": 7.0, "action_packet": "reason^5|analyze^3",
     "json_data": {"domain": "mathematical_logic", "lobe_hint": "L1",
                   "system_prompt": "Scholar of mathematical logic. You explore how reasoning and proof create truth in formal systems.",
                   "voice_register": "explanatory", "frame_hints": ["formal", "precise"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n27", "n4"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n27: L1 (math) — "knowledge truth evidence justify" overlaps with n12 (L3 epistemology)
    {"id": "n27", "pattern": "knowledge truth evidence justify certainty",
     "strength": 6.8, "action_packet": "reason^4|analyze^3",
     "json_data": {"domain": "epistemic_mathematics", "lobe_hint": "L1",
                   "system_prompt": "Scholar of mathematical certainty. You examine how evidence and justification produce knowledge.",
                   "voice_register": "explanatory", "frame_hints": ["formal", "precise"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n26", "n1"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n28: L3 (philosophy) — "logic truth valid inference reasoning" overlaps with n26 (L1 math)
    {"id": "n28", "pattern": "logic truth valid inference reasoning philosophical",
     "strength": 7.2, "action_packet": "explain^5|reason^3",
     "json_data": {"domain": "philosophical_logic", "lobe_hint": "L3",
                   "system_prompt": "Philosopher of logic. You reason about valid inference and how truth emerges from philosophical argument.",
                   "voice_register": "explanatory", "frame_hints": ["formal", "elaborate"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n12", "n26"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n29: L2 (language) — "structure rule order pattern system" overlaps with n3 (L1 math/equation)
    {"id": "n29", "pattern": "structure rule order pattern system formal",
     "strength": 6.5, "action_packet": "explain^4|describe^3",
     "json_data": {"domain": "formal_structure", "lobe_hint": "L2",
                   "system_prompt": "Linguist of formal systems. You explain how structure and rules create order in both language and mathematics.",
                   "voice_register": "explanatory", "frame_hints": ["formal", "precise"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n6", "n3"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n30: L2 (language) — "meaning sense interpretation understanding" overlaps with n12 (L3)
    {"id": "n30", "pattern": "meaning sense interpretation understanding semantics",
     "strength": 6.3, "action_packet": "explain^4|clarify^3",
     "json_data": {"domain": "semantics", "lobe_hint": "L2",
                   "system_prompt": "Scholar of meaning. You explore how language creates understanding and interprets sense.",
                   "voice_register": "explanatory", "frame_hints": ["formal", "elaborate"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n7", "n29"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n31: L5 (survival) — "observe detect watch monitor alert" overlaps with n16/n19 (L4 perception)
    {"id": "n31", "pattern": "observe detect watch monitor alert scan",
     "strength": 7.5, "action_packet": "alert^5|caution^3",
     "json_data": {"domain": "threat_detection", "lobe_hint": "L5",
                   "system_prompt": "Survival sentinel. You watch for danger and alert others to threats in the environment.",
                   "voice_register": "terse", "frame_hints": ["imperative", "urgent"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n21", "n32"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n32: L4 (perception) — "danger threat risk hazard warning" overlaps with n21 (L5 survival)
    {"id": "n32", "pattern": "danger threat risk hazard warning perception",
     "strength": 7.3, "action_packet": "reason^4|alert^3",
     "json_data": {"domain": "danger_perception", "lobe_hint": "L4",
                   "system_prompt": "Perceiver of danger. You evaluate threats and assess whether hazards are real or perceived.",
                   "voice_register": "terse", "frame_hints": ["imperative", "cautious"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n19", "n31"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n33: L3 (philosophy) — "beauty aesthetic judgment taste art" overlaps with n14 (L3 aesthetics)
    {"id": "n33", "pattern": "beauty aesthetic judgment taste art sublime",
     "strength": 6.0, "action_packet": "explain^4|describe^2",
     "json_data": {"domain": "aesthetics", "lobe_hint": "L3",
                   "system_prompt": "Aesthetic philosopher. You contemplate beauty and the nature of artistic judgment.",
                   "voice_register": "warm", "frame_hints": ["expressive", "elaborate"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n14", "n28"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n34: L1 (math) — "infinite limit convergence bound" overlaps with n13 (L3 ontology/being)
    {"id": "n34", "pattern": "infinite limit convergence bound finite eternal",
     "strength": 6.2, "action_packet": "reason^4|calculate^3",
     "json_data": {"domain": "limits_convergence", "lobe_hint": "L1",
                   "system_prompt": "Scholar of infinity. You reason about limits, convergence, and the boundary between finite and infinite.",
                   "voice_register": "explanatory", "frame_hints": ["formal", "precise"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n3", "n26"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n35: L5 (survival) — "protect defend guard secure shield" overlaps with n22 (L5 shelter)
    {"id": "n35", "pattern": "protect guard secure shield fortify defense",
     "strength": 7.0, "action_packet": "fight^4|hide^3",
     "json_data": {"domain": "protection", "lobe_hint": "L5",
                   "system_prompt": "Guardian of safety. You protect and shield others from harm through vigilance and fortification.",
                   "voice_register": "terse", "frame_hints": ["imperative", "cautious"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n22", "n31"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
    # n36: L4 (perception) — "light bright illuminate see dark" overlaps with n16 (L4 vision)
    {"id": "n36", "pattern": "light bright illuminate see dark shadow luminance",
     "strength": 6.8, "action_packet": "reason^4|describe^3",
     "json_data": {"domain": "luminance_perception", "lobe_hint": "L4",
                   "system_prompt": "Perceiver of light. You describe illumination and the interplay of brightness and shadow.",
                   "voice_register": "explanatory", "frame_hints": ["descriptive", "detailed"]},
     "drop_table": [], "required_relations": [], "relational_patterns": [],
     "relation_weights": {}, "throttle": 0.0,
     "is_image_node": False, "is_antimatch_node": False, "is_grave": False,
     "neighbor_ids": ["n16", "n32"], "max_neighbors": 12, "is_unlinkable": False,
     "hopfield_key": 0, "signal": [], "response_times": [], "ledger_last_cleared": 0},
]

for n in overlap_nodes:
    d["nodes"].append(n)

# ── 2. Node-to-lobe assignments for new nodes ──────────────────────────────
lobe_map = {
    "n26": "L1", "n27": "L1", "n34": "L1",           # Math
    "n29": "L2", "n30": "L2",                          # Language
    "n28": "L3", "n33": "L3",                          # Philosophy
    "n31": "L5", "n32": "L4", "n36": "L4",            # Perception/Survival
    "n35": "L5",                                       # Survival
}
d["node_to_lobe_idx"].update(lobe_map)

# ── 2b. Update lobe node_ids to include new nodes ──────────────────────────
for lobe in d["lobes"]:
    lid = lobe["id"]
    new_ids = [nid for nid, l in lobe_map.items() if l == lid]
    existing = lobe.get("node_ids", [])
    lobe["node_ids"] = existing + new_ids

# ── 3. LobeTable entries for new nodes ──────────────────────────────────────
lobe_table_map = {lt_entry["lobe_id"]: lt_entry for lt_entry in d["lobe_tables"]}

for nid, lid in lobe_map.items():
    if lid not in lobe_table_map:
        new_lt = {"lobe_id": lid, "chunks": {"nodes": {}, "drop": {}, "json": {}, "hopfield": {}, "meta": {}}}
        d["lobe_tables"].append(new_lt)
        lobe_table_map[lid] = new_lt
    
    lt_entry = lobe_table_map[lid]
    chunks = lt_entry["chunks"]
    
    chunks["nodes"][nid] = {
        "_type": "NodeRef",
        "node_id": nid,
        "lobe_id": lid,
        "is_active": True,
        "inserted_at": now
    }
    # Also add json chunk for the node's json_data
    node_data = next((n for n in overlap_nodes if n["id"] == nid), None)
    if node_data and "json_data" in node_data:
        chunks["json"][nid] = node_data["json_data"]

# ── 4. AIML nodes for overlap nodes ────────────────────────────────────────
aiml = d["aiml_system"]
reg = aiml.get("registry", {})
for lid in ["L1", "L2", "L3", "L4", "L5"]:
    if lid not in reg:
        reg[lid] = []

# Create AIML node entries for overlap nodes (valid AIMLNode deserialization format)
overlap_aiml_nodes = {
    "L1": [
        {"id": "aiml_L1_logic", "lobe_id": "L1",
         "template": "logical reasoning connects mathematical proof with philosophical truth",
         "fired_count": 0, "voted_count": 0, "gained_count": 0,
         "strength": 5.0, "age": 0, "last_fired": 0.0, "last_voted": 0.0,
         "is_grave": False},
        {"id": "aiml_L1_truth", "lobe_id": "L1",
         "template": "truth in mathematics requires evidence and justification",
         "fired_count": 0, "voted_count": 0, "gained_count": 0,
         "strength": 5.0, "age": 0, "last_fired": 0.0, "last_voted": 0.0,
         "is_grave": False},
    ],
    "L3": [
        {"id": "aiml_L3_logic", "lobe_id": "L3",
         "template": "philosophical logic examines valid inference and reasoning about truth",
         "fired_count": 0, "voted_count": 0, "gained_count": 0,
         "strength": 5.0, "age": 0, "last_fired": 0.0, "last_voted": 0.0,
         "is_grave": False},
        {"id": "aiml_L3_observation", "lobe_id": "L3",
         "template": "observation and perception of danger raises philosophical questions about reality",
         "fired_count": 0, "voted_count": 0, "gained_count": 0,
         "strength": 4.5, "age": 0, "last_fired": 0.0, "last_voted": 0.0,
         "is_grave": False},
    ],
    "L4": [
        {"id": "aiml_L4_danger", "lobe_id": "L4",
         "template": "perceiving danger involves both sensory detection and cognitive evaluation",
         "fired_count": 0, "voted_count": 0, "gained_count": 0,
         "strength": 5.0, "age": 0, "last_fired": 0.0, "last_voted": 0.0,
         "is_grave": False},
    ],
    "L5": [
        {"id": "aiml_L5_observe", "lobe_id": "L5",
         "template": "survival depends on observing and detecting threats in the environment",
         "fired_count": 0, "voted_count": 0, "gained_count": 0,
         "strength": 5.0, "age": 0, "last_fired": 0.0, "last_voted": 0.0,
         "is_grave": False},
    ],
}

for lid, new_nodes in overlap_aiml_nodes.items():
    if lid in reg:
        reg[lid].extend(new_nodes)

aiml["registry"] = reg

# ── 5. New cross-lobe attachments ──────────────────────────────────────────
new_attachments = [
    # n26(L1) ↔ n28(L3) — logic overlap (critical for UNSURE)
    {"target_id": "n26", "node_id": "n28", "pattern": "logic truth reasoning proof",
     "signal": [], "base_confidence": 0.75},
    {"target_id": "n28", "node_id": "n26", "pattern": "logic reasoning proof truth mathematical",
     "signal": [], "base_confidence": 0.72},
    # n27(L1) ↔ n12(L3) — knowledge/truth overlap
    {"target_id": "n27", "node_id": "n12", "pattern": "knowledge truth justification evidence",
     "signal": [], "base_confidence": 0.68},
    {"target_id": "n12", "node_id": "n27", "pattern": "knowledge truth evidence justify certainty",
     "signal": [], "base_confidence": 0.65},
    # n31(L5) ↔ n32(L4) — danger/observation overlap
    {"target_id": "n31", "node_id": "n32", "pattern": "danger threat risk observe detect",
     "signal": [], "base_confidence": 0.60},
    {"target_id": "n32", "node_id": "n31", "pattern": "observe detect watch monitor alert scan",
     "signal": [], "base_confidence": 0.58},
    # n29(L2) ↔ n3(L1) — structure overlap
    {"target_id": "n29", "node_id": "n3", "pattern": "equation balance solve structure rule",
     "signal": [], "base_confidence": 0.55},
    # n36(L4) ↔ n16(L4) — light/vision (same lobe, strengthens theme)
    {"target_id": "n36", "node_id": "n16", "pattern": "vision sight light bright",
     "signal": [], "base_confidence": 0.62},
]

d["attachments"].extend(new_attachments)

# ── 6. New rules ────────────────────────────────────────────────────────────
new_rules = [
    {"text": "when asked about logical truth explain both mathematical and philosophical perspectives",
     "prob": 0.85},
    {"text": "when observation and danger overlap consider whether threat is real or perceived",
     "prob": 0.80},
    {"text": "when structure is discussed explain both formal and linguistic aspects",
     "prob": 0.75},
]
d["rules"].extend(new_rules)

# ── 7. Fix sigil_table ─────────────────────────────────────────────────────
d["sigil_table"] = [
    # Lambda sigils — capture positional values at match time
    {"name": "&n", "sigil_type": "number", "class": "lambda", "applies_at": "match",
     "description": "Numeric value capture (positional)", "promote_at_tokenize": True},
    {"name": "&op", "sigil_type": "op", "class": "lambda", "applies_at": "match",
     "description": "Operator capture (+,-,*,/,^)", "promote_at_tokenize": True},
    {"name": "&word", "sigil_type": "word", "class": "lambda", "applies_at": "match",
     "description": "Single word capture", "promote_at_tokenize": True},
    {"name": "&rest", "sigil_type": "slurp", "class": "lambda", "applies_at": "match",
     "description": "Remaining input capture (greedy)", "promote_at_tokenize": True},
    # Macro sigils — expand to lexicon alternatives at bind time
    {"name": "&math_op", "sigil_type": None, "class": "macro", "applies_at": "bind",
     "lexicon": ["derive", "integrate", "solve", "prove", "calculate"],
     "description": "Mathematical operation family", "promote_at_tokenize": True},
    {"name": "&phil_topic", "sigil_type": None, "class": "macro", "applies_at": "bind",
     "lexicon": ["ethics", "epistemology", "metaphysics", "aesthetics", "ontology"],
     "description": "Philosophical topic family", "promote_at_tokenize": True},
    {"name": "&percept", "sigil_type": None, "class": "macro", "applies_at": "bind",
     "lexicon": ["see", "hear", "feel", "notice", "observe", "detect"],
     "description": "Perceptual verb family", "promote_at_tokenize": False},
    {"name": "&logic_op", "sigil_type": None, "class": "macro", "applies_at": "bind",
     "lexicon": ["infer", "deduce", "conclude", "reason", "prove"],
     "description": "Logical operation family", "promote_at_tokenize": True},
    # Tag sigils — annotations, no value capture, no expansion
    {"name": "&formal", "sigil_type": None, "class": "tag", "applies_at": "bind",
     "description": "Formal mode annotation", "promote_at_tokenize": False},
    {"name": "&casual", "sigil_type": None, "class": "tag", "applies_at": "bind",
     "description": "Casual mode annotation", "promote_at_tokenize": False},
]

# ── 8. Additional thesaurus seeds for overlap topics ────────────────────────
d["thesaurus_seeds"].update({
    "logic": ["logic", "reasoning", "inference", "deduction", "proof"],
    "truth": ["truth", "verity", "fact", "certainty", "reality"],
    "observation": ["observation", "detection", "monitoring", "watching", "scanning"],
    "structure": ["structure", "form", "order", "pattern", "system"],
    "beauty": ["beauty", "aesthetics", "elegance", "grace", "sublime"],
    "light": ["light", "illumination", "brightness", "luminance", "radiance"],
})

# ── 9. Additional verb classes for overlap themes ───────────────────────────
d["verb_registry"]["classes"].update({
    "epistemic": ["know", "believe", "justify", "confirm", "doubt", "certify"],
    "logical": ["infer", "deduce", "conclude", "derive", "prove", "establish"],
})

# ── 10. Update id_counters ─────────────────────────────────────────────────
d["id_counters"]["node"] = max(d["id_counters"].get("node", 25), 36)

# ── 11b. Add voice_register + frame_hints to ALL nodes ──────────────────
# Nodes missing these fields trigger COHERENCE WARNINGs from TonalJudge.
# We assign them based on domain (L1/L2/L3 → explanatory, L4 → descriptive,
# L5 → terse/imperative, with frame_hints matching the node's character).
_voice_defaults = {
    # L1 Math
    "calculus":           ("explanatory", ["formal", "precise"]),
    "algebra":            ("explanatory", ["formal", "stepwise"]),
    "logic":              ("explanatory", ["formal", "precise"]),
    # L2 Language
    "linguistics":        ("explanatory", ["formal", "elaborate"]),
    "rhetoric":           ("warm",        ["persuasive", "elaborate"]),
    "poetry":             ("warm",        ["expressive", "lyrical"]),
    "etymology":          ("explanatory", ["elaborate", "narrative"]),
    # L3 Philosophy
    "ethics":             ("warm",        ["principled", "deliberate"]),
    "epistemology":       ("explanatory", ["formal", "elaborate"]),
    "metaphysics":        ("explanatory", ["formal", "elaborate"]),
    "aesthetics":         ("warm",        ["expressive", "elaborate"]),
    # L4 Perception
    "vision":             ("explanatory", ["descriptive", "detailed"]),
    "audition":           ("explanatory", ["descriptive", "detailed"]),
    "somatic":            ("explanatory", ["descriptive", "embodied"]),
    "attention":          ("terse",       ["imperative", "focused"]),
    # L5 Survival
    "threat_detection":   ("terse",       ["imperative", "urgent"]),
    "shelter":            ("warm",        ["protective", "reassuring"]),
    "nutrition":          ("plain",       ["pragmatic", "efficient"]),
    "combat":             ("terse",       ["imperative", "aggressive"]),
}
_default_voice = ("plain", ["neutral"])

patched = 0
for n in d["nodes"]:
    jd = n.get("json_data", {})
    domain = jd.get("domain", "")
    vr, fh = _voice_defaults.get(domain, _default_voice)
    if "voice_register" not in jd:
        jd["voice_register"] = vr
        patched += 1
    if "frame_hints" not in jd:
        jd["frame_hints"] = fh
        patched += 1
    n["json_data"] = jd

# Also patch lobe_table json chunks (used at load time)
for lt in d["lobe_tables"]:
    chunks = lt.get("chunks", {})
    json_chunks = chunks.get("json", {})
    for nid, jdata in json_chunks.items():
        domain = jdata.get("domain", "")
        vr, fh = _voice_defaults.get(domain, _default_voice)
        if "voice_register" not in jdata:
            jdata["voice_register"] = vr
            patched += 1
        if "frame_hints" not in jdata:
            jdata["frame_hints"] = fh
            patched += 1

print(f"Patched {patched} voice_register/frame_hints fields across all nodes")

# ── 12. Save ────────────────────────────────────────────────────────────────
with open(OUT, "w") as f:
    json.dump(d, f, indent=2)

# Quick verification
with open(OUT) as f:
    v = json.load(f)
print(f"Wrote {OUT}")
print(f"  Nodes: {len(v['nodes'])}")
print(f"  Lobes: {len(v['lobes'])}")
print(f"  AIML registry lobes: {list(v['aiml_system']['registry'].keys())}")
print(f"  Attachments: {len(v['attachments'])}")
print(f"  Rules: {len(v['rules'])}")
print(f"  Sigils: {len(v['sigil_table'])}")
print(f"  Thesaurus seeds: {len(v['thesaurus_seeds'])}")
print(f"  Verb classes: {len(v['verb_registry']['classes'])}")
print(f"  Overlap node lobes: {dict((n['id'], lobe_map[n['id']]) for n in v['nodes'] if n['id'] in lobe_map)}")
