#!/bin/bash
# GrugBot420 Analog Turing v5 Interaction Session
# Loads v5 specimen and runs diverse missions + vigilance exercises
# Output: raw session log → parsed to markdown

cd /workspace/grugbot420

SESSION_RAW="specimens/v5_session_raw.log"
SESSION_MD="specimens/v5_conversation_log.md"

echo "=== Running Analog Turing v5 Interaction Session ==="
echo "=== (v7.29 vigilance + all levers exercised) ==="

cat <<'ENDINPUT' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' > "$SESSION_RAW" 2>&1

/loadSpecimen specimens/analog_turing_v5.specimen.json

# ═══════════════════════════════════════════════════════════════
# WARM-UP: Basic social + survival missions
# ═══════════════════════════════════════════════════════════════

/mission hello Grug! How are you today?
/mission What do you think about the nature of courage?
/mission I feel afraid of what's coming tomorrow
/mission Tell me about the ancient legends of the cave
/mission There is danger approaching from the north!

# ═══════════════════════════════════════════════════════════════
# REASONING + MEMORY LOBE EXERCISES
# ═══════════════════════════════════════════════════════════════

/mission Why does the wind howl at night?
/mission How do we know what is true and what is false?
/mission Grug, remember when the tribe first found fire?
/mission What is the meaning of trust?

# ═══════════════════════════════════════════════════════════════
# CREATIVE + EXPLORATION + METAPHOR LOBE EXERCISES
# ═══════════════════════════════════════════════════════════════

/mission Sing a song for the tribe Grug
/mission I want to create something beautiful
/mission What lies beyond the mountains Grug?
/mission I discovered a new path through the mountain
/mission The darkness is like a blanket over the world
/mission What does the symbol of fire mean to the tribe?

# ═══════════════════════════════════════════════════════════════
# COMFORT + CONFLICT LOBE EXERCISES
# ═══════════════════════════════════════════════════════════════

/mission I am so lonely, no one understands me
/mission My friend and I had a terrible disagreement
/mission I feel sorrow for those who are no longer with us
/mission The two hunters are arguing over the deer
/mission I feel safe when I am with the tribe

# ═══════════════════════════════════════════════════════════════
# VIGILANCE LOBE + THREAT EXERCISES
# ═══════════════════════════════════════════════════════════════

/mission There are strangers at the edge of the forest
/mission The river floods and our shelter is threatened
/mission Watch the perimeter Grug, something is out there
/mission I sense danger but I cannot see it yet

# ═══════════════════════════════════════════════════════════════
# HIGH-AROUSAL CRISIS SCENARIO
# ═══════════════════════════════════════════════════════════════

/arousal 0.9

/mission The storm is getting worse and the fire is dying!
/mission Protect the children from the wildfire!
/mission Danger! The cave entrance is collapsing!

# ═══════════════════════════════════════════════════════════════
# LOW-AROUSAL PEACEFUL SCENARIO
# ═══════════════════════════════════════════════════════════════

/arousal 0.3

/mission It is a peaceful evening and the tribe is resting by the fire
/mission The stars are beautiful tonight, tell me about them
/mission I am content and the tribe is safe

# ═══════════════════════════════════════════════════════════════
# COMPOUND INPUTS + DECOMPOSER EXERCISES
# ═══════════════════════════════════════════════════════════════

/arousal 0.6

/mission Grug, moreover I think we should furthermore consider the unknown nonetheless we must be brave
/mission hey grug what do you think about the thunderstorm coming?
/mission I have been thinking and thought about what we discovered and discovering

# ═══════════════════════════════════════════════════════════════
# VIGILANCE SYSTEM EXERCISES (v7.29 NEW!)
# ═══════════════════════════════════════════════════════════════

/vigilance
/vigilance status
/automaton maxCap 6
/vigilance threshold high 0.75
/vigilance timeout 4.0
/vigilance feedback 0.35
/vigilance

