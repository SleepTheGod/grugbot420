import re, json

def parse_log(logfile):
    with open(logfile) as f:
        content = f.read()
    scaffolds = content.split('🤖 AIML Output Scaffold:')
    results = []
    for i, scaffold in enumerate(scaffolds[1:], 1):
        winners = re.findall(r'Winning Node:\s*(node_\d+)', scaffold)
        mission_match = re.search(r"Mission:\s*'(.+?)'", scaffold)
        question = mission_match.group(1) if mission_match else 'UNKNOWN'
        confs = re.findall(r'conf=([0-9.]+)', scaffold)
        if winners:
            results.append({
                'scaffold': i, 'question': question,
                'first_winner': winners[0], 'all_winners': winners,
                'first_conf': confs[0] if confs else '?',
                'all_confs': confs,
            })
    return results

# Parse all three logs
v739 = parse_log('specimens/v739_interaction_raw.log')
v740 = parse_log('specimens/v740_interaction_raw.log')
v741 = parse_log('specimens/v741_interaction_raw.log')

print(f'Parsed: v7.39={len(v739)} scaffolds, v7.40={len(v740)} scaffolds, v7.41={len(v741)} scaffolds')

# Expected target nodes per question
target_map = {
    1: 'node_3',   # jitter deepest level
    2: 'node_4',   # gravity same push strong force
    3: 'node_36',  # pushed out of shape brings back
    4: 'node_12',  # semantic attachment relay signal
    5: 'node_27',  # markov chains mutated votes
    6: 'node_18',  # organ systems working together
    7: 'node_19',  # force feeling calculation
    8: 'node_25',  # shimmer understanding AI
    9: 'node_5',   # meaning shape of connections
    10: 'node_26', # execution cortex pipeline
    11: 'node_28', # write-once invariant
    12: 'node_17', # sigil vs regular pattern
    13: 'node_32', # proof chain or web
    14: 'node_36', # jitterSnapBack functor
    15: 'node_37', # semantic proximity metaphor
    16: 'node_41', # sigil compressed words
    17: 'node_42', # predator outside cave
    18: 'node_44', # hungry fire going out
    19: 'node_47', # hello friend eastern tribe
    20: 'node_49', # empathy tribe scarce resources
    21: 'node_52', # repeating yourself
    22: 'node_53', # change approach mid-conversation
    23: 'node_56', # song spectral bandwidth
    24: 'node_62', # story jitter snapback characters
    25: 'node_60', # darkness not empty
    26: 'node_63', # feeling force emotion physics
    27: 'node_63', # mathematical functor philosophical shimmer
    28: 'node_64', # creative expression same topology survival
}

# Compare coherence
header = "{:<4} {:<50} {:<10} {:<10} {:<10}".format('Q#', 'Question (short)', 'v739', 'v740', 'v741')
print()
print(header)
print('-' * 84)

coherent = {'v739': 0, 'v740': 0, 'v741': 0}
details = []

for qnum in range(1, 29):
    target = target_map.get(qnum, '?')
    q_short = v739[qnum-1]['question'][:48] if qnum <= len(v739) else '?'
    
    results = {}
    for ver, data in [('v739', v739), ('v740', v740), ('v741', v741)]:
        if qnum <= len(data):
            winner = data[qnum-1]['first_winner']
            is_correct = winner == target
            mark = '✓' if is_correct else '✗'
            results[ver] = '{}({})'.format(winner, mark)
            if is_correct:
                coherent[ver] += 1
        else:
            results[ver] = 'N/A'
    
    row = "{:<4} {:<50} {:<10} {:<10} {:<10}".format(
        qnum, q_short, results['v739'], results['v740'], results['v741'])
    print(row)
    details.append({'qnum': qnum, 'target': target, 'q_short': q_short, 'results': results})

print('-' * 84)
total_row = "     TOTAL COHERENT:                                   {}/28      {}/28      {}/28".format(
    coherent['v739'], coherent['v740'], coherent['v741'])
pct_row = "     PERCENTAGE:                                       {:.1f}%       {:.1f}%       {:.1f}%".format(
    coherent['v739']/28*100, coherent['v740']/28*100, coherent['v741']/28*100)
print(total_row)
print(pct_row)

# Now let's look at where v7.41 differs from v7.39 (improvements and regressions)
print()
print("=" * 84)
print("CHANGES FROM v7.39 → v7.41:")
print("=" * 84)
improvements = []
regressions = []
for d in details:
    q = d['qnum']
    v39 = d['results']['v739']
    v41 = d['results']['v741']
    c39 = '✓' in v39
    c41 = '✓' in v41
    if c41 and not c39:
        improvements.append(d)
    elif c39 and not c41:
        regressions.append(d)

print()
print("IMPROVEMENTS (wrong in v7.39, correct in v7.41):")
for d in improvements:
    print("  Q{}: {} → {}".format(d['qnum'], d['results']['v739'], d['results']['v741']))
print("  Total: {} improvements".format(len(improvements)))

print()
print("REGRESSIONS (correct in v7.39, wrong in v7.41):")
for d in regressions:
    print("  Q{}: {} → {}".format(d['qnum'], d['results']['v739'], d['results']['v741']))
print("  Total: {} regressions".format(len(regressions)))

# Also analyze wrong winners in v7.41 for pattern
print()
print("=" * 84)
print("WRONG WINNERS IN v7.41 — Pattern Analysis:")
print("=" * 84)
from collections import Counter
wrong_winners = []
for d in details:
    if '✗' in d['results']['v741']:
        winner = d['results']['v741'].split('(')[0]
        wrong_winners.append(winner)
        
if wrong_winners:
    print("  Wrong winner frequency: {}".format(dict(Counter(wrong_winners))))
    print("  Total decoherent: {}/28".format(len(wrong_winners)))
else:
    print("  ALL COHERENT! 🎉")

# Show the actual first response text for each scaffold in v7.41
print()
print("=" * 84)
print("v7.41 FIRST RESPONSE CONTENT (voice_body check):")
print("=" * 84)

# Re-parse to get the actual output text
with open('specimens/v741_interaction_raw.log') as f:
    v741_content = f.read()
scaffolds = v741_content.split('🤖 AIML Output Scaffold:')

for i, scaffold in enumerate(scaffolds[1:], 1):
    target = target_map.get(i, '?')
    # Extract the first few lines of actual output
    lines = scaffold.strip().split('\n')
    # Find first non-empty line after scaffold marker
    output_lines = []
    for line in lines[:15]:
        if line.strip() and not line.startswith('📋') and not line.startswith('──'):
            output_lines.append(line.strip()[:80])
    first_output = ' | '.join(output_lines[:3])
    
    winner = v741[i-1]['first_winner']
    is_correct = winner == target
    mark = '✓' if is_correct else '✗'
    print("  Q{:<2} [{}] {} → {}".format(i, mark, winner, first_output[:100]))
