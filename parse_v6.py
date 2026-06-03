#!/usr/bin/env python3
"""v6 parser: Fixed version that handles:
1. Override scaffolds where entire Julia tuple is on one line (avoids swallowing second override)
2. /loadSpecimen output that appears before the burst structure starts
3. Proper sequential marker scanning for governance commands
"""
import re, sys

RAW = "specimens/v751_raw_governance.log"
SCRIPT = "test_all_governance.txt"
OUT = "specimens/v751_conversation_log.md"

def load_raw():
    with open(RAW) as f: return f.readlines()

def parse_script():
    cmds = []
    cur_phase = "Setup"
    with open(SCRIPT) as f:
        for line in f:
            line = line.strip()
            m = re.match(r'#\s*---\s*PHASE\s+\d+[:\s]*(.*?)\s*---', line)
            if m: cur_phase = m.group(1).strip(); continue
            if line.startswith('#') or not line: continue
            cmds.append((cur_phase, line))
    return cmds

def extract_scaffolds(raw_lines):
    """Extract all AIML scaffolds (normal, override, companion) from raw log.
    
    Key fix: Override scaffolds have their ENTIRE content on one line
    (Julia tuple format). We must extract text, mission, action, certainty
    etc. from that single line using regex, NOT by scanning subsequent lines.
    This prevents the parser from swallowing a second override that appears
    right after the first one.
    """
    scaffolds = []
    i, n = 0, len(raw_lines)
    
    while i < n:
        line = raw_lines[i].rstrip('\n')
        is_normal = 'AIML Output Scaffold:' in line
        is_override = 'AIML [Targeted Override]:' in line
        is_companion = line.strip().startswith('*Grug think this also important*')
        
        if is_override:
            # Override: entire scaffold is on the NEXT line as a Julia tuple
            # Format: ("Response text\\n--- DEBUG TELEMETRY...\\nMission: '...'\\n...\\n=========", Vote[...], Vote[])
            s = {'type': 'override', 'text': '',
                 'mission': None, 'action': None, 'conf': None, 'certainty': None,
                 'sure_actions': None, 'unsure_actions': None, 'winning_node': None,
                 'tied': [], 'others': [], 'is_companion': False, 'line': i}
            i += 1
            if i < n:
                l = raw_lines[i].rstrip('\n')
                # Extract text: everything between (" and \n---
                # In the raw log, the Julia tuple line contains literal \n (backslash-n)
                # as the newline separator within the Julia string.
                # Regex: \(" matches literal ("; (.+?) captures text; \\n--- matches \n---
                text_match = re.search(r'\("(.+?)\\n---', l)
                if text_match:
                    s['text'] = text_match.group(1).strip()
                else:
                    # Fallback: between (" and first ",
                    text_match2 = re.search(r'\("(.+?)"', l)
                    if text_match2:
                        s['text'] = text_match2.group(1).strip()
                
                # Extract mission from the embedded debug telemetry
                mission_match = re.search(r"Mission: '(.+?)'", l)
                if mission_match:
                    s['mission'] = mission_match.group(1)
                
                # Extract primary action
                action_match = re.search(r'Primary Action:\s+(\S+)\s+\(conf=([0-9.]+),\s+certainty=(\w+)', l)
                if action_match:
                    s['action'] = action_match.group(1)
                    s['conf'] = float(action_match.group(2))
                    s['certainty'] = action_match.group(3)
                
                # Extract sure actions
                sure_match = re.search(r'Sure Actions:\s+\[(.+?)\]', l)
                if sure_match:
                    s['sure_actions'] = sure_match.group(1)
                
                # Extract unsure actions
                unsure_match = re.search(r'Unsure Actions.*?:\s+\[(.+?)\]', l)
                if unsure_match:
                    s['unsure_actions'] = unsure_match.group(1)
                
                # Extract winning node (stop at \\n boundary since everything is on one line)
                node_match = re.search(r'Winning Node:\s+([^\s\\\\]+)', l)
                if node_match:
                    s['winning_node'] = node_match.group(1)
            
            # Don't scan forward — everything is on one line
            scaffolds.append(s)
            # i stays at the tuple line; the main loop's i += 1 will advance past it
        
        elif is_normal:
            s = {'type': 'normal', 'text': '',
                 'mission': None, 'action': None, 'conf': None, 'certainty': None,
                 'sure_actions': None, 'unsure_actions': None, 'winning_node': None,
                 'tied': [], 'others': [], 'is_companion': False, 'line': i}
            i += 1
            if i < n: s['text'] = raw_lines[i].rstrip('\n').strip()
            # Scan subsequent lines for debug telemetry (normal scaffolds are multi-line)
            while i < n:
                l = raw_lines[i].rstrip('\n')
                m = re.match(r"Mission:\s+'(.+?)'", l)
                if m: s['mission'] = m.group(1)
                m = re.match(r"Primary Action:\s+(\S+)\s+\(conf=([0-9.]+),\s+certainty=(\w+)", l)
                if m: s['action'], s['conf'], s['certainty'] = m.group(1), float(m.group(2)), m.group(3)
                m = re.match(r"Sure Actions:\s+\[(.+?)\]", l)
                if m: s['sure_actions'] = m.group(1)
                m = re.match(r"Unsure Actions.*?:\s+\[(.+?)\]", l)
                if m: s['unsure_actions'] = m.group(1)
                m = re.match(r"Winning Node:\s+(\S+)", l)
                if m: s['winning_node'] = m.group(1)
                m = re.match(r"\s+\U0001f4e8\s+(\S+)\s+\|\s+action=(\S+)\s+\|\s+conf=([0-9.]+)", l)
                if m: s['tied'].append({'node': m.group(1), 'action': m.group(2), 'conf': float(m.group(3))})
                m = re.match(r"\s+\U0001f537\s+(\S+)\s+\|\s+action=(\S+)\s+\|\s+conf=([0-9.]+)", l)
                if m: s['others'].append({'node': m.group(1), 'action': m.group(2), 'conf': float(m.group(3))})
                if l.startswith('========='): break
                i += 1
            scaffolds.append(s)
        
        elif is_companion:
            c = {'type': 'companion', 'text': '', 'mission': None, 'action': None,
                 'conf': None, 'certainty': None, 'winning_node': None, 'is_companion': True, 'line': i}
            i += 1
            if i < n: c['text'] = raw_lines[i].rstrip('\n').strip()
            while i < n:
                l = raw_lines[i].rstrip('\n')
                m = re.match(r"Mission:\s+'(.+?)'", l)
                if m: c['mission'] = m.group(1)
                m = re.match(r"Primary Action:\s+(\S+)\s+\(conf=([0-9.]+),\s+certainty=(\w+)", l)
                if m: c['action'], c['conf'], c['certainty'] = m.group(1), float(m.group(2)), m.group(3)
                m = re.match(r"Winning Node:\s+(\S+)", l)
                if m: c['winning_node'] = m.group(1)
                if l.startswith('========='): break
                i += 1
            scaffolds.append(c)
        
        i += 1
    return scaffolds