# Now run missions that should trigger vigilance dispatch
/mission ALERT! There is an imminent threat to the tribe from multiple directions!
/mission Warning! The river is rising and the dam may break!
/mission I sense something is very wrong but I cannot identify it

# Test vigilance disable/enable
/vigilance disable
/mission This danger is no longer urgent
/vigilance enable
/mission The tribe must remain vigilant always

# ═══════════════════════════════════════════════════════════════
# RIGHT/WRONG FEEDBACK EXERCISES
# ═══════════════════════════════════════════════════════════════

/mission What makes a good leader for the tribe?
/right
/mission How should we prepare for the long winter?
/right
/mission I think we should abandon the old traditions
/wrong
/mission The enemy is at the gate and we must flee
/wrong

# ═══════════════════════════════════════════════════════════════
# BRAINSTORM + EXPLICIT ANALYSIS
# ═══════════════════════════════════════════════════════════════

/brainstorm ways to protect the tribe during the cold season
/explicit analyze node_1 What are the hidden patterns in the stars?

# ═══════════════════════════════════════════════════════════════
# STATUS + CONFIGURATION VERIFICATION
# ═══════════════════════════════════════════════════════════════

/status
/nodes
/lobes
/aimlStatus
/mitosisStatus
/aimlCycle
/aimlList SurvivalLobe

/negativeThesaurus list
/listVerbs
/sigil list
/automaton list
/mlpStatus
/decomposer
/attachments
/tableStatus SurvivalLobe

# ═══════════════════════════════════════════════════════════════
# FINAL VIGILANCE VERIFICATION
# ═══════════════════════════════════════════════════════════════

/vigilance status
/automaton maxCap 10
/vigilance threshold extreme 0.92
/vigilance

# ═══════════════════════════════════════════════════════════════
# FINAL CREATIVE MISSIONS (METAPHOR-HEAVY)
# ═══════════════════════════════════════════════════════════════

/mission The cave paintings tell our story to future generations
/mission Like a river carving stone, time shapes all things
/mission The shadow of the mountain is a sign of what is to come
/mission Light and darkness dance together like old friends

# ═══════════════════════════════════════════════════════════════
# SAVE POST-SESSION SPECIMEN
# ═══════════════════════════════════════════════════════════════

/saveSpecimen specimens/analog_turing_v5_post_session.specimen.json
/quit
ENDINPUT

echo "=== Session complete. Raw log at: $SESSION_RAW ==="
echo "=== Raw log size: $(wc -c < "$SESSION_RAW") bytes ==="
echo "=== Raw log lines: $(wc -l < "$SESSION_RAW") lines ==="
echo "=== Now parsing to markdown ==="

# Parse the raw session log into a readable conversation log
python3 << 'PYEOF'
import re
import sys
import os

raw_file = "specimens/v5_session_raw.log"
md_file = "specimens/v5_conversation_log.md"

if not os.path.exists(raw_file):
    print(f"ERROR: Raw file {raw_file} not found!")
    sys.exit(1)

with open(raw_file, 'r', errors='replace') as f:
    raw = f.read()

lines = raw.split('\n')

# Extract conversation entries
entries = []
current_entry = None
skip_until_next_command = False

