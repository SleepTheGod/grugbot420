#!/bin/bash
# Build specimen with 1100 nodes for idle systems testing
# Uses 11 lobes x 100 nodes each
set -e

cd /workspace/grugbot420

SPECIMEN_FILE="specimens/idle_test_v6.specimen.json"

echo "=== Building Idle Test Specimen v6 ==="
echo "=== (1100 nodes across 11 lobes for idle gate testing) ==="

# Generate the CLI input with many nodes via Python
python3 << 'PYEOF'
lobes = [
    ('AlphaLobe',    'alpha primary core foundation base'),
    ('BetaLobe',     'beta secondary support auxiliary help'),
    ('GammaLobe',    'gamma tertiary extension branch reach'),
    ('DeltaLobe',    'delta change transformation shift evolve'),
    ('EpsilonLobe',  'epsilon precision accuracy exact detail'),
    ('ZetaLobe',     'zeta zeal enthusiasm energy vigor'),
    ('EtaLobe',      'eta efficiency economy optimal stream'),
    ('ThetaLobe',    'theta thought contemplation reflection mind'),
    ('IotaLobe',     'iota small detail particular specific'),
    ('KappaLobe',    'kappa knowledge wisdom understanding learn'),
    ('LambdaLobe',   'lambda logic inference deduction reason'),
]

lines = []

# Create lobes
for name, subj in lobes:
    lines.append(f'/newLobe {name} {subj}')

# Connect adjacent lobes
for i in range(len(lobes)):
    for j in range(i+1, min(i+3, len(lobes))):
        lines.append(f'/connectLobes {lobes[i][0]} {lobes[j][0]}')

# Grow 100 nodes per lobe = 1100 total
node_id = 0
for lobe_idx, (lobe_name, subj) in enumerate(lobes):
    words = subj.split()
    for n in range(100):
        node_id += 1
        w = words[n % len(words)]
        pattern = f'n{node_id} {w} topic{node_id}'
        prompt = f'Grug handles {w} topic{node_id}.'
        lines.append(f'/grow {lobe_name} {{"pattern":"{pattern}","action_packet":"respond[answer]^4|reason[think]^3|support[help]^2","data":{{"system_prompt":"{prompt}","noun_anchors":["{w}"],"voice_register":"plain","frame_hints":["plain"]}}}}')

# Status check
lines.append('/status')

# Save specimen
lines.append(f'/saveSpecimen {SPECIMEN_FILE}')
lines.append('/quit')

with open('/tmp/idle_build_commands.txt', 'w') as f:
    f.write('\n'.join(lines))

print(f'Generated {len(lines)} CLI commands')
PYEOF

echo "Generated $(wc -l < /tmp/idle_build_commands.txt) CLI commands"
echo "Running build (this may take a few minutes)..."

# Run the build
cat /tmp/idle_build_commands.txt | julia --project=. -e 'using GrugBot420; GrugBot420.run_cli()' 2>&1 | tail -200

echo ""
echo "=== Build complete ==="
ls -la "$SPECIMEN_FILE" 2>/dev/null && echo "Specimen saved: $SPECIMEN_FILE" || echo "WARNING: Specimen file not found!"