def extract_loadspecimen_output(raw_lines):
    """Extract the /loadSpecimen output from the raw log.
    This output appears before the burst structure starts, so it's
    missed by the burst-based extraction.
    """
    # Find "Grug thawing specimen" line
    start = None
    end = None
    for i, line in enumerate(raw_lines):
        if 'Grug thawing specimen' in line:
            start = i
        if start is not None and 'SPECIMEN LOADED SUCCESSFULLY' in line:
            # Include the box structure
            # Continue until we find the closing box border
            end = i
            # Find the bottom of the box
            for j in range(i, min(i+20, len(raw_lines))):
                if raw_lines[j].rstrip().startswith('\u255a'):  # bottom-right box corner
                    end = j
                    break
            break
    
    if start is not None and end is not None:
        # Also include some lines before "Grug thawing" that are part of the output
        # (the "Brain > " prompt that triggers the command)
        actual_start = max(0, start - 1)
        output_lines = []
        for j in range(actual_start, end + 1):
            l = raw_lines[j].rstrip('\n')
            # Strip "Brain > " prefix
            if l.startswith('Brain > '):
                l = l[8:]
            output_lines.append(l)
        return '\n'.join(output_lines)
    return None

def extract_bursts(raw_lines):
    """Extract output bursts between empty Brain > prompts."""
    bursts = []
    current = []
    started = False
    
    for line in raw_lines:
        line = line.rstrip('\n')
        if line == 'Brain > ':
            if current:
                bursts.append('\n'.join(current))
                current = []
        elif line.startswith('Brain > '):
            content = line[8:]
            if content.strip():
                started = True
                current.append(content)
        else:
            if started and line.strip():
                current.append(line)
    if current:
        bursts.append('\n'.join(current))
    return bursts

