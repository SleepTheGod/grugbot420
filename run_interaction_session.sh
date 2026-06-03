#!/bin/bash
# GrugBot420 Analog Turing Interaction Session
# Loads v4 specimen and runs diverse missions to capture Grug's responses
# Output saved to raw session log, then parsed to markdown

cd /workspace/grugbot420

SESSION_RAW="specimens/analog_turing_session_raw.log"
SESSION_MD="specimens/analog_turing_conversation_log.md"

echo "=== Running Analog Turing Interaction Session ==="

cat <<'ENDINPUT' | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' > "$SESSION_RAW" 2>&1

/loadSpecimen specimens/analog_turing_v4.specimen.json

/mission hello Grug! How are you today?
/mission What do you think about the nature of courage?
/mission I feel afraid of what's coming tomorrow
/mission Tell me about the ancient legends of the cave
/mission There is danger approaching from the north!
/mission Why does the wind howl at night?
/mission I discovered a new path through the mountain
/mission My friend and I had a terrible disagreement
/mission Grug, remember when the tribe first found fire?
/mission I am so lonely, no one understands me
/mission What is the meaning of trust?
/mission The river floods and our shelter is threatened
/mission Sing a song for the tribe Grug
/mission How do we know what is true and what is false?
/mission Someone I loved is gone and I cannot find them
/mission There are strangers at the edge of the forest
/mission I want to create something beautiful
/mission The two hunters are arguing over the deer
/mission What lies beyond the mountains Grug?
/mission I feel safe when I am with the tribe

/status
/nodes
/lobes
/aimlStatus
/mitosisStatus

/aimlCycle
/aimlList SurvivalLobe

/brainstorm ways to protect the tribe during the cold season

/arousal 0.8

/mission The storm is getting worse and the fire is dying!
/arousal 0.4

/mission It is a peaceful evening and the tribe is resting by the fire

/negativeThesaurus list
/listVerbs
/sigil list
/automaton list
/mlpStatus
/decomposer
/attachments
/tableStatus SurvivalLobe

/thesaurus courage | fear
/thesaurus love | hate

/explicit analyze node_11 What are the hidden patterns in the stars?

/mission Grug, moreover I think we should furthermore consider the unknown nonetheless we must be brave
/mission hey grug what do you think about the thunderstorm coming?

/right
/mission What makes a good leader for the tribe?
/right
/mission How should we prepare for the long winter?
/wrong
/mission I think we should abandon the old traditions
/wrong

/mission The cave paintings tell our story to future generations
/mission Protect the children from the wildfire
/mission I feel sorrow for those who are no longer with us

/saveSpecimen specimens/analog_turing_post_session.specimen.json
/quit
ENDINPUT

echo "=== Session complete. Raw log at: $SESSION_RAW ==="
echo "=== Now parsing to markdown ==="

# Parse the raw session log into a readable conversation log
python3 << 'PYEOF'
import re
import sys

raw_file = "specimens/analog_turing_session_raw.log"
md_file = "specimens/analog_turing_conversation_log.md"

with open(raw_file, 'r', errors='replace') as f:
    raw = f.read()

lines = raw.split('\n')

# Extract conversation entries
entries = []
current_entry = None

for line in lines:
    line_stripped = line.strip()
    
    # Detect mission input
    m_mission = re.match(r'^Brain >\s*/mission\s+(.+)$', line)
    # Detect Grug response - look for typical Grug response patterns
    m_grug_resp = re.match(r'^Brain >\s*(?:Grug|🧠|⚡|🌿|🔥|💎|🪨|👁|🗣|💭|➤|→|🎯|✨|🌟|💫|☀|🌙|⛈|🌋|🏔|🏕|🦣|🪶|🛡|🏹|🎶|🎨|📖|🕯|⚔|🤝|💫)', line)
    # Detect explicit
    m_explicit = re.match(r'^Brain >\s*/explicit\s+(.+)$', line)
    # Detect brainstorm
    m_brainstorm = re.match(r'^Brain >\s*/brainstorm\s+(.+)$', line)
    # Detect system responses  
    m_system = re.match(r'^Brain >\s*(✅|⚠|❌|🔗|🧠|💎|🔍|🧹|⚙|🪄|🗑|🛑|🧊|🔧|🪬|📊)', line)
    # Detect grug output that's not a prompt
    m_output = re.match(r'^Brain >\s+(?![/?])(.+)$', line)
    
    if m_mission:
        if current_entry:
            entries.append(current_entry)
        current_entry = {
            'type': 'mission',
            'input': m_mission.group(1),
            'response_lines': []
        }
    elif m_explicit:
        if current_entry:
            entries.append(current_entry)
        current_entry = {
            'type': 'explicit',
            'input': m_explicit.group(1),
            'response_lines': []
        }
    elif m_brainstorm:
        if current_entry:
            entries.append(current_entry)
        current_entry = {
            'type': 'brainstorm',
            'input': m_brainstorm.group(1),
            'response_lines': []
        }
    elif current_entry and line_stripped and line_stripped != 'Brain >':
        # Collect response lines
        if not line_stripped.startswith('Brain > /') and not line_stripped.startswith('-->'):
            content = re.sub(r'^Brain >\s*', '', line_stripped)
            if content and len(content) > 2:
                current_entry['response_lines'].append(content)

if current_entry:
    entries.append(current_entry)

# Write markdown log
with open(md_file, 'w') as f:
    f.write("# Analog Turing Conversation Log\n\n")
    f.write("## GrugBot420 Neuromorphic Cognitive Engine — Comprehensive Interaction Session\n\n")
    f.write("This log captures a full interaction session with a comprehensive GrugBot420 specimen\n")
    f.write("featuring 36 nodes across 10 lobes, with AIML nodes, automaton rules, sigil entries,\n")
    f.write("MLP rules, inhibitions, verb classes, synonyms, decomposer config, and orchestration rules.\n\n")
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
                resp_text = '\n'.join(entry['response_lines'][:20])  # limit to 20 lines
                # Remove ANSI-like artifacts
                resp_text = re.sub(r'\x1b\[[0-9;]*m', '', resp_text)
                resp_text = resp_text.strip()
                if resp_text:
                    f.write(f"**← Grug:** {resp_text}\n\n")
                else:
                    f.write("**← Grug:** *(processing... no vocal response captured in this line)*\n\n")
            else:
                f.write("**← Grug:** *(processing...)*\n\n")
    
    f.write("---\n\n")
    f.write(f"## Summary\n\n")
    f.write(f"- Total exchanges: {entry_num}\n")
    f.write(f"- Specimen: analog_turing_v4.specimen.json\n")
    f.write(f"- Nodes: 36 across 10 lobes\n")

print(f"Parsed {len(entries)} entries, {entry_num} conversation exchanges")
print(f"Markdown log saved to: {md_file}")
PYEOF

echo "=== All done ==="
ls -la specimens/analog_turing_conversation_log.md 2>/dev/null
