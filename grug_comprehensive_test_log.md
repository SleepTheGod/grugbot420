# Grugbot Comprehensive Test Log

Generated from internal state (`_LAST_AIML_OUTPUT`, `NODE_MAP`, `_LAST_FIRED_NODE`, `_LAST_CONFIDENCE`, `LAST_VOTER_IDS`).
No stdout scraping. All telemetry from program internals.

**Specimen:** `grug_with_actions.specimen` (saved after boot with action sigil nodes)
**Action callback nodes in memory:** 9

## Action Sigil Node Inventory

| Node ID | Pattern | Action Callback | Drop Table |
|---|---|---|---|
| `node_sigil_9` | `half of &n` | `half` | `["@sigil:action"]` |
| `node_sigil_13` | `fibonacci of &n` | `fibonacci` | `["@sigil:action"]` |
| `node_sigil_8` | `double &n` | `double` | `["@sigil:action"]` |
| `node_sigil_7` | `square root of &n` | `square_root` | `["@sigil:action"]` |
| `node_sigil_5` | `factorial of &n` | `factorial` | `["@sigil:action"]` |
| `node_sigil_12` | `reciprocal of &n` | `reciprocal` | `["@sigil:action"]` |
| `node_sigil_6` | `square of &n` | `square` | `["@sigil:action"]` |
| `node_sigil_11` | `absolute value of &n` | `absolute` | `["@sigil:action"]` |
| `node_sigil_10` | `cube of &n` | `cube` | `["@sigil:action"]` |

## Category 1: Regular Prompts

### Regular-1: What is fire

**Input:** `what is fire`

**Output:** Here is the picture: Oxygen combines with fuel and releases energy as heat and light. Grug learned to tame fire long ago. Fire is both creator and destroyer. It warms the cave but devours the forest. Grug speak of fire. It connects like this: fire is oxidation.

| Telemetry | Value |
|---|---|
| Fired Node | `node_113` |
| Confidence | 0.867 |
| Primary Action | `explain` |
| Voter Count | 2 |
| Voter IDs | `node_113, node_114` |
| Node Info | pattern=fire | signal=[0.2630790683754012] | strength=6.0 | node_type=voter |

### Regular-2: Tell me about water

**Input:** `tell me about water`

**Output:** Thinking it through: Two hydrogen and one oxygen holding hands. Water flows and adapts. It takes the shape of any container. Water is patient. Water always finds a way through. Grug think on water. The link is clear: water sustains life.

| Telemetry | Value |
|---|---|
| Fired Node | `node_116` |
| Confidence | 0.866 |
| Primary Action | `reason` |
| Voter Count | 1 |
| Voter IDs | `node_116` |
| Node Info | pattern=water | signal=[0.4176046721471989] | strength=6.0 | node_type=voter |

### Regular-3: How does breathing work

**Input:** `how does breathing work`

**Output:** ⚡ Nothing in the cave matches this input. (I do remember our recent conversation.)
🤔 I'm drawing a blank on "how does breathing work". What is it?
   → Use /answer [@lobe_id] [:mode] <text> to teach me. Modes: reason, explain, define, alert, comfort, math, multi, relate, proc, json. Or /antiAnswer to suppress. (strain=0.8)

| Telemetry | Value |
|---|---|
| Fired Node | `` |
| Confidence | 0.0 |
| Primary Action | `ask` |
| Voter Count | 1 |
| Voter IDs | `node_116` |

### Regular-4: What is hunting

**Input:** `what is hunting`

**Output:** ⚡ Nothing in the cave matches this input. (I do remember our recent conversation.)
🤔 "what is hunting" — nothing fires. What should I know about this?
   → Use /answer [@lobe_id] [:mode] <text> to teach me. Modes: reason, explain, define, alert, comfort, math, multi, relate, proc, json. Or /antiAnswer to suppress. (strain=0.8)

| Telemetry | Value |
|---|---|
| Fired Node | `` |
| Confidence | 0.0 |
| Primary Action | `ask` |
| Voter Count | 1 |
| Voter IDs | `node_116` |