def classify_cmd(cmd):
    """Classify a command string into its system category."""
    c = cmd.strip()
    if c.startswith('/mission'): return 'Mission / Conversation'
    if c.startswith('/brainstorm'): return 'Brainstorm Mode'
    if c.startswith('/explicit'): return 'Explicit Override'
    if c.startswith('/right') or c.startswith('/wrong'): return 'Feedback'
    if c.startswith('/thesaurus'): return 'Thesaurus'
    if c.startswith('/addSeedSynonym'): return 'Seed Synonyms'
    if c.startswith('/negativeThesaurus'): return 'Negative Thesaurus'
    if c.startswith('/sigil'): return 'Sigil System'
    if c.startswith('/decomposer'): return 'Decomposer'
    if c.startswith('/vigilance'): return 'Vigilance'
    if c.startswith('/automaton'): return 'Automaton / Phase Accumulator'
    if c.startswith('/listVerbs') or c.startswith('/addVerb') or c.startswith('/addRelationClass'): return 'Verb Registry'
    if c.startswith('/addAntiMatch'): return 'Anti-Match Nodes'
    if c.startswith('/nodes'): return 'Node Map'
    if c.startswith('/arousal'): return 'Arousal System'
    if c.startswith('/attachments'): return 'Attachment System'
    if c.startswith('/nodeAttach'): return 'Node Attach'
    if c.startswith('/nodeDetach'): return 'Node Detach'
    if c.startswith('/crystalize'): return 'Crystalize'
    if c.startswith('/decrystalize'): return 'De-crystalize'
    if c.startswith('/lobes'): return 'Lobe Registry'
    if c.startswith('/nameLobe'): return 'Lobe Naming'
    if c.startswith('/tableStatus'): return 'Lobe Table Status'
    if c.startswith('/tableMatch'): return 'Lobe Table Match'
    if c.startswith('/grow'): return 'Growth System'
    if c.startswith('/mitosisStatus'): return 'Mitosis Status'
    if c.startswith('/growthStatus'): return 'Growth Automaton'
    if c.startswith('/answer'): return 'Answer System'
    if c.startswith('/antiAnswer'): return 'Anti-Answer System'
    if c.startswith('/addRule'): return 'Rule System'
    if c.startswith('/pin'): return 'Memory Pin'
    if c.startswith('/aimlStatus'): return 'AIML Status'
    if c.startswith('/aimlList'): return 'AIML Listing'
    if c.startswith('/aimlCycle'): return 'AIML Cycle'
    if c.startswith('/aimlRight'): return 'AIML Right'
    if c.startswith('/aimlWrong'): return 'AIML Wrong'
    if c.startswith('/aimlPhagy'): return 'AIML Phagy'
    if c.startswith('/mlpStatus'): return 'MLP System'
    if c.startswith('/mlpRule'): return 'MLP Rules'
    if c.startswith('/mlpObserver'): return 'MLP Observer'
    if c.startswith('/loadSpecimen'): return 'Specimen Loading'
    if c.startswith('/saveSpecimen'): return 'Specimen Save'
    if c.startswith('/status'): return 'System Status'
    if c.startswith('/quit'): return 'Exit'
    return 'Other'

def is_mission_cmd(cmd):
    return cmd.strip().startswith('/mission') or cmd.strip().startswith('/brainstorm') or cmd.strip().startswith('/explicit')