for line in lines:
    line_stripped = line.strip()
    
    # Detect mission input
    m_mission = re.match(r'^Brain >\s*/mission\s+(.+)$', line)
    # Detect explicit
    m_explicit = re.match(r'^Brain >\s*/explicit\s+(.+)$', line)
    # Detect brainstorm
    m_brainstorm = re.match(r'^Brain >\s*/brainstorm\s+(.+)$', line)
    # Detect AIML output scaffold
    m_scaffold = re.match(r'^Brain >\s*🤖 AIML Output Scaffold:', line)
    # Detect vigilance enrichment block
    m_vigilance = re.match(r'^Brain >\s*🔍 Vigilance Context Enrichment', line)
    # Detect grug response lines (typical emoji-prefixed responses)
    m_response = re.match(r'^Brain >\s*(Grug|🔥|🌿|💎|⚡|🧠|👁|🗣|💭|➤|→|🎯|✨|🌟|💫|☀|🌙|⛈|🌊|🏔|🌫|🪶|🛡|🏹|🎵|🎨|📖|🕯|⚔|🤝|💸|🧊|🪨|🐺|🦅|🦁|🐉|💀|👻|🫂)', line)
    # Detect generic output
    m_generic = re.match(r'^Brain >\s+(?![/?❌💎✅⚠🔗🧠🔍🧙⚙🦴🗑💣🥶🔧🫎📊])(.+)$', line)
    
    if m_mission:
        if current_entry:
            entries.append(current_entry)
        current_entry = {
            'type': 'mission',
            'input': m_mission.group(1),
            'response_lines': [],
            'vigilance_lines': []
        }
        skip_until_next_command = False
    elif m_explicit:
        if current_entry:
            entries.append(current_entry)
        current_entry = {
            'type': 'explicit',
            'input': m_explicit.group(1),
            'response_lines': [],
            'vigilance_lines': []
        }
        skip_until_next_command = False
    elif m_brainstorm:
        if current_entry:
            entries.append(current_entry)
        current_entry = {
            'type': 'brainstorm',
            'input': m_brainstorm.group(1),
            'response_lines': [],
            'vigilance_lines': []
        }
        skip_until_next_command = False
    elif current_entry and not skip_until_next_command:
        # Collect response lines
        content = re.sub(r'^Brain >\s*', '', line_stripped)
        # Skip empty prompts and command echoes
        if content and content != 'Brain >' and not content.startswith('/'):
            # Check if it's a system command response (not conversation)
            if content.startswith('❌') or content.startswith('✅') or content.startswith('⚠'):
                skip_until_next_command = True
                continue
            # Remove ANSI escape codes
            content = re.sub(r'\x1b\[[0-9;]*m', '', content)
            if len(content) > 2:
                # Track vigilance lines separately
                if 'Vigilance' in content or 'vigilance' in content or 'injector' in content.lower():
                    current_entry['vigilance_lines'].append(content)
                else:
                    current_entry['response_lines'].append(content)

if current_entry:
    entries.append(current_entry)

# Count entries by type
mission_count = sum(1 for e in entries if e['type'] == 'mission')
explicit_count = sum(1 for e in entries if e['type'] == 'explicit')
brainstorm_count = sum(1 for e in entries if e['type'] == 'brainstorm')
vigilance_entries = sum(1 for e in entries if e.get('vigilance_lines'))