## Category 2: Multipart Prompts

### Multipart-1: What is fire and how does it keep you warm

**Input:** `what is fire and how does it keep you warm`

**Output:** Here is the picture: Oxygen combines with fuel and releases energy as heat and light. Grug learned to tame fire long ago. Fire is both creator and destroyer. It warms the cave but devours the forest. Grug speak of fire.

| Telemetry | Value |
|---|---|
| Fired Node | `node_113` |
| Confidence | 1.0 |
| Primary Action | `explain` |
| Voter Count | 3 |
| Voter IDs | `node_113, node_17, node_254` |
| Node Info | pattern=fire | signal=[0.2630790683754012] | strength=6.0 | node_type=voter |

### Multipart-2: How does water flow and where does it go

**Input:** `how does water flow and where does it go`

**Output:** Here is the picture: They carry water from mountains to sea. Rivers carve canyons over millions of years. They are patient sculptors. Rivers never stop moving toward the sea. Grug speak of rivers.

| Telemetry | Value |
|---|---|
| Fired Node | `node_144` |
| Confidence | 0.866 |
| Primary Action | `describe` |
| Voter Count | 3 |
| Voter IDs | `node_144, node_116, node_145` |
| Node Info | pattern=flow | signal=[0.31609750402231956] | strength=6.0 | node_type=voter |

### Multipart-3: What is sleep and why is it important

**Input:** `what is sleep and why is it important`

**Output:** ⚡ Nothing in the cave matches this input. (I do remember our recent conversation.)
🤔 The cave echoes on "what is sleep and why is it important" and I can't resolve it. Can you tell me what you mean?
   → Use /answer [@lobe_id] [:mode] <text> to teach me. Modes: reason, explain, define, alert, comfort, math, multi, relate, proc, json. Or /antiAnswer to suppress. (strain=0.799)

| Telemetry | Value |
|---|---|
| Fired Node | `` |
| Confidence | 0.0 |
| Primary Action | `ask` |
| Voter Count | 3 |
| Voter IDs | `node_144, node_116, node_145` |

## Category 3: Math / Action Sigil Prompts

### Math-1: Factorial of 5

**Input:** `factorial of 5`