def get_cmd_markers(cmd):
    """Get the first characteristic output marker for a command."""
    c = cmd.strip()
    m = {
        '/loadSpecimen': ['SPECIMEN LOADED SUCCESSFULLY'],
        '/right': ['/right applied'],
        '/wrong': ['penalize'],
        '/thesaurus derivative | integral': ['THESAURUS COMPARISON', 'derivative'],
        '/thesaurus logic | truth': ['THESAURUS COMPARISON', 'logic'],
        '/thesaurus danger | threat :: survival :: perception': ['THESAURUS COMPARISON', 'danger'],
        '/thesaurus beauty | sublime :: aesthetics :: philosophy': ['THESAURUS COMPARISON', 'beauty'],
        '/addSeedSynonym courage [bravery valor fortitude nerve]': ["Seed synonym group: 'courage'"],
        '/addSeedSynonym chaos [disorder entropy turmoil confusion]': ["Seed synonym group: 'chaos'"],
        '/thesaurus courage | bravery': ['THESAURUS COMPARISON', 'courage'],
        '/thesaurus chaos | order': ['THESAURUS COMPARISON', 'chaos'],
        '/negativeThesaurus list': ['NegativeThesaurus'],
        '/negativeThesaurus add stupidity --reason suppress lazy thinking': ["Inhibition registered: 'stupidity'"],
        '/negativeThesaurus add laziness --reason no shortcuts in reasoning': ["Inhibition registered: 'laziness'"],
        '/negativeThesaurus add nonsense': ["Inhibition registered: 'nonsense'"],
        '/negativeThesaurus check stupidity': ["'stupidity' IS inhibited"],
        '/negativeThesaurus check logic': ["'logic' is NOT inhibited"],
        '/negativeThesaurus remove stupidity': ["Inhibition removed: 'stupidity'"],
        '/negativeThesaurus flush': ['NegativeThesaurus flushed'],
        '/sigil list': ['Sigil Table'],
        '/sigil add mathfunc macro bind lexicon=sin,cos,tan,log,exp,sqrt': ['Sigil &mathfunc registered'],
        '/sigil add op2 lambda match type=op promote=true': ['Sigil &op2 registered'],
        '/sigil add formal tag bind': ['Sigil &formal registered'],
        '/sigil remove mathfunc': ['Sigil &mathfunc removed'],
        '/decomposer status': ['DECOMPOSER CONFIG STATUS'],
        '/decomposer addConjunction whereas': ["'whereas'"],
        '/decomposer addQuestion whether': ["'whether'"],
        '/decomposer addCompound notwithstanding standing': ['compound pair'],
        '/decomposer addConjugation think thinks thinking thought': ['addConjugation FAILED'],
        '/decomposer addCommand compute computes computing computed': ['addCommand FAILED'],
        '/decomposer removeConjunction whereas': ["Removed 'whereas'"],
        '/vigilance': ['Vigilance System'],
        '/vigilance enable': ['Vigilance dispatch ENABLED'],
        '/vigilance threshold med 0.6': ['Vigilance threshold'],
        '/vigilance timeout 15.0': ['Vigilance injector timeout'],
        '/vigilance feedback 0.15': ['Vigilance feedback probability'],
        '/automaton list': ['/automaton list'],
        '/automaton phase': ['Phase Accumulator'],
        '/automaton phase threshold 0.5': ['Phase pull threshold'],
        '/automaton phase enable': ['Phase pull ENABLED'],
        '/automaton phase surface 8': ['Phase surface count'],
        '/automaton register test_auto observe 0.5': ['/automaton register'],
        '/listVerbs': ['SEMANTIC VERB REGISTRY'],
        '/addRelationClass epistemic': ["Relation class 'epistemic'"],
        '/addRelationClass causal': ["Relation class 'causal'"],
        '/addRelationClass explain': ["Relation class 'explain'"],
        '/addVerb know epistemic': ["Verb 'know'"],
        '/addVerb believe epistemic': ["Verb 'believe'"],
        '/addVerb doubt epistemic': ["Verb 'doubt'"],
        '/addVerb triggers causal': ["Verb 'triggers'"],
        '/addVerb clarifies explain': ["Verb 'clarifies'"],
        '/addAntiMatch foolishness': ["Anti-match node created", 'foolishness'],
        '/addAntiMatch absurd NONJITTER': ["Anti-match node created", 'absurd'],
        '/nodes': ['NODE MAP STATUS'],
        '/arousal 0.8': ['Arousal set to 0.8'],
        '/arousal 0.3': ['Arousal set to 0.3'],
        '/attachments': ['ATTACHMENT MAP'],
        '/nodeAttach L1 n26 n27 "knowledge certainty proof"': ["n27' attached to target 'n26'"],
        '/nodeAttach L3 n28 n33 "beauty truth aesthetic"': ["n33' attached to target 'n28'"],
        '/crystalize L1 n26 n27': ['CRYSTALIZED'],
        '/decrystalize L1 n26 n27': ['de-crystalized'],
        '/nodeDetach L1 n26 n27': ["n27' detached from target 'n26'"],
        '/lobes': ['LOBE REGISTRY'],
        '/nameLobe L1 mathematics': ["Lobe 'L1' named"],
        '/nameLobe L3 philosophy': ["Lobe 'L3' named"],
        '/tableStatus L1': ['LOBE TABLE: L1'],
        '/tableMatch L1 nodes n26': ['tableMatch'],
        '/grow L1 {"pattern":"induction generalization specific universal","action_packet":"reason^4|analyze^3","data":{"system_prompt":"Grug speaks plainly."}}': ['Tribe expanded', 'L1'],
        '/grow L3 {"pattern":"phenomenology experience consciousness intentionality","action_packet":"explain^4|describe^3","data":{"system_prompt":"Grug speaks plainly."}}': ['Tribe expanded', 'L3'],
        '/mitosisStatus': ['Mitosis:'],
        '/growthStatus': ['GROWTH AUTOMATON'],
        '/answer logical truth is when reasoning and evidence converge': ['Answer node created'],
        '/antiAnswer truth is just opinion': ['Anti-answer node created'],
        '/addRule when logic and philosophy overlap explain both perspectives [prob=0.9]': ['Rule tied to tree'],
        '/addRule always consider multiple perspectives on abstract questions [prob=0.85]': ['Rule tied to tree'],
        '/pin Logic connects mathematics and philosophy through reasoning about truth': ['pinned text to Memory Wall'],
        '/mlpStatus': ['EPHEMERAL MLP STATUS'],
        '/mlpRule add reason analyze 0.7': ['mlpRule add'],
        '/mlpRule list': ['mlpRule list'],
        '/mlpObserver': ['MLP SELF-OBSERVER'],
        '/saveSpecimen specimens/v751_post_test.specimen.json': ['SPECIMEN SAVED'],
        '/status': ['GRUGBOT SYSTEM STATUS'],
        '/aimlStatus': ['AIML TRIBE STATUS'],
        '/aimlList L1': ['AIML NODES IN LOBE: L1'],
        '/aimlList L3': ['AIML NODES IN LOBE: L3'],
        '/aimlCycle': ['AIML CYCLE'],
        '/aimlRight': ['aimlRight'],
        '/aimlWrong': ['aimlWrong'],
        '/aimlPhagy': ['aimlPhagy'],
        '/quit': ['/quit received'],
    }
    return m.get(c)

