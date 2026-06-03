import json

with open('specimens/v741_pre_session.specimen.json') as f:
    spec = json.load(f)

nodes = {n['id']: n for n in spec['nodes']}

# Target nodes and their required_relations
target_map = {
    'node_3':  'Q1: jitter deepest level',
    'node_4':  'Q2: gravity same push strong force',
    'node_36': 'Q3/Q14: pushed out of shape / jitterSnapBack',
    'node_12': 'Q4: semantic attachment relay signal',
    'node_27': 'Q5: markov chains mutated votes',
    'node_18': 'Q6: organ systems working together',
    'node_19': 'Q7: force feeling calculation',
    'node_25': 'Q8: shimmer understanding AI',
    'node_5':  'Q9: meaning shape of connections',
    'node_26': 'Q10: execution cortex pipeline',
    'node_28': 'Q11: write-once invariant',
    'node_17': 'Q12: sigil vs regular pattern',
    'node_32': 'Q13: proof chain or web',
    'node_37': 'Q15: semantic proximity metaphor',
    'node_41': 'Q16: sigil compressed words',
    'node_42': 'Q17: predator outside cave',
    'node_44': 'Q18: hungry fire going out',
    'node_47': 'Q19: hello friend eastern tribe',
    'node_49': 'Q20: empathy tribe scarce resources',
    'node_52': 'Q21: repeating yourself',
    'node_53': 'Q22: change approach mid-conversation',
    'node_56': 'Q23: song spectral bandwidth',
    'node_62': 'Q24: story jitter snapback characters',
    'node_60': 'Q25: darkness not empty',
    'node_63': 'Q26/Q27: feeling force / functor shimmer',
    'node_64': 'Q28: creative expression same topology survival',
}

print('TARGET NODE required_relations CHECK:')
print()
restrictive_count = 0
for nid, desc in sorted(target_map.items(), key=lambda x: int(x[0].split('_')[1])):
    n = nodes[nid]
    req_rels = n.get('required_relations', [])
    pattern = n.get('pattern', '')
    strength = n.get('strength', 0)
    # Check which have restrictive required_relations (not just NONJITTER or empty)
    restrictive = [r for r in req_rels if r != 'NONJITTER']
    nonjitter = 'NONJITTER' in req_rels
    tag = '[NONJITTER]' if nonjitter else '[OPEN]'
    
    if restrictive:
        restrictive_count += 1
        print('  {} ({}): required_relations={}, strength={}'.format(nid, desc, req_rels, strength))
        print('    pattern: {}'.format(pattern[:80]))
        print('    *** RESTRICTIVE GATE: {} ***'.format(restrictive))
        print()
    else:
        print('  {} ({}): req_rels={}, strength={} {}'.format(nid, desc, req_rels, strength, tag))

print()
print('TARGETS WITH RESTRICTIVE required_relations: {}/{}'.format(restrictive_count, len(target_map)))

# Now check ALL nodes with restrictive required_relations
print()
print('=' * 70)
print('ALL NODES WITH RESTRICTIVE required_relations:')
print('=' * 70)
for nid in sorted(nodes.keys(), key=lambda x: int(x.split('_')[1])):
    n = nodes[nid]
    req_rels = n.get('required_relations', [])
    restrictive = [r for r in req_rels if r != 'NONJITTER']
    if restrictive:
        print('  {}: req_rels={}, pattern={}'.format(nid, req_rels, n['pattern'][:60]))

# Now check: for each question, what triples does the engine extract?
# The user input gets parsed into (subject, relation, object) triples
# If the question is "What happens when votes get mutated by Markov chains?"
# The engine might extract: (votes, causes, mutated) — which has "causes" relation!
# So required_relations=['causes'] SHOULD pass...
# Let me check what user triples are extracted per question in v7.41
print()
print('=' * 70)
print('USER TRIPLES PER QUESTION IN v7.41:')
print('=' * 70)

import re
with open('specimens/v741_interaction_raw.log') as f:
    content = f.read()

scaffolds = content.split('🤖 AIML Output Scaffold:')
questions = [
    "What makes everything jitter at the deepest level?",
    "How is gravity the same kind of push as the strong force?",
    "When something is pushed out of shape, what brings it back?",
    "How does a semantic attachment actually relay a signal?",
    "What happens when votes get mutated by Markov chains?",
    "Tell me about grug's organ systems working together",
    "Why can't you force a feeling the way you force a calculation?",
    "What is the shimmer and why does it matter for understanding AI?",
    "How does meaning live in the shape of connections rather than the words?",
    "Walk me through the execution cortex pipeline step by step",
    "Why is the write-once invariant so important for computation?",
    "What does a sigil do that a regular pattern cannot?",
    "What is a proof really — is it a chain or a web?",
    "How does the jitterSnapBack functor unify everything mathematically?",
    "How does semantic proximity let us understand metaphor?",
    "What makes a sigil more compressed than the words it replaces?",
    "There is a predator outside the cave. What should we do?",
    "I am hungry and the fire is going out. Help me think through this.",
    "Hello friend, I bring news from the eastern tribe",
    "How does empathy hold the tribe together when resources are scarce?",
    "Grug, you seem to be repeating yourself. Can you notice that pattern?",
    "What would it mean for you to actually change your approach mid-conversation?",
    "Sing me a song about the spectral bandwidth of all forces",
    "Tell me a story where jitter and snapback are characters",
    "The darkness is not empty — it holds the shape of everything waiting to become",
    "If feeling is fundamental and force is just push, then what is the relationship between emotion and physics?",
    "How does the mathematical functor connect to the philosophical shimmer?",
    "Write a proof that creative expression emerges from the same topology as survival instinct",
]

target_list = [
    'node_3', 'node_4', 'node_36', 'node_12', 'node_27', 'node_18',
    'node_19', 'node_25', 'node_5', 'node_26', 'node_28', 'node_17',
    'node_32', 'node_36', 'node_37', 'node_41', 'node_42', 'node_44',
    'node_47', 'node_49', 'node_52', 'node_53', 'node_56', 'node_62',
    'node_60', 'node_63', 'node_63', 'node_64',
]

for i, scaffold in enumerate(scaffolds[1:], 1):
    # Extract user triples from FIRST debug telemetry block only
    # (each scaffold has multiple debug blocks for different votes)
    first_debug_end = scaffold.find('=========================================')
    if first_debug_end == -1:
        first_debug_end = 500
    first_block = scaffold[:first_debug_end]
    
    triples_match = re.search(r'User Triples:\s*(.+)', first_block)
    triples_str = triples_match.group(1) if triples_match else 'NOT FOUND'
    winner_match = re.search(r'Winning Node:\s*(node_\d+)', first_block)
    winner = winner_match.group(1) if winner_match else '?'
    target = target_list[i-1]
    is_correct = winner == target
    
    print('  Q{:>2} [{}] target={} winner={}: User Triples: {}'.format(
        i, '✓' if is_correct else '✗', target, winner, triples_str[:100]))