**Output:** Thinking it through: factorial of 5 is 120.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_5` |
| Confidence | 1.0 |
| Primary Action | `reason` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_5, node_sigil_12, node_sigil_8, node_sigil_0, node_sigil_10 …` |
| Node Info | pattern=factorial of &n | signal=[0.2984842570344101, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=factorial | drop_table=["@sigil:action"] |

### Math-2: Factorial of 7

**Input:** `factorial of 7`

**Output:** Thinking it through: factorial of 7 is 5040.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_5` |
| Confidence | 1.0 |
| Primary Action | `calculate` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_5, node_sigil_12, node_sigil_8, node_sigil_0, node_sigil_10 …` |
| Node Info | pattern=factorial of &n | signal=[0.2984842570344101, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=factorial | drop_table=["@sigil:action"] |

### Math-3: Square of 9

**Input:** `square of 9`

**Output:** Thinking it through: 9 squared is 81.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_6` |
| Confidence | 1.0 |
| Primary Action | `calculate` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_6, node_sigil_7, node_sigil_12, node_sigil_8, node_sigil_0 …` |
| Node Info | pattern=square of &n | signal=[0.7229739000769797, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=square | drop_table=["@sigil:action"] |

### Math-4: Cube of 3

**Input:** `cube of 3`

**Output:** Thinking it through: 3 cubed is 27.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_10` |
| Confidence | 1.0 |
| Primary Action | `analyze` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_10, node_sigil_12, node_sigil_8, node_sigil_0, node_sigil_13 …` |
| Node Info | pattern=cube of &n | signal=[0.7427491912364599, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=cube | drop_table=["@sigil:action"] |

### Math-5: Double 7

**Input:** `double 7`

**Output:** Thinking it through: double of 7 is 14.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_8` |
| Confidence | 1.0 |
| Primary Action | `reason` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_8, node_sigil_9, node_sigil_13, node_sigil_0, node_sigil_5 …` |
| Node Info | pattern=double &n | signal=[0.5376916418024256, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=double | drop_table=["@sigil:action"] |

### Math-6: Half of 12

**Input:** `half of 12`

**Output:** Thinking it through: half of 12 is 6.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_9` |
| Confidence | 1.0 |
| Primary Action | `reason` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_9, node_sigil_12, node_sigil_8, node_sigil_0, node_sigil_5 …` |
| Node Info | pattern=half of &n | signal=[0.6846628745796876, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=half | drop_table=["@sigil:action"] |

### Math-7: Fibonacci of 10

**Input:** `fibonacci of 10`

**Output:** Thinking it through: fibonacci of 10 is 55.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_13` |
| Confidence | 1.0 |
| Primary Action | `calculate` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_13, node_sigil_12, node_sigil_8, node_sigil_0, node_sigil_5 …` |
| Node Info | pattern=fibonacci of &n | signal=[0.6371223597820456, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=fibonacci | drop_table=["@sigil:action"] |

### Math-8: Absolute value of -15

**Input:** `absolute value of -15`

**Output:** Thinking it through: absolute value of 15 is 15.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_11` |
| Confidence | 0.975 |
| Primary Action | `reason` |
| Voter Count | 4 |
| Voter IDs | `node_sigil_11, node_sigil_0, node_sigil_1, node_sigil_8` |
| Node Info | pattern=absolute value of &n | signal=[0.24944620800052278, 0.7793647294947578, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=absolute | drop_table=["@sigil:action"] |

### Math-9: Reciprocal of 4

**Input:** `reciprocal of 4`

**Output:** Thinking it through: reciprocal of 4 is 0.25.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_12` |
| Confidence | 1.0 |
| Primary Action | `calculate` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_12, node_sigil_0, node_sigil_13, node_sigil_9, node_sigil_10 …` |
| Node Info | pattern=reciprocal of &n | signal=[0.3578689863377465, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=reciprocal | drop_table=["@sigil:action"] |

### Math-10: Square root of 16

**Input:** `square root of 16`

**Output:** Thinking it through: square root of 16 is 4.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_7` |
| Confidence | 1.0 |
| Primary Action | `calculate` |
| Voter Count | 11 |
| Voter IDs | `node_sigil_7, node_sigil_6, node_sigil_12, node_sigil_8, node_sigil_0 …` |
| Node Info | pattern=square root of &n | signal=[0.7229739000769797, 0.06189261341667231, 0.02814897713460073, 0.4537671081806071] | strength=9.0 | node_type=sigil | action_callback=square_root | drop_table=["@sigil:action"] |

### Math-Arithmetic-11: 3 + 5

**Input:** `3 + 5`

**Output:** Thinking it through: 3 plus 5 equals 8.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_0` |
| Confidence | 1.0 |
| Primary Action | `calculate` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_0, node_sigil_1, node_sigil_8, node_sigil_12, node_sigil_6 …` |
| Node Info | pattern=&n &op &n | signal=[0.4537671081806071, 0.501520212580718, 0.4537671081806071] | strength=9.0 | node_type=sigil | drop_table=["@sigil:math"] |

### Math-Arithmetic-12: 12 * 4

**Input:** `12 * 4`

**Output:** Thinking it through: 12 times 4 equals 48.

| Telemetry | Value |
|---|---|
| Fired Node | `node_sigil_0` |
| Confidence | 1.0 |
| Primary Action | `calculate` |
| Voter Count | 12 |
| Voter IDs | `node_sigil_0, node_sigil_1, node_sigil_8, node_sigil_12, node_sigil_6 …` |
| Node Info | pattern=&n &op &n | signal=[0.4537671081806071, 0.501520212580718, 0.4537671081806071] | strength=9.0 | node_type=sigil | drop_table=["@sigil:math"] |

## Category 4: Question / Answer

### QA-1: What is gravity

**Input:** `what is gravity`

**Output:** Thinking it through: Gravity pulls everything toward everything else. Big things pull harder. This is the invisible hand that moves the world. Grug think on gravity.

| Telemetry | Value |
|---|---|
| Fired Node | `node_58` |
| Confidence | 1.0 |
| Primary Action | `reason` |
| Voter Count | 1 |
| Voter IDs | `node_58` |
| Node Info | pattern=gravity | node_type=voter |

### QA-2: How does photosynthesis work

**Input:** `how does photosynthesis work`

**Output:** Here is the picture: That is photosynthesis. Chlorophyll catches light energy and turns water and carbon dioxide into sugar and oxygen. Plants are the bridge between sun and life. Grug speak of photosynthesis. and  The bridge: photosynthesis converts light_to_sugar.

| Telemetry | Value |
|---|---|
| Fired Node | `node_67` |
| Confidence | 0.867 |
| Primary Action | `explain` |
| Voter Count | 1 |
| Voter IDs | `node_67` |
| Node Info | pattern=photosynthesis | node_type=voter |

### QA-3: What is DNA

**Input:** `what is DNA`

**Output:** Here is the picture: It is shaped like a twisted ladder called a double helix. The rungs of the ladder are letters that spell out how to build you. Grug speak of dna.

| Telemetry | Value |
|---|---|
| Fired Node | `node_70` |
| Confidence | 1.0 |
| Primary Action | `explain` |
| Voter Count | 1 |
| Voter IDs | `node_70` |
| Node Info | pattern=DNA | node_type=voter |

### QA-4: Why is the sky blue

**Input:** `why is the sky blue`

**Output:** Here is the picture: Sky is blue because sunlight scatters off air molecules. Blue light scatters most because it waves short and fast. This is Rayleigh scattering. Grug speak of sky.

| Telemetry | Value |
|---|---|
| Fired Node | `node_62` |
| Confidence | 0.866 |
| Primary Action | `explain` |
| Voter Count | 2 |
| Voter IDs | `node_62, node_61` |
| Node Info | pattern=blue | node_type=voter |

### QA-5: What is consciousness

**Input:** `what is consciousness`

**Output:** Thinking it through: What is it like to be Grug? Consciousness is the fire inside that makes experience real. Grug not know where it comes from but Grug knows it burns. Grug think on consciousness.

| Telemetry | Value |
|---|---|
| Fired Node | `node_88` |
| Confidence | 1.0 |
| Primary Action | `ponder` |
| Voter Count | 1 |
| Voter IDs | `node_88` |
| Node Info | pattern=consciousness | node_type=voter |

### QA-6: What is thermodynamics

**Input:** `what is thermodynamics`

**Output:** Thinking it through: That is the way of things. Entropy always increases. Disorder grows unless you push energy in to fight it. These are the laws even Grug cannot break. Grug think on thermodynamics.

| Telemetry | Value |
|---|---|
| Fired Node | `node_79` |
| Confidence | 1.0 |
| Primary Action | `reason` |
| Voter Count | 1 |
| Voter IDs | `node_79` |
| Node Info | pattern=thermodynamics | node_type=voter |

## Category 5: Teach-and-Reask Loop

Tests the full strain → ask → /answer → recall loop.
Each scenario: (1) ask about unknown topic → grug asks for info, (2) teach with /answer → node created in cave, (3) ask again → grug fires from the new node.

### Teach-1A — Ask (before teaching): Breathing

**Input:** `how does breathing work`

**Output:** 🤔 "how does breathing work" — nothing fires. What should I know about this?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Teach-1B — Teach with /answer: Breathing

**Input:** `/answer :explain breathing draws oxygen into the lungs and expels carbon dioxide`

**Output:** 🧠 Answer [:explain]: id=node_3 pattern='breathing draws oxygen into the lungs and expels carbon dioxide' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_3` |
| Pattern | `breathing draws oxygen into the lungs and expels carbon dioxide` |
| Answer Mode | `:explain` |
| Strain Effect | dampened (deficit resolved) |

### Teach-1C — Re-ask (after teaching): Breathing

**Input:** `how does breathing work`

**Output:** Here is the picture: breathing draws oxygen into the lungs and expels carbon dioxide.

| Telemetry | Value |
|---|---|
| Fired Node | `node_5` |
| Confidence | 0.41 |
| Primary Action | `explain` |
| Interpretation | Grug now knows — fires from taught node |

### Teach-2A — Ask (before teaching): Hunting

**Input:** `what is hunting`

**Output:** 🤔 "what is hunting" — nothing fires. What should I know about this?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Teach-2B — Teach with /answer: Hunting

**Input:** `/answer :reason hunting is the pursuit and capture of prey for food and survival`

**Output:** 🧠 Answer [:reason]: id=node_8 pattern='hunting is the pursuit and capture of prey for food and survival' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_8` |
| Pattern | `hunting is the pursuit and capture of prey for food and survival` |
| Answer Mode | `:reason` |
| Strain Effect | dampened (deficit resolved) |

### Teach-2C — Re-ask (after teaching): Hunting

**Input:** `what is hunting`

**Output:** Thinking it through: hunting is the pursuit and capture of prey for food and survival.

| Telemetry | Value |
|---|---|
| Fired Node | `node_10` |
| Confidence | 1.0 |
| Primary Action | `reason` |
| Interpretation | Grug now knows — fires from taught node |

### Teach-3A — Ask (before teaching): Cooking

**Input:** `what is cooking`

**Output:** 🤔 The cave is dark on "what is cooking". What does that mean to you?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Teach-3B — Teach with /answer: Cooking

**Input:** `/answer :explain cooking applies heat to food to make it safe and easier to digest`

**Output:** 🧠 Answer [:explain]: id=node_14 pattern='cooking applies heat to food to make it safe and easier to digest' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_14` |
| Pattern | `cooking applies heat to food to make it safe and easier to digest` |
| Answer Mode | `:explain` |
| Strain Effect | dampened (deficit resolved) |

### Teach-3C — Re-ask (after teaching): Cooking

**Input:** `what is cooking`

**Output:** Here is the picture: cooking applies heat to food to make it safe and easier to digest.

| Telemetry | Value |
|---|---|
| Fired Node | `node_16` |
| Confidence | 1.0 |
| Primary Action | `explain` |
| Interpretation | Grug now knows — fires from taught node |

### Teach-4A — Ask (before teaching): Music

**Input:** `what is music`

**Output:** 🤔 No structure catches "what is music". Help me out — what are you getting at?

| Telemetry | Value |
|---|---|
| Primary Action | `ask` |
| Confidence | 0.0 |
| Interpretation | Grug doesn't know — asks for /answer |

### Teach-4B — Teach with /answer: Music

**Input:** `/answer :define music is organized sound that expresses emotion and rhythm`

**Output:** 🧠 Answer [:define]: id=node_20 pattern='music is organized sound that expresses emotion and rhythm' — node created and strain dampened

| Telemetry | Value |
|---|---|
| New Node | `node_20` |
| Pattern | `music is organized sound that expresses emotion and rhythm` |
| Answer Mode | `:define` |
| Strain Effect | dampened (deficit resolved) |

### Teach-4C — Re-ask (after teaching): Music

**Input:** `what is music`

**Output:** Here is the picture: music is organized sound that expresses emotion and rhythm.

| Telemetry | Value |
|---|---|
| Fired Node | `node_21` |
| Confidence | 1.0 |
| Primary Action | `define` |
| Interpretation | Grug now knows — fires from taught node |

## Summary

| Category | Count |
|---|---|
| Regular | 4 |
| Multipart | 3 |
| Math / Action | 12 |
| Question / Answer | 6 |
| Teach-and-Reask | 12 (4 scenarios × 3 steps) |
| **Total** | **37** |