def clean_gov_output(text):
    """Clean governance output for conversation log."""
    lines = text.split('\n')
    skip_pats = ['[ENGINE]', '[ORCHESTRATOR]', '[HIPPOCAMPAL]', '[INPUT_LEDGER]',
                 '[CHATTER_RESIDUALS]', 'COHERENCE WARNING',
                 'Scanning specimens', 'Cave is silent', 'Attachment relay suppressed',
                 'big-O ledger', 'slow telemetry', 'Lobe Curve',
                 # Julia warning/debug noise
                 '└ @ Base.Docs', '└ @ GrugBot',
                 'Replacing docs for', 'WARNING: redefinition',
                 '└ @ GrugBot420.InputDecomposer', '└ @ GrugBot420.SemanticVerbs',
                 '└ @ GrugBot420 /workspace',
                 'method signature', 'node_map drift', 'scanner_config:',
                 ]
    skip_start_pats = [
        'Warning:', '┌ Warning', '┌ Info:', '┌ Warning: [CLI]',
        '┌ Warning: [MAIN]', '┌ Warning: [SEMANTIC]',
        '┌ Info: [MAIN]', '┌ Info: [SEMANTIC]',
        '│ Input:', '│ Found', '│ The system', '│ FIX:',
        '│ YOU NEED', '│ The frame', '│ TonalJudge',
        '│ method signature',
    ]
    clean = []
    for line in lines:
        stripped = line.strip()
        skip = False
        for pat in skip_pats:
            if pat in line:
                skip = True
                break
        if not skip:
            for pat in skip_start_pats:
                if stripped.startswith(pat):
                    skip = True
                    break
        if not skip and stripped:
            clean.append(line)
    return '\n'.join(clean).strip()