# Write markdown log
with open(md_file, 'w') as f:
    f.write("# Analog Turing v5 Conversation Log\n\n")
    f.write("## GrugBot420 Neuromorphic Cognitive Engine — Comprehensive Interaction Session v5\n\n")
    f.write("This log captures a full interaction session with a comprehensive GrugBot420 specimen ")
    f.write("featuring **40 nodes across 11 lobes** (including the new MetaphorLobe), ")
    f.write("AIML nodes, automaton rules, sigil entries, MLP rules, inhibitions, verb classes, ")
    f.write("synonyms, decomposer config, orchestration rules, and the **v7.29 Vigilance/Context Injector dispatch system**.\n\n")
    f.write("### Specimen Configuration\n\n")
    f.write("| Parameter | Value |\n")
    f.write("|-----------|-------|\n")
    f.write("| Nodes | 39 |\n")
    f.write("| Lobes | 11 (Survival, Social, Reasoning, Creative, Memory, Vigilance, Comfort, Exploration, Conflict, Metaphor) |\n")
    f.write("| AIML Nodes | 7 |\n")
    f.write("| Automaton Rules | 8 |\n")
    f.write("| Sigil Entries | 14 |\n")
    f.write("| Vigilance Cap | 8 (adjustable 1-16) |\n")
    f.write("| Vigilance Thresholds | low=0.20, med=0.45, high=0.70, extreme=0.88 |\n")
    f.write("| Injector Timeout | 6.0s |\n")
    f.write("| Injector Feedback Prob | 0.20 |\n")
    f.write("| Negative Thesaurus | 6 entries |\n")
    f.write("| Contrast Pairs | 5 |\n\n")
    f.write("---\n\n")
    
    entry_num = 0
    for entry in entries:
        if entry['type'] in ('mission', 'explicit', 'brainstorm'):
            entry_num += 1
            type_label = {
                'mission': '📨 Mission',
                'explicit': '🎯 Explicit',
                'brainstorm': '💭 Brainstorm'
            }.get(entry['type'], entry['type'])
            
            f.write(f"### Exchange {entry_num} — {type_label}\n\n")
            f.write(f"**→ User:** {entry['input']}\n\n")
            
            if entry['response_lines']:
                # Clean up response lines and join
                resp_text = '\n'.join(entry['response_lines'][:25])
                resp_text = resp_text.strip()
                if resp_text:
                    f.write(f"**← Grug:** {resp_text}\n\n")
                else:
                    f.write("**← Grug:** *(processing... no vocal response captured)*\n\n")
            else:
                f.write("**← Grug:** *(processing...)*\n\n")
            
            # Add vigilance annotation if present
            if entry.get('vigilance_lines'):
                vig_text = '\n'.join(entry['vigilance_lines'][:5])
                f.write(f"*🔍 Vigilance:* {vig_text}\n\n")
    
    f.write("---\n\n")
    f.write("## Session Summary\n\n")
    f.write(f"- **Total conversation exchanges:** {entry_num}\n")
    f.write(f"- **Mission inputs:** {mission_count}\n")
    f.write(f"- **Explicit analyses:** {explicit_count}\n")
    f.write(f"- **Brainstorm sessions:** {brainstorm_count}\n")
    f.write(f"- **Exchanges with vigilance activity:** {vigilance_entries}\n")
    f.write(f"- **Specimen:** analog_turing_v5.specimen.json\n")
    f.write(f"- **Post-session specimen:** analog_turing_v5_post_session.specimen.json\n\n")
    f.write("### v7.29 Vigilance System Notes\n\n")
    f.write("The vigilance/context injector system dispatches automatons based on computed context weight. ")
    f.write("Context weight is a composite score derived from lobe activation depth, winner strength, ")
    f.write("inhibition hits, anti-match detection, and memory intensity. Higher context weight triggers ")
    f.write("more context injector automatons (up to the configured max cap). Each injector agent probes ")
    f.write("the subconscious (SelfObserver) with biased disposition inherited from its rule, and injects ")
    f.write("findings back into the response scaffold as context enrichment.\n\n")
    f.write("During this session, vigilance was exercised via:\n")
    f.write("- `/vigilance` status checks\n")
    f.write("- `/automaton maxCap` adjustments\n")
    f.write("- `/vigilance threshold` level tuning\n")
    f.write("- `/vigilance timeout` and `/vigilance feedback` configuration\n")
    f.write("- `/vigilance enable` and `/vigilance disable` toggling\n")
    f.write("- High-threat missions designed to trigger elevated context weight\n")

print(f"Parsed {len(entries)} entries, {entry_num} conversation exchanges")
print(f"  Missions: {mission_count}, Explicit: {explicit_count}, Brainstorm: {brainstorm_count}")
print(f"  Exchanges with vigilance: {vigilance_entries}")
print(f"Markdown log saved to: {md_file}")
PYEOF

echo "=== All done ==="
ls -la specimens/v5_conversation_log.md 2>/dev/null
ls -la specimens/analog_turing_v5_post_session.specimen.json 2>/dev/null
