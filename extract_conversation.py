#!/usr/bin/env python3
"""Extract mission input→AIML output conversation pairs from raw grugbot output."""
import re, sys

raw = open(sys.argv[1]).read()

# Find all mission inputs
missions = []
for m in re.finditer(r"Mission:\s*'([^']+)'", raw):
    missions.append(m.group(1))

# Find all AIML output scaffolds
scaffolds = []
for m in re.finditer(r"AIML Output Scaffold:\n(.*?)(?:\n--- DEBUG|Primary Action:)", raw, re.DOTALL):
    text = m.group(1).strip()
    # Clean up directives
    text = re.sub(r'\s*\[Directives:.*?\]', '', text, flags=re.DOTALL)
    # Clean up "Pinned note:" if it's inline
    # Remove trailing periods that are doubled
    text = text.replace('..', '.').strip()
    if text.endswith('.'):
        pass  # fine
    scaffolds.append(text)

# Also extract primary action + winning node for each scaffold
actions = []
for m in re.finditer(r"Primary Action:\s+(\S+)\s+\(conf=([\d.]+).*?\)\n.*?Winning Node:\s+(\S+)", raw, re.DOTALL):
    actions.append((m.group(1), float(m.group(2)), m.group(3)))

# Extract lobe context
lobes = []
for m in re.finditer(r"Lobe Context:\s+\[([^\]]+)\]", raw):
    lobes.append(m.group(1))

# Print conversation
print(f"# Found {len(missions)} missions, {len(scaffolds)} scaffolds, {len(actions)} actions, {len(lobes)} lobe contexts\n")

# Build the conversation - pair up missions with their scaffolds
# Some missions produce "Cave is silent" (no scaffold), some produce multiple outputs
# We need to align them carefully

# Re-parse with a sequential scan
lines = raw.split('\n')
conv_pairs = []
current_mission = None
current_scaffold = None
current_action = None
current_node = None
current_lobe = None
in_scaffold = False
scaffold_buf = []
cave_silent = False

i = 0
while i < len(lines):
    line = lines[i]
    
    # Mission input
    m = re.match(r".*Mission:\s*'([^']+)'", line)
    if m:
        # Save previous if exists
        if current_mission is not None:
            conv_pairs.append({
                'mission': current_mission,
                'scaffold': current_scaffold,
                'action': current_action,
                'node': current_node,
                'lobe': current_lobe,
                'silent': cave_silent
            })
        current_mission = m.group(1)
        current_scaffold = None
        current_action = None
        current_node = None
        current_lobe = None
        in_scaffold = False
        scaffold_buf = []
        cave_silent = False
    
    # Cave is silent
    if "Cave is silent" in line:
        cave_silent = True
    
    # AIML Output Scaffold start
    if "AIML Output Scaffold:" in line:
        in_scaffold = True
        scaffold_buf = []
        # The scaffold text might start on this same line or next line
        rest = line.split("AIML Output Scaffold:", 1)[1].strip()
        if rest:
            scaffold_buf.append(rest)
        i += 1
        continue
    
    if in_scaffold:
        if line.startswith("--- DEBUG") or line.startswith("Primary Action:"):
            in_scaffold = False
            current_scaffold = '\n'.join(scaffold_buf).strip()
            # Clean directives
            current_scaffold = re.sub(r'\s*\[Directives:.*?\]', '', current_scaffold, flags=re.DOTALL)
            current_scaffold = current_scaffold.replace('.. ', '. ').strip()
            # Don't dedupe double periods - they're intentional grug-speak
        else:
            scaffold_buf.append(line)
    
    # Primary action
    m = re.match(r"Primary Action:\s+(\S+)\s+\(conf=([\d.]+)", line)
    if m:
        current_action = (m.group(1), float(m.group(2)))
    
    # Winning node
    m = re.match(r"Winning Node:\s+(\S+)", line)
    if m:
        current_node = m.group(1)
    
    # Lobe context
    m = re.match(r"Lobe Context:\s+\[([^\]]+)\]", line)
    if m:
        current_lobe = m.group(1)
    
    i += 1

# Save last
if current_mission is not None:
    conv_pairs.append({
        'mission': current_mission,
        'scaffold': current_scaffold,
        'action': current_action,
        'node': current_node,
        'lobe': current_lobe,
        'silent': cave_silent
    })

# Deduplicate - same mission can appear in multiple scaffolds if node fires twice
# Keep the FIRST scaffold for each unique mission input
seen = set()
deduped = []
for p in conv_pairs:
    key = p['mission']
    if key not in seen:
        seen.add(key)
        deduped.append(p)

print(f"# Deduplicated: {len(deduped)} unique mission→response pairs\n")
print("=" * 70)

for p in deduped:
    print(f"\nYOU:  {p['mission']}")
    if p['silent']:
        print(f"GRUG: [Cave is silent — no matching node]")
    elif p['scaffold']:
        # Format the scaffold nicely
        text = p['scaffold'].strip()
        # Wrap long lines
        words = text.split()
        line = "GRUG: "
        for w in words:
            if len(line) + len(w) + 1 > 78:
                print(line)
                line = "      "
            line += w + " "
        if line.strip():
            print(line)
    else:
        print(f"GRUG: [no output captured]")
    
    if p['action']:
        print(f"      [{p['action'][0]} via {p['node']} — conf={p['action'][1]:.2f}]")
    if p['lobe']:
        print(f"      Lobe: {p['lobe']}")