def main():
    print("Loading raw log...")
    raw_lines = load_raw()
    print(f"  {len(raw_lines)} lines")
    
    print("Extracting AIML scaffolds...")
    scaffolds = extract_scaffolds(raw_lines)
    print(f"  Found {len(scaffolds)} scaffolds")
    for i, s in enumerate(scaffolds):
        print(f"    [{i}] type={s['type']} companion={s.get('is_companion',False)} mission={s.get('mission')!r} action={s.get('action')} conf={s.get('conf')} cert={s.get('certainty')} node={s.get('winning_node')} line={s['line']}")
    
    print("Extracting /loadSpecimen output...")
    load_output = extract_loadspecimen_output(raw_lines)
    if load_output:
        print(f"  Found ({len(load_output)} chars)")
    else:
        print("  NOT FOUND")
    
    print("Extracting bursts...")
    bursts = extract_bursts(raw_lines)
    print(f"  Found {len(bursts)} bursts")
    
    print("Parsing test script...")
    script = parse_script()
    print(f"  {len(script)} commands")
    
    # Build exchanges using SCRIPT as source of truth + scaffolds for mission responses
    scaffold_ptr = 0
    exchanges = []
    
    for i, (phase, cmd) in enumerate(script):
        cmd = cmd.strip()
        ex = {'cmd': cmd, 'phase': phase, 'type': classify_cmd(cmd), 'response': None, 'scaffold': None, 'companions': [], 'gov_output': None}
        
        if cmd.startswith('/mission '):
            mission = cmd[9:].strip()
            found = False
            for j in range(scaffold_ptr, len(scaffolds)):
                s = scaffolds[j]
                if not s.get('is_companion') and s.get('mission', '').lower() == mission.lower() and s['type'] == 'normal':
                    ex['scaffold'] = s
                    ex['response'] = s.get('text', '')
                    companions = []
                    k = j + 1
                    while k < len(scaffolds) and scaffolds[k].get('is_companion') and scaffolds[k].get('mission', '').lower() == mission.lower():
                        companions.append(scaffolds[k])
                        k += 1
                    ex['companions'] = companions
                    scaffold_ptr = k
                    found = True
                    break
            if not found:
                ex['response'] = '*Cave is silent — no matching nodes responded*'
        
        elif cmd.startswith('/brainstorm '):
            found = False
            for j in range(scaffold_ptr, len(scaffolds)):
                s = scaffolds[j]
                if s['type'] == 'normal' and not s.get('is_companion'):
                    ex['scaffold'] = s
                    ex['response'] = s.get('text', '')
                    companions = []
                    k = j + 1
                    while k < len(scaffolds) and scaffolds[k].get('is_companion'):
                        companions.append(scaffolds[k])
                        k += 1
                    ex['companions'] = companions
                    scaffold_ptr = k
                    found = True
                    break
            if not found:
                ex['response'] = '*Cave is silent — no matching nodes responded*'
        
        elif cmd.startswith('/explicit '):
            found = False
            for j in range(scaffold_ptr, len(scaffolds)):
                s = scaffolds[j]
                if s['type'] == 'override':
                    ex['scaffold'] = s
                    ex['response'] = s.get('text', '')
                    scaffold_ptr = j + 1
                    found = True
                    break
            if not found:
                ex['response'] = '*No override output captured*'
        
        else:
            # Governance command — find output from raw log using markers
            markers = get_cmd_markers(cmd)
            if markers:
                ex['markers'] = markers
            else:
                ex['markers'] = None
        
        exchanges.append(ex)
    
    # Special handling for /loadSpecimen
    for ex in exchanges:
        if ex['cmd'].strip().startswith('/loadSpecimen') and load_output:
            ex['gov_output'] = clean_gov_output(load_output)
            ex['markers'] = None  # Already handled
    
    # Sequential scan for governance commands
    raw_text = ''.join(raw_lines)
    search_pos = 0
    
    for ex in exchanges:
        markers = ex.get('markers')
        if markers is None:
            continue
        
        # Find marker sequence
        pos = search_pos
        found = True
        for marker in markers:
            idx = raw_text.find(marker, pos)
            if idx < 0:
                found = False
                break
            pos = idx + len(marker)
        
        if found:
            start = raw_text.find(markers[0], search_pos)
            # Find end — look for next boundary
            end = start
            for boundary in ['\nBrain > \n', '\nBrain > \nBrain > ', '\n\nBrain > ']:
                idx = raw_text.find(boundary, start + 1)
                if idx >= 0 and (end == start or idx < end):
                    end = idx
            
            if end == start:
                end = min(start + 5000, len(raw_text))
            
            output = raw_text[start:end]
            output = re.sub(r'^Brain > ', '', output, flags=re.MULTILINE)
            output = re.sub(r'\n  ', '\n', output)
            ex['gov_output'] = clean_gov_output(output)
            search_pos = end
        else:
            ex['gov_output'] = None
    
    # Generate MD
    print("Generating conversation log...")
    md = []
    md.append("# GrugBot420 v751 Comprehensive Governance Test — Conversation Log\n")
    md.append("> This log captures a live test of ALL governance systems in the GrugBot420 Julia CLI engine.")
    md.append("> Each exchange shows the user command and Grug's response, with debug telemetry for conversational turns.")
    md.append("> The UNSURE vote certainty was triggered during the brainstorm phase — see analysis at the end.\n")
    
    # Systems summary
    sys_counts = {}
    sure_count = 0
    unsure_count = 0
    for ex in exchanges:
        sys = ex['type']
        sys_counts[sys] = sys_counts.get(sys, 0) + 1
        if ex.get('scaffold'):
            if ex['scaffold'].get('certainty') == 'SURE': sure_count += 1
            elif ex['scaffold'].get('certainty') == 'UNSURE': unsure_count += 1
    has_response = sum(1 for ex in exchanges if ex.get('response') or ex.get('gov_output'))
    miss_count = sum(1 for ex in exchanges if not ex.get('response') and not ex.get('gov_output'))
    
    md.append("## Systems Tested\n")
    for sys in sorted(sys_counts):
        md.append(f"- **{sys}** ({sys_counts[sys]} exchanges)")
    md.append(f"\n**Total exchanges:** {len(exchanges)} | **With response:** {has_response} | **Missing:** {miss_count} | **SURE:** {sure_count} | **UNSURE:** {unsure_count}\n")
    md.append("---\n")
    
    # Phase-grouped exchanges
    cur_phase = None
    for i, ex in enumerate(exchanges):
        if ex['phase'] != cur_phase:
            md.append(f"## Phase: {ex['phase']}\n")
            cur_phase = ex['phase']
        
        cmd = ex['cmd']
        md.append(f"**User:** `{cmd}`")
        
        # AIML response (mission/brainstorm/explicit)
        if ex.get('scaffold'):
            info = ex['scaffold']
            certainty = info.get('certainty', '')
            conf = info.get('conf', 0)
            action = info.get('action', '?')
            node = info.get('winning_node', '?')
            
            if certainty == 'UNSURE':
                md.append(f"**Grug** 🟡 *(UNSURE, conf={conf}, {action} via {node})*:")
            elif certainty == 'SURE':
                md.append(f"**Grug** 🟢 *(SURE, conf={conf}, {action} via {node})*:")
            else:
                md.append(f"**Grug:**")
            
            text = ex.get('response', '')
            if text:
                md.append(f"> {text}")
            
            for comp in ex.get('companions', []):
                ct = comp.get('text', '')
                cn = comp.get('winning_node', '?')
                ca = comp.get('action', '?')
                cc = comp.get('conf', 0)
                if ct:
                    md.append(f"> *Also from {cn} ({ca}, conf={cc}):* {ct}")
            
            tied = info.get('tied', [])
            if tied:
                alt = ', '.join(f"{t['node']}→{t['action']}(conf={t['conf']})" for t in tied)
                md.append(f"> ⚠️ **Tied alternatives (UNSURE trigger):** {alt}")
            
            others = info.get('others', [])
            if others:
                oth = ', '.join(f"{o['node']}→{o['action']}(conf={o['conf']})" for o in others)
                md.append(f"> 🔷 **Other possibilities:** {oth}")
        
        elif ex.get('gov_output'):
            gov = ex['gov_output']
            md.append("**Grug:**")
            for line in gov.split('\n'):
                if line.strip():
                    md.append(f"> {line}")
        
        elif ex.get('response'):
            md.append("**Grug:**")
            md.append(f"> {ex['response']}")
        
        else:
            md.append("**Grug:** > *No output captured*")
        
        md.append(f"<!-- {ex['type']} -->\n")
    
    # UNSURE analysis
    md.append("---\n")
    md.append("## UNSURE Vote Analysis\n")
    unsure_scaffolds = [s for s in scaffolds if s.get('certainty') == 'UNSURE']
    if unsure_scaffolds:
        for s in unsure_scaffolds:
            md.append(f"**Mission:** `{s.get('mission', '?')}`  ")
            md.append(f"**Primary:** {s.get('action', '?')} (conf={s.get('conf', 0)}) via {s.get('winning_node', '?')}  ")
            md.append(f"**Sure Actions:** {s.get('sure_actions', 'None')}\n")
            tied = s.get('tied', [])
            if tied:
                alt = ', '.join(f"{t['node']}→{t['action']}(conf={t['conf']})" for t in tied)
                md.append(f"**Tied Alternatives:** {alt}\n")
            md.append("The UNSURE certainty was triggered because `tied_alternatives` (nodes from different `node_ids` in `sure_votes`) were non-empty. However, the full hedge text \"I am not fully locked in — X also on the table\" requires BOTH `vote_certainty == UNSURE` AND `!isempty(unsure_votes)` (subtop_tier coinflip survivors). In this test, `unsure_votes` was empty, so the full hedge text did not appear in the response. To trigger full hedge text: add more nodes at slightly lower confidence (in the subtop_tier range, just below the top_tier window of 0.05) so that coinflip survivors populate the `unsure_votes` list.\n")
    else:
        md.append("No UNSURE certainty events were captured in this test run.\n")
    
    # Override analysis
    override_scaffolds = [s for s in scaffolds if s.get('type') == 'override']
    if override_scaffolds:
        md.append("## Explicit Override Scaffolds\n")
        for s in override_scaffolds:
            md.append(f"- **Mission:** `{s.get('mission', '?')}` | **Action:** {s.get('action', '?')} | **Node:** {s.get('winning_node', '?')} | **Conf:** {s.get('conf', 0)}")
        md.append("")
    
    result = '\n'.join(md)
    with open(OUT, 'w') as f:
        f.write(result)
    print(f"\nWrote {OUT} ({len(result)} bytes)")
    print(f"  With response: {has_response}, Missing: {miss_count}")
    print(f"  SURE: {sure_count}, UNSURE: {unsure_count}")

if __name__ == '__main__':
    main()
